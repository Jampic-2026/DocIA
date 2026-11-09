import { SMS_PROVIDER, SmsProvider } from "../domain/ports/sms";
import {
  BadRequestException,
  Injectable,
  Inject as InjectRepository,
  Logger,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { appendWebQuery } from "../../../config/public-urls";
import { JwtService, JwtSignOptions } from "@nestjs/jwt";
import * as bcrypt from "bcrypt";
import {
  createCipheriv,
  createDecipheriv,
  createHash,
  createHmac,
  randomBytes,
  randomInt,
  randomUUID,
} from "node:crypto";
import { RequestUser } from "../../../common/types/request-user";
import { MailService } from "../../mail/application/mail.service";
import {
  RequestContext,
  UserAuthRecord,
} from "../domain/auth-persistence-types";
import { AuthTokenPayload } from "../domain/auth-token-payload";
import {
  AUTH_REPOSITORY,
  AuthRepository,
} from "../domain/ports/auth.repository";
import { ChangePasswordDto } from "../interfaces/http/dto/change-password.dto";
import { LoginDto } from "../interfaces/http/dto/login.dto";
import { LogoutDto } from "../interfaces/http/dto/logout.dto";
import { RefreshTokenDto } from "../interfaces/http/dto/refresh-token.dto";
import {
  CompleteRegistrationDto,
  RequestRegistrationDto,
} from "../interfaces/http/dto/registration.dto";
import { RequestPasswordResetDto } from "../interfaces/http/dto/request-password-reset.dto";
import { ResetPasswordDto } from "../interfaces/http/dto/reset-password.dto";
import { DisableMfaDto } from "../interfaces/http/dto/security.dto";

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @InjectRepository(AUTH_REPOSITORY)
    private readonly repository: AuthRepository,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    private readonly mail: MailService,
    @InjectRepository(SMS_PROVIDER) private readonly sms: SmsProvider,
  ) {}

  async login(dto: LoginDto, context: RequestContext) {
    const user = await this.findUserForLogin(dto);
    const passwordMatches = await bcrypt.compare(
      dto.password,
      user.password_hash,
    );

    if (!passwordMatches) {
      throw new UnauthorizedException("Credenciales inválidas");
    }

    if (user.mfa_enabled) {
      if (
        !dto.mfaCode ||
        !user.mfa_secret_encrypted ||
        !this.verifyTotp(
          this.decryptMfaSecret(user.mfa_secret_encrypted),
          dto.mfaCode,
        )
      )
        throw new UnauthorizedException("Código MFA requerido o inválido");
    }

    if (user.status !== "active") {
      throw new UnauthorizedException("Usuario inactivo o no habilitado");
    }

    const sessionId = randomUUID();
    const tokens = await this.issueTokens(user, sessionId);
    const refreshTokenHash = await bcrypt.hash(tokens.refreshToken, 12);
    const refreshExpiresAt = this.expirationToDate(
      this.config.get<string>("JWT_REFRESH_EXPIRES_IN", "7d"),
    );

    await this.repository.createLoginSession(
      sessionId,
      user,
      refreshTokenHash,
      context,
      refreshExpiresAt,
    );

    return this.authResponse(user, sessionId, tokens);
  }

  async refresh(dto: RefreshTokenDto) {
    const payload = await this.verifyRefreshToken(dto.refreshToken);

    return this.repository.rotateRefreshSession(
      payload,
      dto,
      this.issueTokens.bind(this),
      this.expirationToDate.bind(this),
      this.authResponse.bind(this),
      this.config.get<string>("JWT_REFRESH_EXPIRES_IN", "7d"),
    );
  }

  async logout(dto: LogoutDto) {
    const payload = await this.verifyRefreshToken(dto.refreshToken);

    await this.repository.revokeLogoutSession(payload);

    return { status: "ok" };
  }

  me(user: RequestUser) {
    return { user };
  }
  sessions(user: RequestUser) {
    return this.repository.listSessions(user);
  }

  async requestRegistration(
    input: RequestRegistrationDto,
    context: RequestContext,
  ) {
    const email = input.email.trim().toLowerCase();
    const token = randomBytes(32).toString("hex");
    const hash = this.hashResetToken(token);
    const id = await this.repository.createRegistrationRequest(
      email,
      hash,
      context,
    );
    const url = appendWebQuery(
      this.config.getOrThrow<string>("email.registrationUrl"),
      { token },
    );
    try {
      await this.mail.sendRegistrationVerification({
        to: email,
        verificationUrl: url,
        expiresInMinutes: 30,
        idempotencyKey: `registration/${id}`,
      });
    } catch (error) {
      this.logger.error(
        "No se pudo enviar el correo de registro.",
        error instanceof Error ? error.stack : String(error),
      );
    }
    return {
      message: "Revisa tu correo para completar el registro.",
      ...(this.config.get<string>("nodeEnv") !== "production"
        ? { developmentToken: token }
        : {}),
    };
  }

  async completeRegistration(input: CompleteRegistrationDto) {
    if (!input.acceptRequiredConsents)
      throw new BadRequestException(
        "Debes aceptar los consentimientos obligatorios.",
      );
    const tokenHash = this.hashResetToken(input.token.trim());
    const passwordHash = await bcrypt.hash(input.password, 12);
    const birth = new Date(`${input.birthDate}T00:00:00Z`);
    const today = new Date();
    const todayUtc = new Date(
      Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()),
    );
    if (birth > todayUtc)
      throw new BadRequestException(
        "La fecha de nacimiento no puede estar en el futuro.",
      );
    const adultThreshold = new Date(
      Date.UTC(
        todayUtc.getUTCFullYear() - 18,
        todayUtc.getUTCMonth(),
        todayUtc.getUTCDate(),
      ),
    );
    const isMinor = birth > adultThreshold;
    return this.repository.completeRegistration(
      tokenHash,
      isMinor,
      input,
      passwordHash,
    );
  }

  async changePassword(user: RequestUser, input: ChangePasswordDto) {
    return this.repository.changePassword(user, input);
  }
  async revokeSession(user: RequestUser, sessionId: string) {
    return this.repository.revokeSession(sessionId, user);
  }

  async setupMfa(user: RequestUser, password: string) {
    const secret = this.base32Encode(randomBytes(20));
    const encrypted = this.encryptMfaSecret(secret);
    return this.repository.storeMfaSecret(user, password, encrypted, secret);
  }
  async confirmMfa(user: RequestUser, code: string) {
    return this.repository.confirmMfa(
      user,
      code,
      this.verifyTotp.bind(this),
      this.decryptMfaSecret.bind(this),
    );
  }
  async disableMfa(user: RequestUser, input: DisableMfaDto) {
    return this.repository.disableMfa(
      user,
      input,
      this.verifyTotp.bind(this),
      this.decryptMfaSecret.bind(this),
    );
  }

  async requestPhoneVerification(user: RequestUser, phone: string) {
    const normalized = phone.replace(/[\s-]/g, "");
    const code = randomInt(100000, 1000000).toString();
    const hash = await bcrypt.hash(`${code}:${user.id}`, 10);
    await this.repository.storePhoneVerification(normalized, user, hash);
    await this.sms.send(
      normalized,
      `Tu código de verificación de Doc IA es ${code}. Vence en 10 minutos.`,
    );
    return {
      message: "Enviamos un código de verificación a tu teléfono.",
      ...(this.config.get<string>("nodeEnv") !== "production"
        ? { developmentCode: code }
        : {}),
    };
  }
  async confirmPhoneVerification(user: RequestUser, code: string) {
    const result = await this.repository.confirmPhoneVerification(user, code);
    if (result.invalid)
      throw new UnauthorizedException("El código no es válido o expiró.");
    return { phone: result.phone, phoneVerified: result.phoneVerified };
  }

  async administrativeResource(
    user: RequestUser,
    resource: "registration-email-tokens" | "user-sessions",
  ) {
    return this.repository.administrativeResource(user, resource);
  }

  async requestPasswordReset(input: RequestPasswordResetDto) {
    const email = input.email.trim().toLowerCase();
    const token = randomBytes(32).toString("hex");
    const tokenHash = this.hashResetToken(token);
    const created = await this.repository.createPasswordReset(email, tokenHash);

    if (created) {
      const resetUrl = appendWebQuery(
        this.config.getOrThrow<string>("email.passwordResetUrl"),
        { token },
      );
      try {
        await this.mail.sendPasswordReset({
          to: email,
          resetUrl,
          expiresInMinutes: 30,
          idempotencyKey: `password-reset/${created}`,
        });
      } catch (error) {
        this.logger.error(
          "No se pudo enviar el correo de recuperación de contraseña.",
          error instanceof Error ? error.stack : String(error),
        );
      }
    }

    return {
      message:
        "Si el correo está registrado, recibirás instrucciones para cambiar tu contraseña.",
      ...(created && this.config.get<string>("nodeEnv") !== "production"
        ? { developmentToken: token }
        : {}),
    };
  }

  async resetPassword(input: ResetPasswordDto) {
    const tokenHash = this.hashResetToken(input.token.trim());
    const passwordHash = await bcrypt.hash(input.newPassword, 12);
    await this.repository.resetPassword(tokenHash, passwordHash);
    return { message: "Tu contraseña fue actualizada correctamente." };
  }

  private async findUserForLogin(dto: LoginDto) {
    const identifier = dto.email ?? dto.phone;

    if (!identifier) {
      throw new UnauthorizedException("Email o teléfono requerido");
    }

    const user = await this.repository.findLoginUser(identifier);

    if (!user) {
      throw new UnauthorizedException("Credenciales inválidas");
    }

    return user;
  }

  private async issueTokens(user: UserAuthRecord, sessionId: string) {
    const basePayload = {
      sub: user.id,
      sid: sessionId,
      email: user.email,
      phone: user.phone,
      roleCode: user.role_code,
      roles: user.roles,
      permissions: user.permissions,
    };

    const accessPayload: AuthTokenPayload = {
      ...basePayload,
      tokenUse: "access",
    };
    const refreshPayload: AuthTokenPayload = {
      ...basePayload,
      tokenUse: "refresh",
    };

    const accessToken = await this.jwtService.signAsync(accessPayload, {
      secret: this.config.getOrThrow<string>("JWT_ACCESS_SECRET"),
      expiresIn: this.jwtExpiresIn("JWT_ACCESS_EXPIRES_IN", "15m"),
    });

    const refreshToken = await this.jwtService.signAsync(refreshPayload, {
      secret: this.config.getOrThrow<string>("JWT_REFRESH_SECRET"),
      expiresIn: this.jwtExpiresIn("JWT_REFRESH_EXPIRES_IN", "7d"),
    });

    return { accessToken, refreshToken };
  }

  private async verifyRefreshToken(token: string) {
    try {
      const payload = await this.jwtService.verifyAsync<AuthTokenPayload>(
        token,
        {
          secret: this.config.getOrThrow<string>("JWT_REFRESH_SECRET"),
        },
      );

      if (payload.tokenUse !== "refresh") {
        throw new UnauthorizedException("Refresh token inválido");
      }

      return payload;
    } catch {
      throw new UnauthorizedException("Refresh token inválido o expirado");
    }
  }

  private authResponse(
    user: UserAuthRecord,
    sessionId: string,
    tokens: { accessToken: string; refreshToken: string },
  ) {
    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      tokenType: "Bearer",
      user: {
        id: user.id,
        sessionId,
        email: user.email,
        phone: user.phone,
        roleCode: user.role_code,
        roles: user.roles,
        permissions: user.permissions,
      },
    };
  }

  private jwtExpiresIn(
    key: string,
    fallback: string,
  ): JwtSignOptions["expiresIn"] {
    return this.config.get<string>(
      key,
      fallback,
    ) as JwtSignOptions["expiresIn"];
  }

  private expirationToDate(value: string) {
    const match = /^(\d+)([smhd])$/.exec(value.trim());

    if (!match) {
      return new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    }

    const amount = Number(match[1]);
    const unit = match[2];
    const multipliers: Record<string, number> = {
      s: 1000,
      m: 60 * 1000,
      h: 60 * 60 * 1000,
      d: 24 * 60 * 60 * 1000,
    };

    return new Date(Date.now() + amount * multipliers[unit]);
  }

  private hashResetToken(token: string) {
    return createHash("sha256").update(token).digest("hex");
  }

  private mfaKey() {
    const value = this.config.get<string>("security.mfaEncryptionKey");
    if (!value)
      throw new BadRequestException(
        "MFA todavía no está habilitado en la configuración de la API.",
      );
    return createHash("sha256").update(value).digest();
  }
  private encryptMfaSecret(secret: string) {
    const iv = randomBytes(12);
    const cipher = createCipheriv("aes-256-gcm", this.mfaKey(), iv);
    const encrypted = Buffer.concat([
      cipher.update(secret, "utf8"),
      cipher.final(),
    ]);
    return [
      iv.toString("base64url"),
      cipher.getAuthTag().toString("base64url"),
      encrypted.toString("base64url"),
    ].join(".");
  }
  private decryptMfaSecret(value: string) {
    const [iv, tag, data] = value.split(".");
    const decipher = createDecipheriv(
      "aes-256-gcm",
      this.mfaKey(),
      Buffer.from(iv, "base64url"),
    );
    decipher.setAuthTag(Buffer.from(tag, "base64url"));
    return Buffer.concat([
      decipher.update(Buffer.from(data, "base64url")),
      decipher.final(),
    ]).toString("utf8");
  }
  private verifyTotp(secret: string, code: string) {
    const counter = Math.floor(Date.now() / 30000);
    return [-1, 0, 1].some(
      (offset) => this.totp(secret, counter + offset) === code,
    );
  }
  private totp(secret: string, counter: number) {
    const buffer = Buffer.alloc(8);
    buffer.writeBigUInt64BE(BigInt(counter));
    const hash = createHmac("sha1", this.base32Decode(secret))
      .update(buffer)
      .digest();
    const offset = hash[hash.length - 1] & 15;
    const value = (hash.readUInt32BE(offset) & 0x7fffffff) % 1000000;
    return value.toString().padStart(6, "0");
  }
  private base32Encode(value: Buffer) {
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    let bits = 0,
      current = 0,
      result = "";
    for (const byte of value) {
      current = (current << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        result += alphabet[(current >>> (bits - 5)) & 31];
        bits -= 5;
      }
    }
    if (bits) result += alphabet[(current << (5 - bits)) & 31];
    return result;
  }
  private base32Decode(value: string) {
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    let bits = 0,
      current = 0;
    const bytes: number[] = [];
    for (const char of value.replace(/=+$/, "")) {
      const index = alphabet.indexOf(char.toUpperCase());
      if (index < 0) throw new BadRequestException("Secreto MFA inválido.");
      current = (current << 5) | index;
      bits += 5;
      if (bits >= 8) {
        bytes.push((current >>> (bits - 8)) & 255);
        bits -= 8;
      }
    }
    return Buffer.from(bytes);
  }
}
