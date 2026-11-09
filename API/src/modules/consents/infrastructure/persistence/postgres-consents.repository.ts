import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { ConsentsRepository } from "../../domain/ports/consents.repository";

@Injectable()
export class PostgresConsentsRepository implements ConsentsRepository {
  constructor(private readonly database: DatabaseService) {}

  listForUser(user: RequestUser): Promise<unknown[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `SELECT type.code,type.name,type.description,type.version,
          type.is_required AS "isRequired",
          COALESCE(current.status::text,'pending') AS status,
          current.accepted_at AS "acceptedAt",
          current.revoked_at AS "revokedAt"
         FROM consent_types type
         LEFT JOIN LATERAL (
           SELECT consent.status,consent.accepted_at,consent.revoked_at
           FROM patient_consents consent
           JOIN patients patient ON patient.id=consent.patient_id
           JOIN persons person ON person.id=patient.person_id
           WHERE consent.consent_type_id=type.id AND person.user_id=$1
           ORDER BY consent.created_at DESC LIMIT 1
         ) current ON true
         WHERE type.is_active
         ORDER BY type.is_required DESC,type.name`,
        [user.id],
      );
      return result.rows;
    });
  }

  isAccepted(user: RequestUser, code: string): Promise<boolean> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `SELECT 1 FROM patient_consents consent
         JOIN consent_types type ON type.id=consent.consent_type_id
         JOIN patients patient ON patient.id=consent.patient_id
         JOIN persons person ON person.id=patient.person_id
         WHERE person.user_id=$1 AND type.code=$2 AND type.is_active
           AND consent.status='accepted'
         ORDER BY consent.created_at DESC LIMIT 1`,
        [user.id, code],
      );
      return Boolean(result.rows[0]);
    });
  }

  accept(
    user: RequestUser,
    code: string,
    metadata: { ipAddress?: string; userAgent?: string },
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const context = await client.query<{
        patient_id: string;
        type_id: string;
      }>(
        `SELECT patient.id AS patient_id,type.id AS type_id
         FROM patients patient
         JOIN persons person ON person.id=patient.person_id
         CROSS JOIN consent_types type
         WHERE person.user_id=$1 AND type.code=$2 AND type.is_active LIMIT 1`,
        [user.id, code],
      );
      const row = context.rows[0];
      if (!row)
        throw new NotFoundException(
          "El consentimiento no existe para este paciente.",
        );
      await client.query(
        `UPDATE patient_consents SET status='revoked',revoked_at=now()
         WHERE patient_id=$1 AND consent_type_id=$2 AND status='accepted'`,
        [row.patient_id, row.type_id],
      );
      const result = await client.query(
        `INSERT INTO patient_consents
         (patient_id,consent_type_id,granted_by_user_id,ip_address,user_agent)
         VALUES($1,$2,$3,$4,NULLIF($5,''))
         RETURNING id,status,accepted_at AS "acceptedAt"`,
        [
          row.patient_id,
          row.type_id,
          user.id,
          metadata.ipAddress ?? null,
          metadata.userAgent?.slice(0, 1000) ?? "",
        ],
      );
      return result.rows[0];
    });
  }

  revoke(user: RequestUser, code: string) {
    return this.database.transactionAsUser(user, async (client) => {
      const type = await client.query<{ is_required: boolean }>(
        `SELECT is_required FROM consent_types
         WHERE code=$1 AND is_active LIMIT 1`,
        [code],
      );
      if (type.rows[0]?.is_required) {
        throw new ForbiddenException(
          "Los términos y consentimientos obligatorios no se pueden retirar.",
        );
      }
      const result = await client.query(
        `UPDATE patient_consents consent
         SET status='revoked',revoked_at=now()
         FROM consent_types type,patients patient,persons person
         WHERE consent.consent_type_id=type.id
           AND patient.id=consent.patient_id AND person.id=patient.person_id
           AND person.user_id=$1 AND type.code=$2 AND consent.status='accepted'
         RETURNING consent.id,consent.status,consent.revoked_at AS "revokedAt"`,
        [user.id, code],
      );
      if (!result.rows[0]) {
        throw new NotFoundException(
          "No existe un consentimiento activo para revocar.",
        );
      }
      return result.rows[0];
    });
  }
}
