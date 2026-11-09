import type { MultipartFile } from "@fastify/multipart";
import { BadRequestException, Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import type { PoolClient } from "pg";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { FileStorageRepository } from "../../domain/ports/file-storage.repository";
@Injectable()
export class PostgresFileStorageRepository implements FileStorageRepository {
  constructor(
    private readonly database: DatabaseService,
    private readonly config: ConfigService,
  ) {}
  saveFileMetadata(
    user: RequestUser,
    contents: Buffer<ArrayBufferLike>,
    key: string,
    fileType: { extension: string; mimeType: string },
    file: MultipartFile,
    category: string,
    writeObjectCallback: (
      key: string,
      contents: Buffer,
      mimeType: string,
      originalName: string,
    ) => Promise<void>,
    objectInfoCallback: (
      key: string,
    ) => Promise<{ size: number; mimeType: string | undefined }>,
  ): Promise<{ size: number; mimeType: string | undefined }> {
    return this.database.transactionAsUser(user, async (client) => {
      await client.query("SELECT pg_advisory_xact_lock(hashtext($1))", [
        `file-upload:${user.id}`,
      ]);
      await this.assertDailyQuota(client, user, contents.length);
      await writeObjectCallback(
        key,
        contents,
        fileType.mimeType,
        file.filename,
      );
      const object = await objectInfoCallback(key);
      const entityId = key.split("/")[1].split(".")[0];
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,
               entity_type,entity_id,new_values)
             VALUES($1,$2,'files','file_uploaded','stored_file',$3,
               jsonb_build_object(
                 'key',$4::text,
                 'mimeType',$5::text,
                 'size',$6::bigint,
                 'category',$7::text
               ))`,
        [
          user.id,
          user.roleCode,
          entityId,
          key,
          fileType.mimeType,
          object.size,
          category,
        ],
      );
      return object;
    });
  }
  authorizeFileRead(
    suffix: string,
    keySuffix: string,
    user: RequestUser,
    key: string,
    hasPermissionCallback: (user: RequestUser, permission: string) => boolean,
  ): Promise<{ rowCount: number | null }> {
    return this.database.transactionAsUser(user, async (client) =>
      client.query(
        `SELECT 1 FROM audit_events
           WHERE actor_user_id=$3 AND action='file_uploaded'
             AND new_values->>'key'=$4
         UNION ALL
         SELECT 1 FROM clinical_documents document
           WHERE (document.file_url LIKE $1 OR document.file_url LIKE $2)
             AND $5::boolean AND app_can_read_patient(document.patient_id)
         UNION ALL
         SELECT 1 FROM professional_documents document
           JOIN professionals professional ON professional.id=document.professional_id
           WHERE (document.file_url LIKE $1 OR document.file_url LIKE $2)
             AND (professional.user_id=$3 OR $6::boolean)
         UNION ALL
         SELECT 1 FROM personnel_documents document
           LEFT JOIN personnel_applications application ON application.id=document.application_id
           LEFT JOIN professionals professional ON professional.id=document.professional_id
           WHERE (document.file_url LIKE $1 OR document.file_url LIKE $2)
             AND (application.applicant_user_id=$3 OR professional.user_id=$3 OR $6::boolean)
         UNION ALL
         SELECT 1 FROM partner_documents document
           WHERE (document.file_url LIKE $1 OR document.file_url LIKE $2)
             AND ($7::boolean OR EXISTS(
               SELECT 1 FROM partner_users member
               WHERE member.partner_id=document.partner_id AND member.user_id=$3 AND member.is_active
             ))
         UNION ALL
         SELECT 1 FROM system_settings setting
           WHERE setting.setting_key='payments.qr_image_url'
             AND setting.value #>> '{}' LIKE $1
         UNION ALL
         SELECT 1 FROM coin_packages package
           WHERE package.qr_image_url LIKE $1 OR package.qr_image_url LIKE $2
         UNION ALL
         SELECT 1 FROM payments payment
           JOIN payment_orders payment_order ON payment_order.id=payment.payment_order_id
           WHERE (payment.receipt_url LIKE $1 OR payment.receipt_url LIKE $2)
             AND (payment_order.user_id=$3 OR $8::boolean)
         UNION ALL
         SELECT 1 FROM service_evidence evidence
           JOIN home_service_requests request ON request.id=evidence.home_service_id
           LEFT JOIN professionals professional ON professional.id=request.assigned_professional_id
           WHERE (evidence.file_url LIKE $1 OR evidence.file_url LIKE $2)
             AND (request.requested_by_user_id=$3 OR professional.user_id=$3 OR $9::boolean)
         UNION ALL
         SELECT 1 FROM delivery_evidence evidence
           JOIN deliveries delivery ON delivery.id=evidence.delivery_id
           LEFT JOIN professionals professional ON professional.id=delivery.assigned_professional_id
           WHERE (evidence.file_url LIKE $1 OR evidence.file_url LIKE $2)
             AND (delivery.recipient_user_id=$3 OR professional.user_id=$3 OR $10::boolean)
         LIMIT 1`,
        [
          suffix,
          keySuffix,
          user.id,
          key,
          hasPermissionCallback(user, "clinical_records.read"),
          hasPermissionCallback(user, "human_resources.read") ||
            hasPermissionCallback(user, "human_resources.manage"),
          hasPermissionCallback(user, "partners.manage"),
          hasPermissionCallback(user, "payments.manage"),
          hasPermissionCallback(user, "home_services.manage"),
          hasPermissionCallback(user, "deliveries.manage"),
        ],
      ),
    );
  }
  logFileRead(
    user: RequestUser,
    entityId: string,
    key: string,
    result: { url: string; expiresAt: string },
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,
             entity_type,entity_id,new_values)
           VALUES($1,$2,'files','signed_file_access_created','stored_file',$3,
             jsonb_build_object('key',$4,'expiresAt',$5::text))`,
        [user.id, user.roleCode, entityId, key, result.expiresAt],
      );
    });
  }
  private async assertDailyQuota(
    client: PoolClient,
    user: RequestUser,
    incomingBytes: number,
  ) {
    const limitMb = this.config.get<number>("STORAGE_DAILY_UPLOAD_MB", 100);
    const result = await client.query<{ used: string }>(
      `SELECT COALESCE(sum((new_values->>'size')::bigint),0)::text AS used
         FROM audit_events
         WHERE actor_user_id=$1 AND action='file_uploaded'
           AND created_at>=now()-interval '24 hours'`,
      [user.id],
    );
    if (
      Number(result.rows[0]?.used ?? 0) + incomingBytes >
      limitMb * 1024 * 1024
    ) {
      throw new BadRequestException("Alcanzaste el límite diario de archivos.");
    }
  }
}
