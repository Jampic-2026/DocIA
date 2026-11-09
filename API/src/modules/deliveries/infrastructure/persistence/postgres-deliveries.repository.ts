import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { DeliveriesRepository } from "../../domain/ports/deliveries.repository";
const cols = `delivery.id,delivery.partner_request_id AS "partnerRequestId",delivery.assigned_professional_id AS "assignedProfessionalId",delivery.delivery_address_id AS "deliveryAddressId",delivery.recipient_user_id AS "recipientUserId",delivery.status::text,delivery.delivery_fee::float8 AS "deliveryFee",delivery.failure_reason AS "failureReason",delivery.retry_count AS "retryCount",delivery.created_at AS "createdAt",delivery.updated_at AS "updatedAt"`;
@Injectable()
export class PostgresDeliveriesRepository implements DeliveriesRepository {
  constructor(private readonly db: DatabaseService) {}
  list(user: RequestUser) {
    return this.db.transactionAsUser(
      user,
      async (c) =>
        (
          await c.query(
            `SELECT ${cols} FROM deliveries delivery ORDER BY delivery.created_at DESC LIMIT 100`,
          )
        ).rows,
    );
  }
  create(
    user: RequestUser,
    input: {
      partnerRequestId: string;
      deliveryAddressId: string;
      recipientUserId?: string;
      deliveryFee?: number;
    },
  ) {
    return this.db.transactionAsUser(user, async (c) => {
      const valid = await c.query(
        `SELECT request.requested_by_user_id,address.person_id FROM partner_requests request JOIN addresses address ON address.id=$2 WHERE request.id=$1 AND (request.requested_by_user_id=$3 OR app_has_permission('deliveries.manage'))`,
        [input.partnerRequestId, input.deliveryAddressId, user.id],
      );
      if (!valid.rowCount)
        throw new BadRequestException(
          "La solicitud o dirección de entrega no son válidas.",
        );
      const inserted = await c.query<{ id: string }>(
        `INSERT INTO deliveries(partner_request_id,delivery_address_id,recipient_user_id,delivery_fee)VALUES($1,$2,COALESCE($3,$4),$5)RETURNING id`,
        [
          input.partnerRequestId,
          input.deliveryAddressId,
          input.recipientUserId,
          user.id,
          input.deliveryFee ?? 0,
        ],
      );
      await c.query(
        `INSERT INTO delivery_status_history(delivery_id,new_status,changed_by_user_id,reason)VALUES($1,'available',$2,'Entrega creada')`,
        [inserted.rows[0].id, user.id],
      );
      return (
        await c.query(
          `SELECT ${cols} FROM deliveries delivery WHERE delivery.id=$1`,
          [inserted.rows[0].id],
        )
      ).rows[0];
    });
  }
  assign(user: RequestUser, id: string, professionalId: string) {
    return this.db.transactionAsUser(user, async (c) => {
      const result = await c.query(
        `UPDATE deliveries SET assigned_professional_id=$2,status='assigned',updated_at=now() WHERE id=$1 AND status IN('available','assigned') RETURNING id`,
        [id, professionalId],
      );
      if (!result.rowCount)
        throw new ConflictException(
          "La entrega no está disponible para asignación.",
        );
      await c.query(
        `INSERT INTO delivery_status_history(delivery_id,old_status,new_status,changed_by_user_id,reason)VALUES($1,'available','assigned',$2,'Repartidor asignado')`,
        [id, user.id],
      );
      return (
        await c.query(
          `SELECT ${cols} FROM deliveries delivery WHERE delivery.id=$1`,
          [id],
        )
      ).rows[0];
    });
  }
  updateStatus(user: RequestUser, id: string, status: string, reason?: string) {
    return this.db.transactionAsUser(user, async (c) => {
      const current = await c.query<{ status: string }>(
        `SELECT status::text FROM deliveries WHERE id=$1 FOR UPDATE`,
        [id],
      );
      if (!current.rows[0])
        throw new NotFoundException("Entrega no encontrada.");
      const allowed: Record<string, string[]> = {
        available: ["assigned", "cancelled"],
        assigned: ["accepted", "cancelled"],
        accepted: ["picked_up", "failed"],
        picked_up: ["on_route", "failed"],
        on_route: ["delivered", "failed"],
        failed: ["returned", "assigned"],
      };
      if (!(allowed[current.rows[0].status] ?? []).includes(status))
        throw new ConflictException(
          "La transición de la entrega no está permitida.",
        );
      await c.query(
        `UPDATE deliveries SET status=$2::delivery_status,accepted_at=CASE WHEN $2='accepted'THEN now()ELSE accepted_at END,picked_up_at=CASE WHEN $2='picked_up'THEN now()ELSE picked_up_at END,delivered_at=CASE WHEN $2='delivered'THEN now()ELSE delivered_at END,failed_at=CASE WHEN $2='failed'THEN now()ELSE failed_at END,failure_reason=CASE WHEN $2='failed'THEN $3 ELSE failure_reason END,retry_count=CASE WHEN $2='assigned'AND status='failed'THEN retry_count+1 ELSE retry_count END,updated_at=now()WHERE id=$1`,
        [id, status, reason?.trim() ?? null],
      );
      await c.query(
        `INSERT INTO delivery_status_history(delivery_id,old_status,new_status,changed_by_user_id,reason)VALUES($1,$2::delivery_status,$3::delivery_status,$4,$5)`,
        [id, current.rows[0].status, status, user.id, reason?.trim() ?? null],
      );
      return (
        await c.query(
          `SELECT ${cols} FROM deliveries delivery WHERE delivery.id=$1`,
          [id],
        )
      ).rows[0];
    });
  }
  history(user: RequestUser, id?: string) {
    return this.rows(
      user,
      `SELECT id,delivery_id AS "deliveryId",old_status::text AS "oldStatus",new_status::text AS "newStatus",changed_by_user_id AS "changedByUserId",reason,created_at AS "createdAt" FROM delivery_status_history WHERE($1::uuid IS NULL OR delivery_id=$1)ORDER BY created_at DESC`,
      id,
    );
  }
  evidence(user: RequestUser, id?: string) {
    return this.rows(
      user,
      `SELECT id,delivery_id AS "deliveryId",uploaded_by_user_id AS "uploadedByUserId",evidence_type AS "evidenceType",file_url AS "fileUrl",recipient_document_verified AS "recipientDocumentVerified",notes,created_at AS "createdAt" FROM delivery_evidence WHERE($1::uuid IS NULL OR delivery_id=$1)ORDER BY created_at DESC`,
      id,
    );
  }
  addEvidence(
    user: RequestUser,
    id: string,
    input: {
      evidenceType: string;
      fileUrl: string;
      recipientDocumentVerified?: boolean;
      notes?: string;
    },
  ) {
    return this.db.transactionAsUser(user, async (c) => {
      const result = await c.query(
        `INSERT INTO delivery_evidence(delivery_id,uploaded_by_user_id,evidence_type,file_url,recipient_document_verified,notes)SELECT $1,$2,$3,$4,$5,$6 WHERE EXISTS(SELECT 1 FROM deliveries WHERE id=$1)RETURNING id,created_at AS "createdAt"`,
        [
          id,
          user.id,
          input.evidenceType.trim(),
          input.fileUrl,
          input.recipientDocumentVerified ?? false,
          input.notes?.trim() ?? null,
        ],
      );
      if (!result.rows[0])
        throw new NotFoundException("Entrega no encontrada.");
      return result.rows[0];
    });
  }
  private rows(user: RequestUser, sql: string, id?: string) {
    return this.db.transactionAsUser(
      user,
      async (c) => (await c.query(sql, [id ?? null])).rows,
    );
  }
}
