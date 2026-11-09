import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { UsersRepository } from "../../domain/ports/users.repository";
@Injectable()
export class PostgresUsersRepository implements UsersRepository {
  constructor(private readonly database: DatabaseService) {}
  overview(user: RequestUser) {
    return this.database.transactionAsUser(user, async (client) => {
      const users = await client.query(
        `SELECT app_user.id,app_user.email,app_user.phone,app_user.status,app_user.mfa_enabled AS "mfaEnabled",app_user.last_login_at AS "lastLoginAt",app_user.created_at AS "createdAt",concat_ws(' ',person.first_name,person.last_name,person.second_last_name) AS "fullName",COALESCE(jsonb_agg(DISTINCT role.code) FILTER(WHERE role.code IS NOT NULL),'[]'::jsonb) AS roles FROM users app_user LEFT JOIN persons person ON person.user_id=app_user.id LEFT JOIN user_roles link ON link.user_id=app_user.id AND link.revoked_at IS NULL AND (link.valid_until IS NULL OR link.valid_until>now()) LEFT JOIN roles role ON role.id=link.role_id GROUP BY app_user.id,person.id ORDER BY app_user.created_at DESC`,
      );
      const roles = await client.query(
        `SELECT role.id,role.code,role.name,role.description,role.is_system AS "isSystem",COALESCE(jsonb_agg(permission.code ORDER BY permission.code) FILTER(WHERE permission.code IS NOT NULL),'[]'::jsonb) AS permissions FROM roles role LEFT JOIN role_permissions link ON link.role_id=role.id LEFT JOIN permissions permission ON permission.id=link.permission_id GROUP BY role.id ORDER BY role.name`,
      );
      const permissions = await client.query(
        `SELECT id,code,module,description FROM permissions ORDER BY module,code`,
      );
      return {
        users: users.rows,
        roles: roles.rows,
        permissions: permissions.rows,
      };
    });
  }
  updateStatus(user: RequestUser, id: string, status: string, reason?: string) {
    if (id === user.id && status !== "active")
      throw new BadRequestException("No puedes suspender tu propia cuenta.");
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `UPDATE users SET status=$2::user_status,suspension_reason=CASE WHEN $2='suspended' THEN NULLIF($3,'') ELSE NULL END,suspended_at=CASE WHEN $2='suspended' THEN now() ELSE NULL END,reactivated_at=CASE WHEN $2='active' THEN now() ELSE reactivated_at END,updated_at=now() WHERE id=$1 RETURNING id`,
        [id, status, reason?.trim() ?? ""],
      );
      if (!result.rowCount)
        throw new NotFoundException("Usuario no encontrado.");
    });
  }
  updateRoles(user: RequestUser, id: string, roleCodes: string[]) {
    const unique = [...new Set(roleCodes)];
    if (!unique.length)
      throw new BadRequestException(
        "El usuario debe conservar al menos un rol.",
      );
    return this.database.transactionAsUser(user, async (client) => {
      const roles = await client.query<{ id: string; code: string }>(
        `SELECT id,code FROM roles WHERE code=ANY($1::text[]) AND is_active`,
        [unique],
      );
      if (roles.rowCount !== unique.length)
        throw new BadRequestException("Uno o más roles no son válidos.");
      if (id === user.id && !unique.includes("admin"))
        throw new BadRequestException(
          "No puedes retirar tu propio rol administrador.",
        );
      const exists = await client.query(`SELECT 1 FROM users WHERE id=$1`, [
        id,
      ]);
      if (!exists.rowCount)
        throw new NotFoundException("Usuario no encontrado.");
      await client.query(
        `UPDATE user_roles SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL`,
        [id],
      );
      for (const role of roles.rows)
        await client.query(
          `INSERT INTO user_roles(user_id,role_id,granted_by_user_id) VALUES($1,$2,$3) ON CONFLICT(user_id,role_id) DO UPDATE SET granted_by_user_id=$3,valid_from=now(),valid_until=NULL,revoked_at=NULL`,
          [id, role.id, user.id],
        );
      await client.query(
        `UPDATE users SET role_id=$2,updated_at=now() WHERE id=$1`,
        [id, roles.rows[0].id],
      );
    });
  }
}
