import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { HomeService } from "../../domain/home-service";
import { HomeServicesRepository } from "../../domain/ports/home-services.repository";

const columns = `request.id,request.patient_id AS "patientId",request.service_id AS "serviceId",
  service.name AS "serviceName",request.address_id AS "addressId",
  request.assigned_professional_id AS "assignedProfessionalId",
  request.assigned_partner_id AS "assignedPartnerId",request.status::text,
  request.requested_for AS "requestedFor",request.clinical_notes AS "clinicalNotes",
  request.created_at AS "createdAt",request.updated_at AS "updatedAt"`;

@Injectable()
export class PostgresHomeServicesRepository implements HomeServicesRepository {
  constructor(private readonly database: DatabaseService) {}

  list(user: RequestUser) {
    return this.database.transactionAsUser(
      user,
      async (client) =>
        (
          await client.query<HomeService>(
            `SELECT ${columns} FROM home_service_requests request JOIN service_catalog service ON service.id=request.service_id ORDER BY request.created_at DESC LIMIT 100`,
          )
        ).rows,
    );
  }

  create(
    user: RequestUser,
    input: { serviceId: string; addressId: string; requestedFor?: string },
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const patient = await client.query<{ id: string }>(
        `SELECT patient.id FROM patients patient JOIN persons person ON person.id=patient.person_id WHERE person.user_id=$1 LIMIT 1`,
        [user.id],
      );
      if (!patient.rows[0])
        throw new BadRequestException(
          "La cuenta no tiene un perfil de paciente.",
        );
      const valid = await client.query(
        `SELECT 1 FROM service_catalog service JOIN addresses address ON address.id=$2 JOIN persons person ON person.id=address.person_id WHERE service.id=$1 AND service.is_active AND service.category='home_service' AND person.user_id=$3`,
        [input.serviceId, input.addressId, user.id],
      );
      if (!valid.rowCount)
        throw new BadRequestException(
          "El servicio o la dirección no son válidos.",
        );
      const inserted = await client.query<{ id: string }>(
        `INSERT INTO home_service_requests(patient_id,requested_by_user_id,service_id,address_id,requested_for) VALUES($1,$2,$3,$4,$5) RETURNING id`,
        [
          patient.rows[0].id,
          user.id,
          input.serviceId,
          input.addressId,
          input.requestedFor ?? null,
        ],
      );
      await client.query(
        `INSERT INTO service_status_history(home_service_id,new_status,changed_by_user_id,reason) VALUES($1,'pending',$2,'Solicitud creada')`,
        [inserted.rows[0].id, user.id],
      );
      return (
        await client.query<HomeService>(
          `SELECT ${columns} FROM home_service_requests request JOIN service_catalog service ON service.id=request.service_id WHERE request.id=$1`,
          [inserted.rows[0].id],
        )
      ).rows[0];
    });
  }

  assign(
    user: RequestUser,
    id: string,
    input: { professionalId?: string; partnerId?: string },
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<HomeService>(
        `WITH previous AS (SELECT status FROM home_service_requests WHERE id=$1 FOR UPDATE), updated AS (UPDATE home_service_requests SET assigned_professional_id=$2,assigned_partner_id=$3,status='assigned',updated_at=now() WHERE id=$1 AND status IN('pending','assigned') RETURNING *) INSERT INTO service_status_history(home_service_id,old_status,new_status,changed_by_user_id,reason) SELECT $1,previous.status,'assigned',$4,'Asignación registrada' FROM previous,updated RETURNING $1::uuid AS id`,
        [id, input.professionalId ?? null, input.partnerId ?? null, user.id],
      );
      if (!result.rowCount)
        throw new ConflictException(
          "La solicitud no puede ser asignada en su estado actual.",
        );
      return (
        await client.query<HomeService>(
          `SELECT ${columns} FROM home_service_requests request JOIN service_catalog service ON service.id=request.service_id WHERE request.id=$1`,
          [id],
        )
      ).rows[0];
    });
  }

  updateStatus(
    user: RequestUser,
    id: string,
    status: string,
    reason?: string,
    clinicalNotes?: string,
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const current = await client.query<{ status: string }>(
        `SELECT status::text FROM home_service_requests WHERE id=$1 FOR UPDATE`,
        [id],
      );
      if (!current.rows[0])
        throw new NotFoundException("Solicitud domiciliaria no encontrada.");
      const allowed: Record<string, string[]> = {
        pending: ["cancelled", "assigned"],
        assigned: ["accepted", "rejected", "cancelled"],
        accepted: ["in_progress", "cancelled"],
        in_progress: ["completed", "failed"],
      };
      if (!(allowed[current.rows[0].status] ?? []).includes(status))
        throw new ConflictException(
          "La transición de estado no está permitida.",
        );
      await client.query(
        `UPDATE home_service_requests SET status=$2::generic_request_status,clinical_notes=COALESCE($4,clinical_notes),accepted_at=CASE WHEN $2='accepted' THEN now() ELSE accepted_at END,rejected_at=CASE WHEN $2='rejected' THEN now() ELSE rejected_at END,rejection_reason=CASE WHEN $2='rejected' THEN $3 ELSE rejection_reason END,on_route_at=CASE WHEN $2='in_progress' THEN now() ELSE on_route_at END,completed_at=CASE WHEN $2='completed' THEN now() ELSE completed_at END,updated_at=now() WHERE id=$1`,
        [id, status, reason?.trim() ?? null, clinicalNotes?.trim() ?? null],
      );
      await client.query(
        `INSERT INTO service_status_history(home_service_id,old_status,new_status,changed_by_user_id,reason) VALUES($1,$2::generic_request_status,$3::generic_request_status,$4,$5)`,
        [id, current.rows[0].status, status, user.id, reason?.trim() ?? null],
      );
      return (
        await client.query<HomeService>(
          `SELECT ${columns} FROM home_service_requests request JOIN service_catalog service ON service.id=request.service_id WHERE request.id=$1`,
          [id],
        )
      ).rows[0];
    });
  }

  history(user: RequestUser, serviceId?: string) {
    return this.rows(
      user,
      `SELECT id,home_service_id AS "homeServiceId",old_status::text AS "oldStatus",new_status::text AS "newStatus",changed_by_user_id AS "changedByUserId",reason,created_at AS "createdAt" FROM service_status_history WHERE ($1::uuid IS NULL OR home_service_id=$1) ORDER BY created_at DESC`,
      serviceId,
    );
  }
  locations(user: RequestUser, serviceId?: string) {
    return this.rows(
      user,
      `SELECT id,professional_id AS "professionalId",home_service_id AS "homeServiceId",latitude::float8,longitude::float8,accuracy_m::float8 AS "accuracyM",recorded_at AS "recordedAt" FROM realtime_locations WHERE home_service_id IS NOT NULL AND ($1::uuid IS NULL OR home_service_id=$1) ORDER BY recorded_at DESC LIMIT 500`,
      serviceId,
    );
  }
  evidence(user: RequestUser, serviceId?: string) {
    return this.rows(
      user,
      `SELECT id,home_service_id AS "homeServiceId",uploaded_by_user_id AS "uploadedByUserId",evidence_type AS "evidenceType",file_url AS "fileUrl",notes,created_at AS "createdAt" FROM service_evidence WHERE ($1::uuid IS NULL OR home_service_id=$1) ORDER BY created_at DESC`,
      serviceId,
    );
  }
  ratings(user: RequestUser, serviceId?: string) {
    return this.rows(
      user,
      `SELECT id,home_service_id AS "homeServiceId",patient_id AS "patientId",professional_id AS "professionalId",rating,comment,created_at AS "createdAt" FROM home_service_ratings WHERE ($1::uuid IS NULL OR home_service_id=$1) ORDER BY created_at DESC`,
      serviceId,
    );
  }

  addLocation(
    user: RequestUser,
    id: string,
    input: { latitude: number; longitude: number; accuracyM?: number },
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const professional = await client.query<{ id: string }>(
        `SELECT id FROM professionals WHERE user_id=$1`,
        [user.id],
      );
      if (!professional.rows[0])
        throw new BadRequestException(
          "La cuenta no tiene un perfil profesional.",
        );
      const result = await client.query(
        `INSERT INTO realtime_locations(professional_id,home_service_id,latitude,longitude,accuracy_m) SELECT $1,$2,$3,$4,$5 WHERE EXISTS(SELECT 1 FROM home_service_requests WHERE id=$2 AND assigned_professional_id=$1 AND status IN('accepted','in_progress')) RETURNING id,recorded_at AS "recordedAt"`,
        [
          professional.rows[0].id,
          id,
          input.latitude,
          input.longitude,
          input.accuracyM ?? null,
        ],
      );
      if (!result.rows[0])
        throw new ConflictException(
          "No puedes registrar ubicación para esta solicitud.",
        );
      return result.rows[0];
    });
  }
  addEvidence(
    user: RequestUser,
    id: string,
    input: { evidenceType: string; fileUrl: string; notes?: string },
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `INSERT INTO service_evidence(home_service_id,uploaded_by_user_id,evidence_type,file_url,notes) SELECT $1,$2,$3,$4,$5 WHERE EXISTS(SELECT 1 FROM home_service_requests WHERE id=$1) RETURNING id,home_service_id AS "homeServiceId",evidence_type AS "evidenceType",file_url AS "fileUrl",notes,created_at AS "createdAt"`,
        [
          id,
          user.id,
          input.evidenceType.trim(),
          input.fileUrl,
          input.notes?.trim() ?? null,
        ],
      );
      if (!result.rows[0])
        throw new NotFoundException("Solicitud domiciliaria no encontrada.");
      return result.rows[0];
    });
  }
  rate(user: RequestUser, id: string, rating: number, comment?: string) {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `INSERT INTO home_service_ratings(home_service_id,patient_id,professional_id,rating,comment) SELECT request.id,request.patient_id,request.assigned_professional_id,$2,$3 FROM home_service_requests request WHERE request.id=$1 AND request.requested_by_user_id=$4 AND request.status='completed' ON CONFLICT(home_service_id) DO NOTHING RETURNING id,rating,comment,created_at AS "createdAt"`,
        [id, rating, comment?.trim() ?? null, user.id],
      );
      if (!result.rows[0])
        throw new ConflictException(
          "El servicio no puede calificarse o ya fue calificado.",
        );
      return result.rows[0];
    });
  }
  private rows(user: RequestUser, sql: string, id?: string) {
    return this.database.transactionAsUser(
      user,
      async (client) => (await client.query(sql, [id ?? null])).rows,
    );
  }
}
