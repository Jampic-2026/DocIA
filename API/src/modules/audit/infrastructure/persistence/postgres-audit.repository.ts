import { Injectable } from "@nestjs/common";
import { QueryResultRow } from "pg";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { AuditEvent } from "../../domain/audit-event";
import { AuditRepository } from "../../domain/ports/audit.repository";

type AuditEventRow = QueryResultRow & {
  id: string;
  module: string;
  action: string;
  entity_type: string | null;
  actor_name: string | null;
  actor_role: string | null;
  reason: string | null;
  created_at: Date;
};

@Injectable()
export class PostgresAuditRepository implements AuditRepository {
  constructor(private readonly database: DatabaseService) {}

  listEvents(user: RequestUser): Promise<AuditEvent[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<AuditEventRow>(
        `
        SELECT event.id, event.module, event.action, event.entity_type,
          NULLIF(
            concat_ws(
              ' ',
              actor.first_name,
              actor.last_name,
              actor.second_last_name
            ),
            ''
          ) AS actor_name,
          event.actor_role, event.reason, event.created_at
        FROM audit_events event
        LEFT JOIN persons actor ON actor.user_id = event.actor_user_id
        ORDER BY event.created_at DESC
        LIMIT 100
        `,
      );
      return result.rows.map((row) => ({
        id: row.id,
        module: row.module,
        action: row.action,
        entityType: row.entity_type,
        actorName: row.actor_name,
        actorRole: row.actor_role,
        reason: row.reason,
        createdAt: row.created_at,
      }));
    });
  }
  listClinicalAccess(user: RequestUser): Promise<unknown[]> {
    return this.database.transactionAsUser(
      user,
      async (client) =>
        (
          await client.query(
          `SELECT id,actor_user_id AS "actorUserId",actor_role AS "actorRole",patient_id AS "patientId",section,purpose,access_granted AS "accessGranted",denial_reason AS "denialReason",ip_address AS "ipAddress",user_agent AS "userAgent",created_at AS "createdAt" FROM clinical_access_logs ORDER BY created_at DESC LIMIT 200`,
          )
        ).rows,
    );
  }
  listFinancialEvents(user: RequestUser): Promise<unknown[]> {
    return this.database.transactionAsUser(
      user,
      async (client) =>
        (
          await client.query(
            `SELECT event.id,event.actor_user_id AS "actorUserId",
               event.actor_role AS "actorRole",event.module,event.action,
               event.entity_type AS "entityType",event.entity_id AS "entityId",
               event.old_values AS "oldValues",event.new_values AS "newValues",
               event.reason,event.created_at AS "createdAt"
             FROM audit_events event
             WHERE event.module IN('payments','coins','catalog','partners')
               AND(
                 event.entity_type IN(
                   'payment','payment_order','payment_incident','refund',
                   'coin_purchase','coin_lot','coin_transaction',
                   'price_list','partner_subscription','partner_subscription_plan'
                 )
                 OR event.action LIKE 'coin_%'
                 OR event.action LIKE 'payment_%'
               )
             ORDER BY event.created_at DESC LIMIT 500`,
          )
        ).rows,
    );
  }
}
