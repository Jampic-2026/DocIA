import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
@Injectable()
export class PostgresAdministrationRepository {
  constructor(private readonly database: DatabaseService) {}
  settings(user: RequestUser) {
    return this.database.transactionAsUser(user, async (client) => ({
      items: (
        await client.query(
          `SELECT setting_key AS "key",value,description,requires_clinical_approval AS "requiresClinicalApproval",updated_at AS "updatedAt" FROM system_settings ORDER BY setting_key`,
        )
      ).rows,
    }));
  }
  updateSetting(
    user: RequestUser,
    key: string,
    input: {
      value: unknown;
      description?: string;
      requiresClinicalApproval?: boolean;
    },
  ) {
    if (!/^[a-z][a-z0-9_.-]{2,119}$/.test(key)) {
      throw new BadRequestException("La clave del parámetro no es válida.");
    }
    return this.database.transactionAsUser(user, async (client) => {
      const old = await client.query(
        `SELECT * FROM system_settings WHERE setting_key=$1 FOR UPDATE`,
        [key],
      );
      const requiresClinicalApproval =
        input.requiresClinicalApproval ??
        old.rows[0]?.requires_clinical_approval ??
        false;
      if (
        requiresClinicalApproval &&
        !user.roles.includes("clinical_supervisor")
      ) {
        throw new BadRequestException(
          "Este parámetro requiere aprobación de supervisión clínica.",
        );
      }
      await client.query(
        `INSERT INTO system_settings(setting_key,value,description,requires_clinical_approval,updated_by_user_id) VALUES($1,$2::jsonb,NULLIF($3,''),COALESCE($4,false),$5) ON CONFLICT(setting_key) DO UPDATE SET value=excluded.value,description=COALESCE(excluded.description,system_settings.description),requires_clinical_approval=COALESCE($4,system_settings.requires_clinical_approval),updated_by_user_id=$5,updated_at=now()`,
        [
          key,
          JSON.stringify(input.value),
          input.description?.trim() ?? "",
          input.requiresClinicalApproval ?? null,
          user.id,
        ],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,
           entity_id,old_values,new_values)
         VALUES($1,$2,'administration','system_setting_updated','system_setting',
           NULL,$3::jsonb,jsonb_build_object('key',$4,'value',$5::jsonb))`,
        [
          user.id,
          user.roleCode,
          old.rows[0] ? JSON.stringify(old.rows[0]) : null,
          key,
          JSON.stringify(input.value),
        ],
      );
      return { updated: true };
    });
  }

  roles(user: RequestUser) {
    return this.database.transactionAsUser(user, async (client) => ({
      items: (
        await client.query(
          `SELECT role.id,role.code,role.name,role.description,role.is_system AS "isSystem",
            role.is_active AS "isActive",role.created_at AS "createdAt",
            COALESCE(jsonb_agg(permission.code ORDER BY permission.code)
              FILTER(WHERE permission.code IS NOT NULL),'[]') AS permissions
           FROM roles role LEFT JOIN role_permissions assignment ON assignment.role_id=role.id
           LEFT JOIN permissions permission ON permission.id=assignment.permission_id
           GROUP BY role.id ORDER BY role.name`,
        )
      ).rows,
    }));
  }

  permissions(user: RequestUser) {
    return this.database.transactionAsUser(user, async (client) => ({
      items: (
        await client.query(
          `SELECT id,code,module,description,created_at AS "createdAt"
           FROM permissions ORDER BY module,code`,
        )
      ).rows,
    }));
  }

  createRole(
    user: RequestUser,
    input: {
      code: string;
      name: string;
      description?: string;
      isActive?: boolean;
    },
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      try {
        const result = await client.query(
          `INSERT INTO roles(code,name,description,is_system,is_active)
           VALUES($1,$2,NULLIF($3,''),FALSE,$4) RETURNING *`,
          [
            input.code,
            input.name.trim(),
            input.description?.trim() ?? "",
            input.isActive ?? true,
          ],
        );
        await this.audit(
          client,
          user,
          "role_created",
          "role",
          result.rows[0].id,
          null,
          result.rows[0],
        );
        return result.rows[0];
      } catch (error) {
        if ((error as { code?: string }).code === "23505")
          throw new ConflictException("El código del rol ya existe.");
        throw error;
      }
    });
  }

  updateRole(
    user: RequestUser,
    id: string,
    input: {
      code: string;
      name: string;
      description?: string;
      isActive?: boolean;
    },
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const old = await client.query(
        `SELECT * FROM roles WHERE id=$1 FOR UPDATE`,
        [id],
      );
      if (!old.rows[0]) throw new NotFoundException("El rol no existe.");
      if (old.rows[0].is_system && input.code !== old.rows[0].code) {
        throw new BadRequestException(
          "No se puede cambiar el código de un rol del sistema.",
        );
      }
      if (old.rows[0].code === "admin" && input.isActive === false) {
        throw new BadRequestException(
          "No se puede desactivar el rol administrador.",
        );
      }
      const result = await client.query(
        `UPDATE roles SET code=$2,name=$3,description=NULLIF($4,''),
           is_active=COALESCE($5,is_active),updated_at=now() WHERE id=$1 RETURNING *`,
        [
          id,
          input.code,
          input.name.trim(),
          input.description?.trim() ?? "",
          input.isActive ?? null,
        ],
      );
      await this.audit(
        client,
        user,
        "role_updated",
        "role",
        id,
        old.rows[0],
        result.rows[0],
      );
      return result.rows[0];
    });
  }

  assignPermissions(
    user: RequestUser,
    roleId: string,
    input: { permissionCodes: string[]; reason: string },
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const role = await client.query<{ code: string }>(
        `SELECT code FROM roles WHERE id=$1 FOR UPDATE`,
        [roleId],
      );
      if (!role.rows[0]) throw new NotFoundException("El rol no existe.");
      if (
        role.rows[0].code === "admin" &&
        !input.permissionCodes.includes("administration.manage")
      ) {
        throw new BadRequestException(
          "El rol administrador debe conservar administration.manage.",
        );
      }
      const permissions = await client.query<{ id: string; code: string }>(
        `SELECT id,code FROM permissions WHERE code=ANY($1::text[])`,
        [input.permissionCodes],
      );
      if (permissions.rowCount !== input.permissionCodes.length) {
        throw new BadRequestException("Uno o más permisos no existen.");
      }
      const old = await client.query<{ code: string }>(
        `SELECT permission.code FROM role_permissions assignment
         JOIN permissions permission ON permission.id=assignment.permission_id
         WHERE assignment.role_id=$1 ORDER BY permission.code`,
        [roleId],
      );
      await client.query(`DELETE FROM role_permissions WHERE role_id=$1`, [
        roleId,
      ]);
      await client.query(
        `INSERT INTO role_permissions(role_id,permission_id)
         SELECT $1,id FROM permissions WHERE code=ANY($2::text[])`,
        [roleId, input.permissionCodes],
      );
      await this.audit(
        client,
        user,
        "role_permissions_replaced",
        "role",
        roleId,
        { permissions: old.rows.map((row) => row.code) },
        { permissions: input.permissionCodes },
        input.reason.trim(),
      );
      return { roleId, permissionCodes: [...input.permissionCodes].sort() };
    });
  }

  sites(user: RequestUser) {
    return this.database.transactionAsUser(user, async (client) => ({
      items: (
        await client.query(
          `SELECT id,partner_id AS "partnerId",code,name,site_type AS "siteType",address,latitude::float8,longitude::float8,phone,is_active AS "isActive",created_at AS "createdAt",updated_at AS "updatedAt" FROM operating_sites ORDER BY name`,
        )
      ).rows,
    }));
  }

  createSite(user: RequestUser, input: Record<string, unknown>) {
    return this.saveSite(user, undefined, input);
  }

  updateSite(user: RequestUser, id: string, input: Record<string, unknown>) {
    return this.saveSite(user, id, input);
  }

  private saveSite(
    user: RequestUser,
    id: string | undefined,
    input: Record<string, unknown>,
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const old = id
        ? await client.query(
            `SELECT * FROM operating_sites WHERE id=$1 FOR UPDATE`,
            [id],
          )
        : null;
      if (id && !old?.rows[0])
        throw new NotFoundException("La sede no existe.");
      try {
        const result = id
          ? await client.query(
              `UPDATE operating_sites SET partner_id=$2,code=$3,name=$4,site_type=$5,address=NULLIF($6,''),latitude=$7,longitude=$8,phone=NULLIF($9,''),is_active=COALESCE($10,is_active),updated_at=now() WHERE id=$1 RETURNING *`,
              [
                id,
                input.partnerId ?? null,
                input.code,
                String(input.name).trim(),
                String(input.siteType).trim(),
                String(input.address ?? "").trim(),
                input.latitude ?? null,
                input.longitude ?? null,
                String(input.phone ?? "").trim(),
                input.isActive ?? null,
              ],
            )
          : await client.query(
              `INSERT INTO operating_sites(partner_id,code,name,site_type,address,latitude,longitude,phone,is_active) VALUES($1,$2,$3,$4,NULLIF($5,''),$6,$7,NULLIF($8,''),$9) RETURNING *`,
              [
                input.partnerId ?? null,
                input.code,
                String(input.name).trim(),
                String(input.siteType).trim(),
                String(input.address ?? "").trim(),
                input.latitude ?? null,
                input.longitude ?? null,
                String(input.phone ?? "").trim(),
                input.isActive ?? true,
              ],
            );
        await this.audit(
          client,
          user,
          id ? "operating_site_updated" : "operating_site_created",
          "operating_site",
          result.rows[0].id,
          old?.rows[0] ?? null,
          result.rows[0],
        );
        return result.rows[0];
      } catch (error) {
        if ((error as { code?: string }).code === "23505")
          throw new ConflictException("El código de la sede ya existe.");
        throw error;
      }
    });
  }

  rules(user: RequestUser) {
    return this.database.transactionAsUser(user, async (client) => ({
      items: (
        await client.query(
          `SELECT rule.*,COALESCE((SELECT jsonb_agg(history ORDER BY history.created_at DESC) FROM business_rule_history history WHERE history.business_rule_id=rule.id),'[]') AS history FROM business_rules rule ORDER BY rule.domain,rule.code`,
        )
      ).rows,
    }));
  }

  createRule(user: RequestUser, input: Record<string, unknown>) {
    return this.saveRule(user, undefined, input);
  }

  updateRule(user: RequestUser, id: string, input: Record<string, unknown>) {
    return this.saveRule(user, id, input);
  }

  private saveRule(
    user: RequestUser,
    id: string | undefined,
    input: Record<string, unknown>,
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const old = id
        ? await client.query(
            `SELECT * FROM business_rules WHERE id=$1 FOR UPDATE`,
            [id],
          )
        : null;
      if (id && !old?.rows[0])
        throw new NotFoundException("La regla no existe.");
      const requiresApproval = Boolean(input.requiresClinicalApproval);
      if (requiresApproval) {
        const approver = await client.query(
          `SELECT id FROM professionals WHERE id=$1 AND professional_type='clinical_supervisor' AND verification_status='approved'`,
          [input.approvedByProfessionalId ?? null],
        );
        if (!approver.rows[0])
          throw new BadRequestException(
            "La regla requiere aprobación de un supervisor clínico verificado.",
          );
      }
      if (
        input.validFrom &&
        input.validUntil &&
        new Date(String(input.validUntil)) <= new Date(String(input.validFrom))
      ) {
        throw new BadRequestException(
          "La vigencia final debe ser posterior a la inicial.",
        );
      }
      try {
        const result = id
          ? await client.query(
              `UPDATE business_rules SET code=$2,domain=$3,name=$4,configuration=$5::jsonb,version=version+1,is_active=COALESCE($6,is_active),requires_clinical_approval=$7,approved_by_professional_id=$8,approved_at=CASE WHEN $8::uuid IS NULL THEN NULL ELSE now() END,valid_from=COALESCE($9::timestamptz,valid_from),valid_until=$10::timestamptz,updated_at=now() WHERE id=$1 RETURNING *`,
              [
                id,
                input.code,
                input.domain,
                String(input.name).trim(),
                JSON.stringify(input.configuration),
                input.isActive ?? null,
                requiresApproval,
                input.approvedByProfessionalId ?? null,
                input.validFrom ?? null,
                input.validUntil ?? null,
              ],
            )
          : await client.query(
              `INSERT INTO business_rules(code,domain,name,configuration,is_active,requires_clinical_approval,approved_by_professional_id,approved_at,valid_from,valid_until,created_by_user_id) VALUES($1,$2,$3,$4::jsonb,$5,$6,$7,CASE WHEN $7::uuid IS NULL THEN NULL ELSE now() END,COALESCE($8::timestamptz,now()),$9::timestamptz,$10) RETURNING *`,
              [
                input.code,
                input.domain,
                String(input.name).trim(),
                JSON.stringify(input.configuration),
                input.isActive ?? true,
                requiresApproval,
                input.approvedByProfessionalId ?? null,
                input.validFrom ?? null,
                input.validUntil ?? null,
                user.id,
              ],
            );
        await client.query(
          `INSERT INTO business_rule_history(business_rule_id,changed_by_user_id,old_configuration,new_configuration,reason) VALUES($1,$2,$3::jsonb,$4::jsonb,$5)`,
          [
            result.rows[0].id,
            user.id,
            old?.rows[0] ? JSON.stringify(old.rows[0].configuration) : null,
            JSON.stringify(input.configuration),
            String(input.reason).trim(),
          ],
        );
        await this.audit(
          client,
          user,
          id ? "business_rule_updated" : "business_rule_created",
          "business_rule",
          result.rows[0].id,
          old?.rows[0] ?? null,
          result.rows[0],
          String(input.reason).trim(),
        );
        return result.rows[0];
      } catch (error) {
        if ((error as { code?: string }).code === "23505")
          throw new ConflictException("El código de la regla ya existe.");
        throw error;
      }
    });
  }

  operationalReport(user: RequestUser) {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(`SELECT
        (SELECT count(*)::int FROM users WHERE status='active') AS "activeUsers",
        (SELECT count(*)::int FROM appointments WHERE created_at>=current_date) AS "appointmentsToday",
        (SELECT count(*)::int FROM emergency_events WHERE status NOT IN ('closed','cancelled')) AS "activeEmergencies",
        (SELECT count(*)::int FROM payment_orders WHERE status='pending') AS "pendingPaymentOrders",
        (SELECT count(*)::int FROM incidents WHERE status IN ('open','in_review')) AS "openIncidents",
        (SELECT count(*)::int FROM partner_subscriptions WHERE status IN ('active','grace_period')) AS "activePartnerSubscriptions",
        (SELECT count(*)::int FROM personnel_applications WHERE status IN ('pending','under_review')) AS "pendingPersonnelApplications"`);
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,
           entity_type,new_values)
         VALUES($1,$2,'administration','operational_report_viewed',
           'operational_report',$3::jsonb)`,
        [user.id, user.roleCode, JSON.stringify(result.rows[0])],
      );
      return { generatedAt: new Date().toISOString(), ...result.rows[0] };
    });
  }

  private async audit(
    client: { query: (text: string, values?: unknown[]) => Promise<unknown> },
    user: RequestUser,
    action: string,
    entityType: string,
    entityId: string,
    oldValues: unknown,
    newValues: unknown,
    reason: string | null = null,
  ) {
    await client.query(
      `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id,old_values,new_values,reason) VALUES($1,$2,'administration',$3,$4,$5,$6::jsonb,$7::jsonb,$8)`,
      [
        user.id,
        user.roleCode,
        action,
        entityType,
        entityId,
        oldValues ? JSON.stringify(oldValues) : null,
        newValues ? JSON.stringify(newValues) : null,
        reason,
      ],
    );
  }
}
