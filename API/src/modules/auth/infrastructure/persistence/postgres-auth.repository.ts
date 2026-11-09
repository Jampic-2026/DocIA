import {
  ChangePasswordDto,
  RefreshTokenDto,
  CompleteRegistrationDto,
  DisableMfaDto,
} from "../../domain/auth-inputs";
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import * as bcrypt from "bcrypt";
import { PoolClient } from "pg";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import {
  RequestContext,
  SessionRecord,
  UserAuthRecord,
} from "../../domain/auth-persistence-types";
import { AuthTokenPayload } from "../../domain/auth-token-payload";
import { AuthRepository } from "../../domain/ports/auth.repository";

@Injectable()
export class PostgresAuthRepository implements AuthRepository {
  constructor(
    private readonly database: DatabaseService,
    private readonly config: ConfigService,
  ) {}
  createLoginSession(
    sessionId: `${string}-${string}-${string}-${string}-${string}`,
    user: UserAuthRecord,
    refreshTokenHash: string,
    context: RequestContext,
    refreshExpiresAt: Date,
  ): Promise<void> {
    return this.database.transactionWithSettings(
      this.authSettings(user, sessionId),
      async (client) => {
        await client.query(
          `
          INSERT INTO user_sessions (id, user_id, refresh_token_hash, user_agent, ip_address, expires_at)
          VALUES ($1, $2, $3, $4, NULLIF($5, '')::inet, $6)
          `,
          [
            sessionId,
            user.id,
            refreshTokenHash,
            context.userAgent ?? null,
            context.ipAddress ?? "",
            refreshExpiresAt,
          ],
        );

        await client.query(
          "UPDATE users SET last_login_at = now() WHERE id = $1",
          [user.id],
        );
        await client.query(
          `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id,ip_address,user_agent) VALUES($1,$2,'auth','login_succeeded','user',$1,NULLIF($3,'')::inet,$4)`,
          [
            user.id,
            user.role_code,
            context.ipAddress ?? "",
            context.userAgent ?? null,
          ],
        );
      },
    );
  }
  rotateRefreshSession(
    payload: AuthTokenPayload,
    dto: RefreshTokenDto,
    issueTokensCallback: (
      user: UserAuthRecord,
      sessionId: string,
    ) => Promise<{ accessToken: string; refreshToken: string }>,
    expirationToDateCallback: (value: string) => Date,
    authResponseCallback: (
      user: UserAuthRecord,
      sessionId: string,
      tokens: { accessToken: string; refreshToken: string },
    ) => {
      accessToken: string;
      refreshToken: string;
      tokenType: string;
      user: {
        id: string;
        sessionId: string;
        email: string;
        phone: string | null;
        roleCode: string;
        roles: string[];
        permissions: string[];
      };
    },
    configurationValue1: string,
  ): Promise<{
    accessToken: string;
    refreshToken: string;
    tokenType: string;
    user: {
      id: string;
      sessionId: string;
      email: string;
      phone: string | null;
      roleCode: string;
      roles: string[];
      permissions: string[];
    };
  }> {
    return this.database.transactionWithSettings(
      {
        "app.user_id": payload.sub,
        "app.session_id": payload.sid,
        "app.role_code": payload.roleCode,
        "app.roles": payload.roles,
        "app.permissions": payload.permissions,
      },
      async (client) => {
        const session = await this.findActiveSession(
          client,
          payload.sid,
          payload.sub,
        );
        const tokenMatches = await bcrypt.compare(
          dto.refreshToken,
          session.refresh_token_hash,
        );

        if (!tokenMatches) {
          throw new UnauthorizedException("Refresh token inválido");
        }

        const user = await this.findActiveUserById(client, session.user_id);
        const tokens = await issueTokensCallback(user, session.id);
        const refreshTokenHash = await bcrypt.hash(tokens.refreshToken, 12);
        const refreshExpiresAt = expirationToDateCallback(configurationValue1);

        await client.query(
          `
          UPDATE user_sessions
          SET refresh_token_hash = $1,
              expires_at = $2
          WHERE id = $3
          `,
          [refreshTokenHash, refreshExpiresAt, session.id],
        );

        return authResponseCallback(user, session.id, tokens);
      },
    );
  }
  revokeLogoutSession(payload: AuthTokenPayload): Promise<void> {
    return this.database.transactionWithSettings(
      {
        "app.user_id": payload.sub,
        "app.session_id": payload.sid,
        "app.role_code": payload.roleCode,
        "app.roles": payload.roles,
        "app.permissions": payload.permissions,
      },
      async (client) => {
        await client.query(
          `
          UPDATE user_sessions
          SET revoked_at = now()
          WHERE id = $1
            AND user_id = $2
            AND revoked_at IS NULL
          `,
          [payload.sid, payload.sub],
        );
        await client.query(
          `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id) VALUES($1,$2,'auth','logout','user',$1)`,
          [payload.sub, payload.roleCode],
        );
      },
    );
  }
  listSessions(user: RequestUser): Promise<{ items: any[] }> {
    return this.database.transactionAsUser(user, async (client) => ({
      items: (
        await client.query(
          `SELECT id,user_agent AS "userAgent",ip_address AS "ipAddress",expires_at AS "expiresAt",revoked_at AS "revokedAt",created_at AS "createdAt",id=$2 AS "isCurrent" FROM user_sessions WHERE user_id=$1 ORDER BY created_at DESC`,
          [user.id, user.sessionId],
        )
      ).rows,
    }));
  }
  createRegistrationRequest(
    email: string,
    hash: string,
    context: RequestContext,
  ): Promise<string> {
    return this.database.transaction(async (client) => {
      if (
        (await client.query(`SELECT id FROM users WHERE email=$1`, [email]))
          .rows[0]
      )
        throw new ConflictException("Ya existe una cuenta con ese correo.");
      await client.query(
        `UPDATE registration_email_tokens SET consumed_at=COALESCE(consumed_at,now()) WHERE email=$1 AND consumed_at IS NULL`,
        [email],
      );
      return (
        await client.query<{ id: string }>(
          `INSERT INTO registration_email_tokens(email,token_hash,requested_ip,user_agent,expires_at) VALUES($1,$2,NULLIF($3,'')::inet,$4,now()+interval '30 minutes') RETURNING id`,
          [email, hash, context.ipAddress ?? "", context.userAgent ?? null],
        )
      ).rows[0].id;
    });
  }
  completeRegistration(
    tokenHash: string,
    isMinor: boolean,
    input: CompleteRegistrationDto,
    passwordHash: string,
  ): Promise<{
    userId: string;
    patientId: string;
    email: string;
    status: string;
  }> {
    return this.database.transaction(async (client) => {
      const token = await client.query<{ id: string; email: string }>(
        `SELECT id,email::text FROM registration_email_tokens WHERE token_hash=$1 AND consumed_at IS NULL AND expires_at>now() FOR UPDATE`,
        [tokenHash],
      );
      if (!token.rows[0])
        throw new UnauthorizedException(
          "El enlace de registro no es válido o expiró.",
        );
      await client.query(
        "SELECT set_config('app.registration_email',$1,true)",
        [token.rows[0].email],
      );
      let guardianId: string | null = null;
      if (isMinor) {
        if (!input.guardianEmail)
          throw new BadRequestException(
            "Una persona menor de edad debe vincular un tutor adulto registrado.",
          );
        const guardian = await client.query<{ id: string }>(
          `SELECT users.id FROM users JOIN persons ON persons.user_id=users.id WHERE users.email=$1 AND users.status='active' AND persons.birth_date<=CURRENT_DATE-interval '18 years'`,
          [input.guardianEmail.trim().toLowerCase()],
        );
        if (!guardian.rows[0])
          throw new BadRequestException(
            "El tutor debe tener una cuenta activa y ser mayor de edad.",
          );
        guardianId = guardian.rows[0].id;
      }
      const role = await client.query<{ id: string }>(
        `SELECT id FROM roles WHERE code='patient' AND is_active`,
      );
      if (!role.rows[0])
        throw new NotFoundException("El rol de paciente no está configurado.");
      const created = await client.query<{ id: string }>(
        `INSERT INTO users(role_id,email,phone,password_hash,status,email_verified_at) VALUES($1,$2,NULLIF($3,''),$4,'active',now()) RETURNING id`,
        [
          role.rows[0].id,
          token.rows[0].email,
          input.phone?.trim() ?? "",
          passwordHash,
        ],
      );
      await client.query("SELECT set_config('app.user_id',$1,true)", [
        created.rows[0].id,
      ]);
      await client.query("SELECT set_config('app.role_code','patient',true)");
      await client.query(
        `INSERT INTO user_roles(user_id,role_id) VALUES($1,$2)`,
        [created.rows[0].id, role.rows[0].id],
      );
      const person = await client.query<{ id: string }>(
        `INSERT INTO persons(user_id,first_name,last_name,second_last_name,document_type,document_number,birth_date) VALUES($1,$2,$3,NULLIF($4,''),NULLIF($5,''),NULLIF($6,''),$7::date) RETURNING id`,
        [
          created.rows[0].id,
          input.firstName.trim(),
          input.lastName.trim(),
          input.secondLastName?.trim() ?? "",
          input.documentType?.trim() ?? "",
          input.documentNumber?.trim() ?? "",
          input.birthDate,
        ],
      );
      const patient = await client.query<{ id: string }>(
        `INSERT INTO patients(person_id,is_minor,is_dependent) VALUES($1,$2,$2) RETURNING id`,
        [person.rows[0].id, isMinor],
      );
      if (input.municipality || input.zone || input.addressLine)
        await client.query(
          `INSERT INTO addresses(person_id,municipality,zone,address_line) VALUES($1,NULLIF($2,''),NULLIF($3,''),NULLIF($4,''))`,
          [
            person.rows[0].id,
            input.municipality?.trim() ?? "",
            input.zone?.trim() ?? "",
            input.addressLine?.trim() ?? "",
          ],
        );
      if (guardianId)
        await client.query(
          `INSERT INTO patient_guardians(patient_id,guardian_user_id,relationship,is_legal_guardian,verification_status) VALUES($1,$2,$3,true,'validated')`,
          [
            patient.rows[0].id,
            guardianId,
            input.guardianRelationship?.trim() ?? "Tutor",
          ],
        );
      await client.query(
        `INSERT INTO patient_consents(patient_id,consent_type_id,granted_by_user_id,status) SELECT $1,type.id,$2,'accepted' FROM consent_types type WHERE type.is_required AND type.is_active`,
        [patient.rows[0].id, created.rows[0].id],
      );
      await client.query(
        `UPDATE registration_email_tokens SET verified_at=now(),consumed_at=now(),created_user_id=$2 WHERE id=$1`,
        [token.rows[0].id, created.rows[0].id],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,patient_id,module,action,entity_type,entity_id,new_values) VALUES($1,'patient',$2,'auth','patient_registered','user',$1,jsonb_build_object('emailVerified',true,'isMinor',$3::boolean))`,
        [created.rows[0].id, patient.rows[0].id, isMinor],
      );
      return {
        userId: created.rows[0].id,
        patientId: patient.rows[0].id,
        email: token.rows[0].email,
        status: "active",
      };
    });
  }
  changePassword(
    user: RequestUser,
    input: ChangePasswordDto,
  ): Promise<{ updated: boolean }> {
    return this.database.transactionAsUser(user, async (client) => {
      const record = await client.query<{ password_hash: string }>(
        `SELECT password_hash FROM users WHERE id=$1 FOR UPDATE`,
        [user.id],
      );
      if (
        !record.rows[0] ||
        !(await bcrypt.compare(
          input.currentPassword,
          record.rows[0].password_hash,
        ))
      )
        throw new UnauthorizedException("La contraseña actual no es correcta.");
      if (await bcrypt.compare(input.newPassword, record.rows[0].password_hash))
        throw new BadRequestException(
          "La nueva contraseña debe ser diferente.",
        );
      const hash = await bcrypt.hash(input.newPassword, 12);
      await client.query(
        `UPDATE users SET password_hash=$2,updated_at=now() WHERE id=$1`,
        [user.id, hash],
      );
      await client.query(
        `UPDATE user_sessions SET revoked_at=COALESCE(revoked_at,now()) WHERE user_id=$1 AND id<>$2`,
        [user.id, user.sessionId],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id) VALUES($1,$2,'auth','password_changed','user',$1)`,
        [user.id, user.roleCode],
      );
      return { updated: true };
    });
  }
  revokeSession(sessionId: string, user: RequestUser): Promise<any> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `UPDATE user_sessions SET revoked_at=COALESCE(revoked_at,now()) WHERE id=$1 AND user_id=$2 RETURNING id,revoked_at AS "revokedAt"`,
        [sessionId, user.id],
      );
      if (!result.rows[0]) throw new NotFoundException("Sesión no encontrada.");
      return result.rows[0];
    });
  }
  storeMfaSecret(
    user: RequestUser,
    password: string,
    encrypted: string,
    secret: string,
  ): Promise<{ secret: string; otpauthUrl: string }> {
    return this.database.transactionAsUser(user, async (client) => {
      const account = await client.query<{
        password_hash: string;
        mfa_enabled: boolean;
      }>(`SELECT password_hash,mfa_enabled FROM users WHERE id=$1 FOR UPDATE`, [
        user.id,
      ]);
      if (
        !account.rows[0] ||
        !(await bcrypt.compare(password, account.rows[0].password_hash))
      )
        throw new UnauthorizedException("La contraseña no es correcta.");
      if (account.rows[0].mfa_enabled)
        throw new ConflictException(
          "MFA ya está habilitado. Debes desactivarlo antes de configurarlo nuevamente.",
        );
      await client.query(
        `UPDATE users SET mfa_enabled=false,mfa_secret_encrypted=$2,updated_at=now() WHERE id=$1`,
        [user.id, encrypted],
      );
      const label = encodeURIComponent(`Doc IA:${user.email}`);
      return {
        secret,
        otpauthUrl: `otpauth://totp/${label}?secret=${secret}&issuer=Doc%20IA&digits=6&period=30`,
      };
    });
  }
  confirmMfa(
    user: RequestUser,
    code: string,
    verifyTotpCallback: (secret: string, code: string) => boolean,
    decryptMfaSecretCallback: (value: string) => string,
  ): Promise<{ mfaEnabled: boolean }> {
    return this.database.transactionAsUser(user, async (client) => {
      const record = await client.query<{
        mfa_secret_encrypted: string | null;
      }>(`SELECT mfa_secret_encrypted FROM users WHERE id=$1 FOR UPDATE`, [
        user.id,
      ]);
      if (
        !record.rows[0]?.mfa_secret_encrypted ||
        !verifyTotpCallback(
          decryptMfaSecretCallback(record.rows[0].mfa_secret_encrypted),
          code,
        )
      )
        throw new UnauthorizedException("Código MFA inválido.");
      await client.query(
        `UPDATE users SET mfa_enabled=true,updated_at=now() WHERE id=$1`,
        [user.id],
      );
      await client.query(
        `UPDATE user_sessions SET revoked_at=COALESCE(revoked_at,now()) WHERE user_id=$1 AND id<>$2`,
        [user.id, user.sessionId],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id,new_values) VALUES($1,$2,'auth','mfa_enabled','user',$1,jsonb_build_object('mfaEnabled',true))`,
        [user.id, user.roleCode],
      );
      return { mfaEnabled: true };
    });
  }
  disableMfa(
    user: RequestUser,
    input: DisableMfaDto,
    verifyTotpCallback: (secret: string, code: string) => boolean,
    decryptMfaSecretCallback: (value: string) => string,
  ): Promise<{ mfaEnabled: boolean }> {
    return this.database.transactionAsUser(user, async (client) => {
      const record = await client.query<{
        password_hash: string;
        mfa_secret_encrypted: string | null;
        mfa_enabled: boolean;
      }>(
        `SELECT password_hash,mfa_secret_encrypted,mfa_enabled FROM users WHERE id=$1 FOR UPDATE`,
        [user.id],
      );
      if (
        !record.rows[0] ||
        !(await bcrypt.compare(input.password, record.rows[0].password_hash)) ||
        !record.rows[0].mfa_enabled ||
        !record.rows[0].mfa_secret_encrypted ||
        !verifyTotpCallback(
          decryptMfaSecretCallback(record.rows[0].mfa_secret_encrypted),
          input.code,
        )
      )
        throw new UnauthorizedException(
          "No se pudo validar la desactivación de MFA.",
        );
      await client.query(
        `UPDATE users SET mfa_enabled=false,mfa_secret_encrypted=NULL,updated_at=now() WHERE id=$1`,
        [user.id],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id,new_values) VALUES($1,$2,'auth','mfa_disabled','user',$1,jsonb_build_object('mfaEnabled',false))`,
        [user.id, user.roleCode],
      );
      return { mfaEnabled: false };
    });
  }
  storePhoneVerification(
    normalized: string,
    user: RequestUser,
    hash: string,
  ): Promise<string> {
    return this.database.transactionAsUser(user, async (client) => {
      if (
        (
          await client.query(`SELECT id FROM users WHERE phone=$1 AND id<>$2`, [
            normalized,
            user.id,
          ])
        ).rows[0]
      )
        throw new ConflictException("El teléfono ya pertenece a otra cuenta.");
      const account = await client.query<{ email: string }>(
        `SELECT email::text FROM users WHERE id=$1`,
        [user.id],
      );
      await client.query(
        `UPDATE registration_email_tokens SET consumed_at=COALESCE(consumed_at,now()) WHERE email=$1 AND user_agent LIKE 'phone_verification:%' AND consumed_at IS NULL`,
        [account.rows[0].email],
      );
      return (
        await client.query<{ id: string }>(
          `INSERT INTO registration_email_tokens(email,token_hash,user_agent,expires_at) VALUES($1,$2,$3,now()+interval '10 minutes') RETURNING id`,
          [account.rows[0].email, hash, `phone_verification:${normalized}`],
        )
      ).rows[0].id;
    });
  }
  confirmPhoneVerification(
    user: RequestUser,
    code: string,
  ): Promise<
    | { invalid: true; phone?: undefined; phoneVerified?: undefined }
    | { invalid: false; phone: string; phoneVerified: boolean }
  > {
    return this.database.transactionAsUser(user, async (client) => {
      const token = await client.query<{
        id: string;
        token_hash: string;
        user_agent: string;
        attempt_count: number;
      }>(
        `SELECT token.id,token.token_hash,token.user_agent,token.attempt_count FROM registration_email_tokens token JOIN users ON users.email=token.email WHERE users.id=$1 AND token.user_agent LIKE 'phone_verification:%' AND token.consumed_at IS NULL AND token.expires_at>now() ORDER BY token.created_at DESC LIMIT 1 FOR UPDATE OF token`,
        [user.id],
      );
      if (!token.rows[0] || token.rows[0].attempt_count >= 5)
        return { invalid: true as const };
      if (
        !(await bcrypt.compare(`${code}:${user.id}`, token.rows[0].token_hash))
      ) {
        await client.query(
          `UPDATE registration_email_tokens SET attempt_count=attempt_count+1 WHERE id=$1`,
          [token.rows[0].id],
        );
        return { invalid: true as const };
      }
      const phone = token.rows[0].user_agent.slice(
        "phone_verification:".length,
      );
      await client.query(
        `UPDATE users SET phone=$2,phone_verified_at=now(),updated_at=now() WHERE id=$1`,
        [user.id, phone],
      );
      await client.query(
        `UPDATE registration_email_tokens SET verified_at=now(),consumed_at=now() WHERE id=$1`,
        [token.rows[0].id],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id,new_values) VALUES($1,$2,'auth','phone_verified','user',$1,jsonb_build_object('phoneVerified',true))`,
        [user.id, user.roleCode],
      );
      return { invalid: false as const, phone, phoneVerified: true };
    });
  }
  administrativeResource(
    user: RequestUser,
    resource: "registration-email-tokens" | "user-sessions",
  ): Promise<{ items: any[] }> {
    return this.database.transactionAsUser(user, async (client) => {
      const queries = {
        "registration-email-tokens": `SELECT id,email,requested_ip AS "requestedIp",user_agent AS "userAgent",expires_at AS "expiresAt",verified_at AS "verifiedAt",consumed_at AS "consumedAt",created_user_id AS "createdUserId",attempt_count AS "attemptCount",created_at AS "createdAt" FROM registration_email_tokens ORDER BY created_at DESC LIMIT 200`,
        "user-sessions": `SELECT id,user_id AS "userId",user_agent AS "userAgent",ip_address AS "ipAddress",expires_at AS "expiresAt",revoked_at AS "revokedAt",created_at AS "createdAt" FROM user_sessions ORDER BY created_at DESC LIMIT 200`,
      };
      return { items: (await client.query(queries[resource])).rows };
    });
  }
  createPasswordReset(
    email: string,
    tokenHash: string,
  ): Promise<string | null> {
    return this.database.transactionWithSettings(
      { "app.login_identifier": email },
      async (client) => {
        const user = await client.query<{ id: string }>(
          `SELECT id FROM users WHERE email=$1 AND status='active' LIMIT 1`,
          [email],
        );
        if (!user.rows[0]) return null;
        await client.query("SELECT set_config('app.user_id',$1,true)", [
          user.rows[0].id,
        ]);
        await client.query(
          `UPDATE password_reset_tokens SET used_at=COALESCE(used_at,now())
           WHERE user_id=$1 AND used_at IS NULL`,
          [user.rows[0].id],
        );
        const reset = await client.query<{ id: string }>(
          `INSERT INTO password_reset_tokens(user_id,token_hash,expires_at)
           VALUES($1,$2,now()+interval '30 minutes')
           RETURNING id`,
          [user.rows[0].id, tokenHash],
        );
        await client.query(
          `INSERT INTO audit_events(actor_user_id,module,action,entity_type,entity_id) VALUES($1,'auth','password_reset_requested','user',$1)`,
          [user.rows[0].id],
        );
        return reset.rows[0]?.id ?? null;
      },
    );
  }
  resetPassword(tokenHash: string, passwordHash: string): Promise<void> {
    return this.database.transaction(async (client) => {
      const token = await client.query<{ id: string; user_id: string }>(
        `SELECT id,user_id FROM password_reset_tokens
         WHERE token_hash=$1 AND used_at IS NULL AND expires_at>now()
         ORDER BY created_at DESC LIMIT 1 FOR UPDATE`,
        [tokenHash],
      );
      if (!token.rows[0]) {
        throw new UnauthorizedException(
          "El enlace de recuperación no es válido o expiró.",
        );
      }
      await client.query("SELECT set_config('app.user_id',$1,true)", [
        token.rows[0].user_id,
      ]);
      await client.query(
        `UPDATE users SET password_hash=$1,updated_at=now()
         WHERE id=$2`,
        [passwordHash, token.rows[0].user_id],
      );
      await client.query(
        `UPDATE password_reset_tokens SET used_at=now() WHERE id=$1`,
        [token.rows[0].id],
      );
      await client.query(
        `UPDATE user_sessions SET revoked_at=COALESCE(revoked_at,now())
         WHERE user_id=$1`,
        [token.rows[0].user_id],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,module,action,entity_type,entity_id) VALUES($1,'auth','password_reset_completed','user',$1)`,
        [token.rows[0].user_id],
      );
    });
  }
  findLoginUser(identifier: string): Promise<UserAuthRecord> {
    return this.database.transactionWithSettings(
      { "app.login_identifier": identifier },
      async (client) => this.findUserByIdentifier(client, identifier),
    );
  }
  private async findUserByIdentifier(client: PoolClient, identifier: string) {
    const result = await client.query<UserAuthRecord>(
      `
      WITH selected_user AS (
        SELECT *
        FROM users
        WHERE email = $1 OR phone = $1
        LIMIT 1
      ), active_roles AS (
        SELECT su.id AS user_id, r.id AS role_id, r.code
        FROM selected_user su
        LEFT JOIN roles r ON r.id = su.role_id AND r.is_active
        UNION
        SELECT ur.user_id, r.id AS role_id, r.code
        FROM user_roles ur
        JOIN roles r ON r.id = ur.role_id AND r.is_active
        JOIN selected_user su ON su.id = ur.user_id
        WHERE ur.revoked_at IS NULL
          AND ur.valid_from <= now()
          AND (ur.valid_until IS NULL OR ur.valid_until > now())
      )
      SELECT
        su.id,
        su.email,
        su.phone,
        su.password_hash,
        su.status,
        su.mfa_enabled,
        su.mfa_secret_encrypted,
        COALESCE(MAX(ar.code) FILTER (WHERE ar.role_id = su.role_id), 'patient') AS role_code,
        COALESCE(array_remove(array_agg(DISTINCT ar.code), NULL), ARRAY[]::text[]) AS roles,
        COALESCE(array_remove(array_agg(DISTINCT p.code), NULL), ARRAY[]::text[]) AS permissions
      FROM selected_user su
      LEFT JOIN active_roles ar ON ar.user_id = su.id
        AND (ar.code NOT IN ('doctor_general','doctor_specialist','nurse') OR app_user_clinically_verified(su.id))
      LEFT JOIN role_permissions rp ON rp.role_id = ar.role_id
      LEFT JOIN permissions p ON p.id = rp.permission_id
      GROUP BY su.id, su.email, su.phone, su.password_hash, su.status, su.mfa_enabled, su.mfa_secret_encrypted
      `,
      [identifier],
    );

    return result.rows[0];
  }
  private async findActiveUserById(client: PoolClient, userId: string) {
    const result = await client.query<UserAuthRecord>(
      `
      WITH selected_user AS (
        SELECT *
        FROM users
        WHERE id = $1 AND status = 'active'
      ), active_roles AS (
        SELECT su.id AS user_id, r.id AS role_id, r.code
        FROM selected_user su
        LEFT JOIN roles r ON r.id = su.role_id AND r.is_active
        UNION
        SELECT ur.user_id, r.id AS role_id, r.code
        FROM user_roles ur
        JOIN roles r ON r.id = ur.role_id AND r.is_active
        JOIN selected_user su ON su.id = ur.user_id
        WHERE ur.revoked_at IS NULL
          AND ur.valid_from <= now()
          AND (ur.valid_until IS NULL OR ur.valid_until > now())
      )
      SELECT
        su.id,
        su.email,
        su.phone,
        su.password_hash,
        su.status,
        su.mfa_enabled,
        su.mfa_secret_encrypted,
        COALESCE(MAX(ar.code) FILTER (WHERE ar.role_id = su.role_id), 'patient') AS role_code,
        COALESCE(array_remove(array_agg(DISTINCT ar.code), NULL), ARRAY[]::text[]) AS roles,
        COALESCE(array_remove(array_agg(DISTINCT p.code), NULL), ARRAY[]::text[]) AS permissions
      FROM selected_user su
      LEFT JOIN active_roles ar ON ar.user_id = su.id
        AND (ar.code NOT IN ('doctor_general','doctor_specialist','nurse') OR app_user_clinically_verified(su.id))
      LEFT JOIN role_permissions rp ON rp.role_id = ar.role_id
      LEFT JOIN permissions p ON p.id = rp.permission_id
      GROUP BY su.id, su.email, su.phone, su.password_hash, su.status, su.mfa_enabled, su.mfa_secret_encrypted
      `,
      [userId],
    );

    const user = result.rows[0];

    if (!user) {
      throw new UnauthorizedException("Usuario no habilitado");
    }

    return user;
  }
  private async findActiveSession(
    client: PoolClient,
    sessionId: string,
    userId: string,
  ) {
    const result = await client.query<SessionRecord>(
      `
      SELECT id, user_id, refresh_token_hash
      FROM user_sessions
      WHERE id = $1
        AND user_id = $2
        AND revoked_at IS NULL
        AND expires_at > now()
      `,
      [sessionId, userId],
    );

    const session = result.rows[0];

    if (!session) {
      throw new UnauthorizedException("Sesión inválida o expirada");
    }

    return session;
  }

  private authSettings(user: UserAuthRecord, sessionId: string) {
    return {
      "app.user_id": user.id,
      "app.session_id": sessionId,
      "app.role_code": user.role_code,
      "app.roles": user.roles,
      "app.permissions": user.permissions,
    };
  }
}
