import {
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { MeetProvider } from "../../../integrations/domain/ports/meet-provider";
import { TelemedicineRepository } from "../../domain/ports/telemedicine.repository";
@Injectable()
export class PostgresTelemedicineRepository implements TelemedicineRepository {
  async claimRoomJobs() {
    return this.database.transactionWithSettings(
      { "app.roles": '["admin"]' },
      async (client) => {
        const result = await client.query<{
          appointmentId: string;
          requestedBy: string;
        }>(
          `WITH jobs AS (SELECT appointment_id FROM telemedicine_room_jobs
          WHERE processed_at IS NULL AND available_at<=now()
          ORDER BY available_at LIMIT 10 FOR UPDATE SKIP LOCKED)
         UPDATE telemedicine_room_jobs job SET available_at=now()+interval '2 minutes',attempts=attempts+1
         FROM jobs WHERE job.appointment_id=jobs.appointment_id
         RETURNING job.appointment_id AS "appointmentId",job.requested_by_user_id AS "requestedBy"`,
        );
        return result.rows;
      },
    );
  }
  async completeRoomJob(appointmentId: string) {
    await this.database.transactionWithSettings(
      { "app.roles": '["admin"]' },
      async (client) => {
        await client.query(
          "UPDATE telemedicine_room_jobs SET processed_at=now() WHERE appointment_id=$1",
          [appointmentId],
        );
      },
    );
  }
  async failRoomJob(appointmentId:string) {
    await this.database.transactionWithSettings({'app.roles':'["admin"]','app.role_code':'system'},async client=>{
      await client.query('SELECT app_report_room_job_failure($1)',[appointmentId]);
    });
  }
  async closeRoom(roomId: string, user: RequestUser, meet: MeetProvider) {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<{
        status: string;
        external_meeting_id: string;
        duration_seconds: number;
      }>(
        `SELECT room.status,room.external_meeting_id,room.duration_seconds
         FROM telemedicine_rooms room JOIN appointments appointment ON appointment.id=room.appointment_id
         JOIN professionals professional ON professional.id=appointment.professional_id
         WHERE room.id=$1 AND (professional.user_id=$2 OR app_has_role('admin') OR app_has_role('operator'))
         FOR UPDATE OF room`,
        [roomId, user.id],
      );
      const row = result.rows[0];
      if (!row)
        throw new NotFoundException("No puedes finalizar esta teleconsulta.");
      if (row.status === "completed")
        return { closed: true, durationSeconds: row.duration_seconds };
      if (row.status !== "active")
        throw new ConflictException("La videollamada todavía no fue iniciada.");
      if (!user.roles.some((role) => ["admin", "operator"].includes(role))) {
        const present = await client.query(
          "SELECT 1 FROM telemedicine_participants WHERE room_id=$1 AND user_id=$2 AND joined_at IS NOT NULL AND left_at IS NULL",
          [roomId, user.id],
        );
        if (!present.rowCount)
          throw new ConflictException(
            "Ingresa a la sesión antes de finalizarla.",
          );
      }
      await meet.endActiveConference(row.external_meeting_id);
      const updated = await client.query<{ duration_seconds: number }>(
        `UPDATE telemedicine_rooms SET status='completed',ended_at=now(),
         duration_seconds=GREATEST(0,EXTRACT(EPOCH FROM now()-COALESCE(started_at,now()))::int)
         WHERE id=$1 RETURNING duration_seconds`,
        [roomId],
      );
      await client.query(
        "UPDATE telemedicine_participants SET left_at=COALESCE(left_at,now()) WHERE room_id=$1 AND joined_at IS NOT NULL",
        [roomId],
      );
      await client.query(
        `INSERT INTO telemedicine_events(room_id,user_id,event_type) VALUES($1,$2,'conference_ended')`,
        [roomId, user.id],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,module,action,entity_type,entity_id)
        VALUES($1,'telemedicine','conference_ended','telemedicine_room',$2)`,
        [user.id, roomId],
      );
      await client.query(
        `UPDATE appointments a SET status=CASE WHEN EXISTS(SELECT 1 FROM clinical_notes n WHERE n.appointment_id=a.id AND n.closed_at IS NOT NULL)
        THEN 'completed'::appointment_status ELSE a.status END,updated_at=now() WHERE a.id=(SELECT appointment_id FROM telemedicine_rooms WHERE id=$1)`,
        [roomId],
      );
      return {
        closed: true,
        durationSeconds: updated.rows[0].duration_seconds,
      };
    });
  }
  constructor(
    private readonly database: DatabaseService,
    private readonly config: ConfigService,
  ) {}
  listRooms(user: RequestUser): Promise<{ items: any[] }> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `SELECT room.id,room.appointment_id AS "appointmentId",
          room.meeting_url AS "meetingUrl",room.status,
          appointment.start_at AS "startAt",appointment.end_at AS "endAt",
          app_telemedicine_professional_identity(room.id) AS "professionalName",
          specialty.name AS specialty
         FROM telemedicine_rooms room
         JOIN appointments appointment ON appointment.id=room.appointment_id
         JOIN patients patient ON patient.id=appointment.patient_id
         JOIN persons patient_person ON patient_person.id=patient.person_id
         LEFT JOIN professionals professional ON professional.id=appointment.professional_id
         LEFT JOIN professional_specialties ps
           ON ps.professional_id=appointment.professional_id AND ps.is_primary
         LEFT JOIN specialties specialty ON specialty.id=ps.specialty_id
         WHERE patient_person.user_id=$1 OR professional.user_id=$1
           OR app_has_role('admin') OR app_has_role('operator')
         ORDER BY appointment.start_at DESC`,
        [user.id],
      );
      return { items: result.rows };
    });
  }
  createRoom(
    appointmentId: string,
    user: RequestUser,
    meetCallback: MeetProvider,
  ): Promise<any> {
    return this.database.transactionAsUser(user, async (client) => {
      const appointment = await client.query<{
        modality: string;
        status: string;
      }>(
        `SELECT appointment.modality,appointment.status
         FROM appointments appointment
         JOIN professionals professional ON professional.id=appointment.professional_id
         WHERE appointment.id=$1 AND professional.verification_status='approved'
           AND (professional.user_id=$2 OR app_can_patient_action(appointment.patient_id,'appointments.manage') OR app_has_role('admin')
             OR app_has_role('operator'))
         FOR UPDATE`,
        [appointmentId, user.id],
      );
      const row = appointment.rows[0];
      if (!row) {
        throw new NotFoundException(
          "La cita no existe o no puedes administrar su sala.",
        );
      }
      if (row.modality !== "telemedicine") {
        throw new ConflictException("La cita no es de telemedicina.");
      }
      if (["cancelled", "completed", "no_show"].includes(row.status)) {
        throw new ConflictException("La cita ya no admite una sala nueva.");
      }
      const existing = await client.query(
        `SELECT id,appointment_id AS "appointmentId",meeting_url AS "meetingUrl",status
         FROM telemedicine_rooms WHERE appointment_id=$1`,
        [appointmentId],
      );
      if (existing.rows[0]) return existing.rows[0];

      const space = await meetCallback.createSpace();
      const created = await client.query(
        `INSERT INTO telemedicine_rooms
         (appointment_id,provider,meeting_url,external_meeting_id)
         VALUES($1,'google_meet',$2,$3)
         RETURNING id,appointment_id AS "appointmentId",meeting_url AS "meetingUrl",status`,
        [appointmentId, space.meetingUri, space.name],
      );
      // Participants and notifications are installed transactionally by the room trigger.
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id)
        VALUES($1,$2,'telemedicine','room_created','telemedicine_room',$3)`,
        [user.id, user.roleCode, created.rows[0].id],
      );
      return created.rows[0];
    });
  }
  registerJoin(
    roomId: string,
    user: RequestUser,
  ): Promise<{ registered: boolean }> {
    return this.database.transactionAsUser(user, async (client) => {
      const available = await client.query<{
        status: string;
        professional_user_id: string;
      }>(
        `SELECT room.status,professional.user_id AS professional_user_id FROM telemedicine_rooms room
        JOIN appointments a ON a.id=room.appointment_id JOIN professionals professional ON professional.id=a.professional_id
        WHERE room.id=$1 AND room.status IN('created','active') AND professional.verification_status='approved'
        AND a.status NOT IN('cancelled','completed','no_show') FOR UPDATE OF room`,
        [roomId],
      );
      if (!available.rows[0])
        throw new NotFoundException("La sala no está disponible.");
      const isProfessional = available.rows[0].professional_user_id === user.id;
      if (!isProfessional && available.rows[0].status === "created")
        throw new ConflictException(
          "La consulta está pendiente de inicio por el profesional.",
        );
      const result = await client.query(
        `UPDATE telemedicine_participants participant SET joined_at=COALESCE(joined_at,now()),left_at=NULL
         FROM telemedicine_rooms room JOIN appointments appointment ON appointment.id=room.appointment_id
         WHERE participant.room_id=$1 AND participant.user_id=$2 AND room.id=participant.room_id
           AND room.status IN('created','active') AND appointment.status NOT IN('cancelled','completed','no_show')
         RETURNING participant.room_id`,
        [roomId, user.id],
      );
      if (!result.rows[0])
        throw new NotFoundException("No puedes ingresar a esta sala.");
      await client.query(
        `INSERT INTO telemedicine_events(room_id,user_id,event_type) VALUES($1,$2,'join')`,
        [roomId, user.id],
      );
      await client.query(
        `UPDATE telemedicine_rooms SET started_at=COALESCE(started_at,now()),status='active' WHERE id=$1`,
        [roomId],
      );
      if (isProfessional)
        await client.query(
          `UPDATE appointments SET status='in_progress',updated_at=now()
        WHERE id=(SELECT appointment_id FROM telemedicine_rooms WHERE id=$1) AND status IN('scheduled','confirmed','rescheduled')`,
          [roomId],
        );
      return { registered: true };
    });
  }
  activity(
    roomId: string,
    user: RequestUser,
  ): Promise<{ participants: any[]; events: any[]; files: any[] }> {
    return this.database.transactionAsUser(user, async (client) => {
      const allowed = await client.query(
        `SELECT 1 FROM telemedicine_participants
        WHERE room_id=$1 AND user_id=$2`,
        [roomId, user.id],
      );
      if (
        !allowed.rowCount &&
        !user.roles.some((role) => ["admin", "operator"].includes(role))
      )
        throw new NotFoundException("No puedes consultar esta sala.");
      const participants = await client.query(
        `SELECT participant.user_id AS "userId",
        concat_ws(' ',person.first_name,person.last_name,person.second_last_name) AS name,
        participant.joined_at AS "joinedAt",participant.left_at AS "leftAt",
        participant.connection_failures AS "connectionFailures"
        FROM telemedicine_participants participant LEFT JOIN persons person ON person.user_id=participant.user_id
        WHERE participant.room_id=$1 ORDER BY name`,
        [roomId],
      );
      const events = await client.query(
        `SELECT id,user_id AS "userId",event_type AS "eventType",
        details,created_at AS "createdAt" FROM telemedicine_events WHERE room_id=$1 ORDER BY created_at DESC LIMIT 100`,
        [roomId],
      );
      const files = await client.query(
        `SELECT shared.id,shared.clinical_document_id AS "clinicalDocumentId",
        document.document_type AS "documentType",document.file_name AS "fileName",document.file_url AS "fileUrl",
        shared.shared_by_user_id AS "sharedByUserId",shared.shared_at AS "sharedAt"
        FROM telemedicine_shared_files shared JOIN clinical_documents document ON document.id=shared.clinical_document_id
        WHERE shared.room_id=$1 ORDER BY shared.shared_at DESC`,
        [roomId],
      );
      return {
        participants: participants.rows,
        events: events.rows,
        files: files.rows,
      };
    });
  }
  registerLeave(
    roomId: string,
    user: RequestUser,
  ): Promise<{ registered: boolean }> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `UPDATE telemedicine_participants SET left_at=now()
      WHERE room_id=$1 AND user_id=$2 AND joined_at IS NOT NULL AND left_at IS NULL RETURNING room_id`,
        [roomId, user.id],
      );
      if (!result.rowCount)
        throw new NotFoundException(
          "No existe un ingreso activo para esta sala.",
        );
      await client.query(
        `INSERT INTO telemedicine_events(room_id,user_id,event_type) VALUES($1,$2,'leave')`,
        [roomId, user.id],
      );
      return { registered: true };
    });
  }
  registerConnectionFailure(
    roomId: string,
    user: RequestUser,
  ): Promise<{ registered: boolean }> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `UPDATE telemedicine_participants SET connection_failures=connection_failures+1
      WHERE room_id=$1 AND user_id=$2 RETURNING room_id`,
        [roomId, user.id],
      );
      if (!result.rowCount)
        throw new NotFoundException(
          "No puedes registrar eventos en esta sala.",
        );
      await client.query(
        `INSERT INTO telemedicine_events(room_id,user_id,event_type) VALUES($1,$2,'connection_failure')`,
        [roomId, user.id],
      );
      return { registered: true };
    });
  }
  shareFile(
    roomId: string,
    user: RequestUser,
    clinicalDocumentId: string,
  ): Promise<{ shared: boolean }> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `INSERT INTO telemedicine_shared_files(room_id,clinical_document_id,shared_by_user_id)
      SELECT $1,document.id,$2 FROM clinical_documents document JOIN telemedicine_rooms room ON room.id=$1
      JOIN appointments appointment ON appointment.id=room.appointment_id
      WHERE document.id=$3 AND document.patient_id=appointment.patient_id
        AND room.status IN('created','active') AND appointment.status NOT IN('cancelled','completed','no_show')
        AND EXISTS(SELECT 1 FROM telemedicine_participants participant WHERE participant.room_id=$1 AND participant.user_id=$2)
        AND NOT EXISTS(SELECT 1 FROM telemedicine_shared_files current
          WHERE current.room_id=$1 AND current.clinical_document_id=$3)
      RETURNING id`,
        [roomId, user.id, clinicalDocumentId],
      );
      if (!result.rowCount)
        throw new ConflictException(
          "El documento no puede compartirse en esta sala.",
        );
      await client.query(
        `INSERT INTO telemedicine_events(room_id,user_id,event_type,details)
      VALUES($1,$2,'file_shared',jsonb_build_object('clinicalDocumentId',$3::text))`,
        [roomId, user.id, clinicalDocumentId],
      );
      return { shared: true };
    });
  }
}
