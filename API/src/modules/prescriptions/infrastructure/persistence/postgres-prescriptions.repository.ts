import {
  BadRequestException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from "@nestjs/common";
import { QueryResultRow } from "pg";
import { ConfigService } from "@nestjs/config";
import { createHmac, createHash } from "node:crypto";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { Prescription } from "../../domain/prescription";
import { PrescriptionsRepository } from "../../domain/ports/prescriptions.repository";

type PrescriptionRow = QueryResultRow & {
  id: string;
  patient_id: string;
  patient_name: string;
  professional_name: string;
  status: Prescription["status"];
  issued_at: Date | null;
  expires_at: Date | null;
  created_at: Date;
  items: Prescription["items"];
};

@Injectable()
export class PostgresPrescriptionsRepository implements PrescriptionsRepository {
  constructor(
    private readonly database: DatabaseService,
    private readonly config: ConfigService,
  ) {}

  listForUser(user: RequestUser): Promise<Prescription[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<PrescriptionRow>(
        `
        SELECT prescription.id,prescription.patient_id,
          concat_ws(' ', patient_person.first_name, patient_person.last_name,
            patient_person.second_last_name) AS patient_name,
          app_prescription_author_identity(prescription.id) AS professional_name,
          prescription.status, prescription.issued_at, prescription.expires_at,
          prescription.created_at,
          COALESCE(jsonb_agg(jsonb_build_object(
            'id', item.id,
            'medicationName', item.medication_name,
            'dose', item.dose,
            'frequency', item.frequency,
            'duration', item.duration,
            'instructions', item.instructions
          ) ORDER BY item.created_at) FILTER (WHERE item.id IS NOT NULL), '[]'::jsonb) AS items
        FROM prescriptions prescription
        JOIN patients patient ON patient.id = prescription.patient_id
        JOIN persons patient_person ON patient_person.id = patient.person_id
        LEFT JOIN professionals professional ON professional.id = prescription.professional_id
        LEFT JOIN prescription_items item ON item.prescription_id = prescription.id
        WHERE (patient_person.user_id = $1
           OR professional.user_id = $1
           OR $2::boolean)
          AND (prescription.status<>'draft' OR professional.user_id=$1 OR $2::boolean)
        GROUP BY prescription.id, patient_person.id
        ORDER BY COALESCE(prescription.issued_at, prescription.created_at) DESC
        `,
        [
          user.id,
          user.roles.some((role) =>
            ["admin", "clinical_supervisor"].includes(role),
          ),
        ],
      );
      for (const row of result.rows) {
        await client.query(
          `INSERT INTO audit_events(actor_user_id,patient_id,module,action,entity_type,entity_id)
          VALUES($1,$2,'prescriptions','prescription_read','prescription',$3)`,
          [user.id, row.patient_id, row.id],
        );
      }
      return result.rows.map((row) => ({
        id: row.id,
        patientId: row.patient_id,
        patientName: row.patient_name,
        professionalName: row.professional_name,
        status: row.status,
        issuedAt: row.issued_at,
        expiresAt: row.expires_at,
        createdAt: row.created_at,
        items: row.items,
      }));
    });
  }

  createDraft(
    user: RequestUser,
    input: {
      patientId: string;
      appointmentId: string;
      items: Array<{
        medicationName: string;
        dose?: string;
        frequency?: string;
        duration?: string;
        instructions?: string;
      }>;
    },
  ): Promise<Prescription> {
    return this.database.transactionAsUser(user, async (client) => {
      const context = await client.query<{
        professional_id: string;
        patient_name: string;
        professional_name: string;
        status: string;
        clinical_note_id: string | null;
      }>(
        `SELECT appointment.professional_id,
          concat_ws(' ',patient_person.first_name,patient_person.last_name,
            patient_person.second_last_name) AS patient_name,
          concat_ws(' ',professional_person.first_name,
            professional_person.last_name,
            professional_person.second_last_name) AS professional_name,
          appointment.status,
          (SELECT note.id FROM clinical_notes note
           WHERE note.appointment_id=appointment.id
             AND note.professional_id=appointment.professional_id
           ORDER BY note.created_at DESC LIMIT 1) AS clinical_note_id
         FROM appointments appointment
         JOIN patients patient ON patient.id=appointment.patient_id
         JOIN persons patient_person ON patient_person.id=patient.person_id
         JOIN professionals professional
           ON professional.id=appointment.professional_id
         JOIN persons professional_person
           ON professional_person.id=professional.person_id
         WHERE appointment.id=$1 AND appointment.patient_id=$2
           AND professional.user_id=$3
         LIMIT 1`,
        [input.appointmentId, input.patientId, user.id],
      );
      const care = context.rows[0];
      if (!care) {
        throw new NotFoundException(
          "La cita no existe o no corresponde al profesional y paciente.",
        );
      }
      if (!["in_progress", "completed"].includes(care.status)) {
        throw new BadRequestException(
          "La receta requiere una atención en curso o completada.",
        );
      }
      if (!care.clinical_note_id) {
        throw new BadRequestException(
          "Registra la nota clínica antes de crear la receta.",
        );
      }

      const created = await client.query<{ id: string; created_at: Date }>(
        `INSERT INTO prescriptions(
          patient_id,professional_id,appointment_id,clinical_note_id,status
         ) VALUES($1,$2,$3,$4,'draft')
         RETURNING id,created_at`,
        [
          input.patientId,
          care.professional_id,
          input.appointmentId,
          care.clinical_note_id,
        ],
      );
      const prescription = created.rows[0];
      const items: Prescription["items"] = [];
      for (const item of input.items) {
        const inserted = await client.query<{
          id: string;
          medication_name: string;
          dose: string | null;
          frequency: string | null;
          duration: string | null;
          instructions: string | null;
        }>(
          `INSERT INTO prescription_items(
            prescription_id,medication_name,dose,frequency,duration,instructions
           ) VALUES($1,$2,NULLIF($3,''),NULLIF($4,''),NULLIF($5,''),NULLIF($6,''))
           RETURNING id,medication_name,dose,frequency,duration,instructions`,
          [
            prescription.id,
            item.medicationName.trim(),
            item.dose?.trim() ?? "",
            item.frequency?.trim() ?? "",
            item.duration?.trim() ?? "",
            item.instructions?.trim() ?? "",
          ],
        );
        const row = inserted.rows[0];
        items.push({
          id: row.id,
          medicationName: row.medication_name,
          dose: row.dose,
          frequency: row.frequency,
          duration: row.duration,
          instructions: row.instructions,
        });
      }
      await client.query(
        `INSERT INTO audit_events(
          actor_user_id,actor_role,patient_id,module,action,entity_type,
          entity_id,new_values
         ) VALUES($1,$2,$3,'prescriptions','prescription_draft_created',
          'prescription',$4,jsonb_build_object('itemCount',$5::int))`,
        [
          user.id,
          user.roleCode,
          input.patientId,
          prescription.id,
          items.length,
        ],
      );
      return {
        id: prescription.id,
        patientId: input.patientId,
        patientName: care.patient_name,
        professionalName: care.professional_name,
        status: "draft",
        issuedAt: null,
        expiresAt: null,
        createdAt: prescription.created_at,
        items,
      };
    });
  }

  async safetyReview(user: RequestUser, id: string) {
    return this.database.transactionAsUser(user, async (client) => {
      const allowed = await client.query(
        `SELECT prescription.patient_id FROM prescriptions prescription
        JOIN professionals professional ON professional.id=prescription.professional_id
        WHERE prescription.id=$1 AND professional.user_id=$2`,
        [id, user.id],
      );
      if (!allowed.rows[0])
        throw new NotFoundException(
          "No se encontró la receta del profesional.",
        );
      const result = await client.query<{
        substance: string;
        reaction: string | null;
      }>(
        `SELECT substance,reaction FROM allergies WHERE patient_id=$1 AND is_active ORDER BY id`,
        [allowed.rows[0].patient_id],
      );
      return {
        allergies: result.rows,
        fingerprint: createHash("sha256")
          .update(JSON.stringify(result.rows))
          .digest("hex"),
      };
    });
  }

  issue(
    user: RequestUser,
    id: string,
    expiresAt: Date,
    review?: { fingerprint?: string; reason?: string },
  ): Promise<Prescription> {
    if (!Number.isFinite(expiresAt.getTime()) || expiresAt <= new Date()) {
      throw new BadRequestException("La fecha de vencimiento debe ser futura.");
    }
    if (expiresAt.getTime() > Date.now() + 366 * 24 * 60 * 60 * 1000) {
      throw new BadRequestException(
        "La receta no puede vencer después de un año.",
      );
    }
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<
        PrescriptionRow & {
          appointment_id: string | null;
          clinical_note_id: string | null;
          professional_id: string;
        }
      >(
        `SELECT prescription.id,prescription.patient_id,
          prescription.professional_id,prescription.appointment_id,
          prescription.clinical_note_id,prescription.status,
          prescription.issued_at,prescription.expires_at,prescription.created_at,
          concat_ws(' ',patient_person.first_name,patient_person.last_name,
            patient_person.second_last_name) AS patient_name,
          concat_ws(' ',professional_person.first_name,professional_person.last_name,
            professional_person.second_last_name) AS professional_name,
          COALESCE(jsonb_agg(jsonb_build_object(
            'id',item.id,'medicationName',item.medication_name,'dose',item.dose,
            'frequency',item.frequency,'duration',item.duration,
            'instructions',item.instructions
          ) ORDER BY item.created_at) FILTER(WHERE item.id IS NOT NULL),'[]'::jsonb) AS items
         FROM prescriptions prescription
         JOIN patients patient ON patient.id=prescription.patient_id
         JOIN persons patient_person ON patient_person.id=patient.person_id
         JOIN professionals professional ON professional.id=prescription.professional_id
         JOIN persons professional_person ON professional_person.id=professional.person_id
         LEFT JOIN prescription_items item ON item.prescription_id=prescription.id
         WHERE prescription.id=$1 AND professional.user_id=$2
         GROUP BY prescription.id,patient_person.id,professional_person.id`,
        [id, user.id],
      );
      const row = result.rows[0];
      if (!row) throw new NotFoundException("No se encontró la receta.");
      if (row.status !== "draft") {
        throw new BadRequestException(
          "Solo se puede emitir una receta en borrador.",
        );
      }
      if (!row.items.length) {
        throw new BadRequestException(
          "La receta debe contener al menos un medicamento.",
        );
      }
      const allergies = await client.query(
        `SELECT substance,reaction FROM allergies WHERE patient_id=$1 AND is_active ORDER BY id`,
        [row.patient_id],
      );
      const fingerprint = createHash("sha256")
        .update(JSON.stringify(allergies.rows))
        .digest("hex");
      if (
        allergies.rowCount &&
        (review?.fingerprint !== fingerprint ||
          (review?.reason?.trim().length ?? 0) < 8)
      ) {
        throw new BadRequestException(
          "Revisa las alergias actuales y registra la justificación profesional antes de emitir.",
        );
      }
      if (allergies.rowCount)
        await client.query(
          `INSERT INTO audit_events(actor_user_id,patient_id,module,action,entity_type,entity_id,new_values)
        VALUES($1,$2,'prescriptions','allergy_warning_acknowledged','prescription',$3,$4::jsonb)`,
          [
            user.id,
            row.patient_id,
            id,
            JSON.stringify({ fingerprint, reason: review!.reason!.trim() }),
          ],
        );
      const issuedAt = new Date();
      const payload = JSON.stringify({
        id: row.id,
        patientId: row.patient_id,
        professionalId: row.professional_id,
        appointmentId: row.appointment_id,
        clinicalNoteId: row.clinical_note_id,
        issuedAt: issuedAt.toISOString(),
        expiresAt: expiresAt.toISOString(),
        items: row.items,
      });
      const signingSecret = this.config.get<string>(
        "PRESCRIPTION_SIGNING_SECRET",
      );
      if (!signingSecret) {
        throw new ServiceUnavailableException(
          "La firma de recetas todavía no está configurada en la API.",
        );
      }
      const signature = createHmac("sha256", signingSecret)
        .update(payload)
        .digest("hex");
      const updated = await client.query(
        `UPDATE prescriptions SET status='issued',issued_at=$2,expires_at=$3,
          digital_signature_hash=$4,updated_at=now()
          WHERE id=$1 AND status='draft' RETURNING id`,
        [id, issuedAt, expiresAt, signature],
      );
      if (!updated.rowCount) {
        throw new BadRequestException(
          "La receta ya no se encuentra en borrador.",
        );
      }
      await client.query(
        `INSERT INTO audit_events(
          actor_user_id,actor_role,patient_id,module,action,entity_type,
          entity_id,new_values
         ) VALUES($1,$2,$3,'prescriptions','prescription_issued',
          'prescription',$4,jsonb_build_object('expiresAt',$5::text,
          'signatureAlgorithm','HMAC-SHA256'))`,
        [user.id, user.roleCode, row.patient_id, id, expiresAt.toISOString()],
      );
      return {
        id: row.id,
        patientId: row.patient_id,
        patientName: row.patient_name,
        professionalName: row.professional_name,
        status: "issued",
        issuedAt,
        expiresAt,
        createdAt: row.created_at,
        items: row.items,
      };
    });
  }
}
