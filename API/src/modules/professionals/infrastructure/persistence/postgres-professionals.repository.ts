import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { QueryResultRow } from "pg";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { ProfessionalDirectoryEntry } from "../../domain/professional-directory-entry";
import { ProfessionalSchedule } from "../../domain/professional-schedule";
import { ProfessionalProfile } from "../../domain/professional-profile";
import {
  SaveWorkShift,
  ShiftQuery,
  StaffAvailabilityQuery,
} from "../../domain/work-shift";
import {
  ProfessionalResource,
  ProfessionalsRepository,
} from "../../domain/ports/professionals.repository";

type DirectoryRow = QueryResultRow & {
  id: string;
  full_name: string;
  specialty_id: string;
  specialty: string;
  years_experience: number | null;
  average_rating: string;
  rating_count: number;
  availability: ProfessionalDirectoryEntry["availability"];
  bookable_slots: ProfessionalDirectoryEntry["bookableSlots"];
  requires_referral: boolean;
  public_details: ProfessionalDirectoryEntry["publicDetails"];
};

@Injectable()
export class PostgresProfessionalsRepository implements ProfessionalsRepository {
  constructor(private readonly database: DatabaseService) {}

  listShifts(user: RequestUser, query: ShiftQuery) {
    return this.database.transactionAsUser(user, async (client) => {
      if (query.from && query.to && new Date(query.to) <= new Date(query.from))
        throw new BadRequestException("El período de consulta no es válido.");
      const result = await client.query(
        `SELECT shift.id,shift.professional_id AS "professionalId",shift.start_at AS "startAt",shift.end_at AS "endAt",
        shift.status,shift.location_text AS location,shift.area_text AS area,shift.notes,
        concat_ws(' ',person.first_name,person.last_name) AS "professionalName"
        FROM work_shifts shift JOIN professionals professional ON professional.id=shift.professional_id JOIN persons person ON person.id=professional.person_id
        WHERE ($1::timestamptz IS NULL OR shift.end_at>$1) AND ($2::timestamptz IS NULL OR shift.start_at<$2)
        ORDER BY shift.start_at DESC LIMIT 200`,
        [query.from ?? null, query.to ?? null],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,new_values)
        VALUES($1,$2,'professionals','work_shifts_read','work_shift',$3::jsonb)`,
        [user.id, user.roleCode, JSON.stringify(query)],
      );
      return result.rows;
    });
  }

  saveShift(user: RequestUser, input: SaveWorkShift, id?: string) {
    if (new Date(input.endAt) <= new Date(input.startAt))
      throw new BadRequestException(
        "El fin del turno debe ser posterior al inicio.",
      );
    return this.database.transactionAsUser(user, async (client) => {
      const professional = await client.query(
        `SELECT id,user_id FROM professionals WHERE id=$1 AND professional_type='nurse' AND verification_status='approved' FOR UPDATE`,
        [input.professionalId],
      );
      if (!professional.rows[0])
        throw new BadRequestException(
          "Selecciona personal de enfermería habilitado.",
        );
      const old = id
        ? (
            await client.query(
              `SELECT * FROM work_shifts WHERE id=$1 FOR UPDATE`,
              [id],
            )
          ).rows[0]
        : undefined;
      if (id && !old) throw new NotFoundException("El turno no existe.");
      if (old && old.professional_id !== input.professionalId)
        throw new BadRequestException(
          "No se puede cambiar el titular de un turno. Cancela y registra la nueva asignación.",
        );
      if (old && new Date(old.start_at) <= new Date())
        throw new ConflictException(
          "No se puede reescribir un turno iniciado o histórico.",
        );
      if (input.status === "assigned") {
        const overlap = await client.query(
          `SELECT id FROM work_shifts WHERE professional_id=$1 AND status<>'cancelled'
          AND start_at<$3::timestamptz AND end_at>$2::timestamptz AND ($4::uuid IS NULL OR id<>$4) LIMIT 1`,
          [input.professionalId, input.startAt, input.endAt, id ?? null],
        );
        if (overlap.rows[0])
          throw new ConflictException(
            "El horario se superpone con otro turno.",
          );
      }
      const values = [
        input.professionalId,
        user.id,
        input.startAt,
        input.endAt,
        input.location.trim(),
        input.area?.trim() || null,
        input.notes?.trim() || null,
        input.status,
      ];
      const result = id
        ? await client.query(
            `UPDATE work_shifts SET start_at=$2,end_at=$3,location_text=$4,area_text=$5,notes=$6,status=$7,updated_at=now()
        WHERE id=$8 AND professional_id=$1 RETURNING *`,
            [
              input.professionalId,
              input.startAt,
              input.endAt,
              input.location.trim(),
              input.area?.trim() || null,
              input.notes?.trim() || null,
              input.status,
              id,
            ],
          )
        : await client.query(
            `INSERT INTO work_shifts(professional_id,assigned_by_user_id,start_at,end_at,location_text,area_text,notes,status)
          VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
            values,
          );
      await client.query(
        `INSERT INTO work_shift_history(shift_id,changed_by_user_id,old_values,new_values,reason) VALUES($1,$2,$3::jsonb,$4::jsonb,$5)`,
        [
          result.rows[0].id,
          user.id,
          old ? JSON.stringify(old) : null,
          JSON.stringify(result.rows[0]),
          input.reason.trim(),
        ],
      );
      await client.query(
        `INSERT INTO notifications(user_id,event_code,channel,title,body,related_entity_type,related_entity_id,status)
        VALUES($1,'work_shifts','in_app','Actualización de turno','Consulta tu planificación de turnos.','work_shift',$2,'sent')`,
        [professional.rows[0].user_id, result.rows[0].id],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id,reason)
        VALUES($1,$2,'professionals',$3,'work_shift',$4,$5)`,
        [
          user.id,
          user.roleCode,
          id ? "work_shift_updated" : "work_shift_assigned",
          result.rows[0].id,
          input.reason.trim(),
        ],
      );
      return { id: result.rows[0].id };
    });
  }

  availableStaff(user: RequestUser, query: StaffAvailabilityQuery) {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `WITH staff AS (
        SELECT professional.id,professional.professional_type AS role,concat_ws(' ',person.first_name,person.last_name) AS name,
          specialty.name AS specialty,specialty.id AS "specialtyId",current_shift.location_text AS location,current_shift.area_text AS area,
          app_staff_is_available(professional.id,$5) AS "availableNow"
        FROM professionals professional JOIN persons person ON person.id=professional.person_id
        LEFT JOIN professional_specialties link ON link.professional_id=professional.id AND link.is_primary
        LEFT JOIN specialties specialty ON specialty.id=link.specialty_id
        LEFT JOIN LATERAL(SELECT * FROM work_shifts shift WHERE shift.professional_id=professional.id AND shift.status='assigned' AND shift.start_at<=now() AND shift.end_at>now() ORDER BY shift.start_at LIMIT 1) current_shift ON TRUE
        WHERE professional.verification_status='approved'
          AND ($1::text IS NULL OR professional.professional_type=$1 OR EXISTS(SELECT 1 FROM user_roles ur JOIN roles r ON r.id=ur.role_id
            WHERE ur.user_id=professional.user_id AND r.code=$1 AND ur.revoked_at IS NULL AND ur.valid_from<=now() AND (ur.valid_until IS NULL OR ur.valid_until>now())))
          AND ($3::uuid IS NULL OR specialty.id=$3)
          AND ($5::text IS NULL OR EXISTS(SELECT 1 FROM professional_availability av WHERE av.professional_id=professional.id AND av.is_active AND av.modality::text=$5))
      ) SELECT * FROM staff WHERE ($2::text IS NULL OR location ILIKE '%' || $2 || '%')
        AND ($4::boolean IS NOT TRUE OR "availableNow") ORDER BY name LIMIT 200`,
        [
          query.role ?? null,
          query.location ?? null,
          query.specialtyId ?? null,
          query.availableOnly === "true",
          query.serviceType ?? null,
        ],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,new_values)
        VALUES($1,$2,'professionals','staff_availability_read','professional',$3::jsonb)`,
        [user.id, user.roleCode, JSON.stringify(query)],
      );
      return result.rows;
    });
  }

  listDirectory(user: RequestUser): Promise<ProfessionalDirectoryEntry[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<DirectoryRow>(`
        SELECT professional.id,
          person.full_name,
          specialty.id AS specialty_id, specialty.name AS specialty,professional_specialty.requires_referral,
          app_professional_public_details(professional.id) AS public_details,
          professional.years_experience, professional.average_rating, professional.rating_count,
          (SELECT COALESCE(jsonb_agg(jsonb_build_object('startAt',slots.start_at,'endAt',slots.end_at,'modality',slots.modality) ORDER BY slots.start_at),'[]') FROM (
            SELECT DISTINCT starts.start_at,starts.start_at+interval '30 minutes' AS end_at,av_window.modality
            FROM professional_availability av_window
            CROSS JOIN generate_series(0,59) day_offset
            CROSS JOIN LATERAL generate_series(((now() AT TIME ZONE 'America/La_Paz')::date+day_offset+av_window.start_time) AT TIME ZONE 'America/La_Paz',
              ((now() AT TIME ZONE 'America/La_Paz')::date+day_offset+av_window.end_time) AT TIME ZONE 'America/La_Paz'-interval '30 minutes',interval '30 minutes') starts(start_at)
            WHERE av_window.professional_id=professional.id AND av_window.is_active
              AND av_window.weekday=extract(dow FROM (now() AT TIME ZONE 'America/La_Paz')::date+day_offset)
              AND app_professional_slot_free(professional.id,starts.start_at,starts.start_at+interval '30 minutes')
          ) slots) AS bookable_slots,
          COALESCE(jsonb_agg(jsonb_build_object(
            'weekday', availability.weekday,
            'startTime', to_char(availability.start_time, 'HH24:MI'),
            'endTime', to_char(availability.end_time, 'HH24:MI'),
            'modality', availability.modality
          ) ORDER BY availability.weekday, availability.start_time)
          FILTER (WHERE availability.id IS NOT NULL), '[]'::jsonb) AS availability
        FROM professionals professional
        JOIN LATERAL app_professional_directory_identity(professional.id) person ON TRUE
        JOIN professional_specialties professional_specialty
          ON professional_specialty.professional_id = professional.id
         AND professional_specialty.is_primary
        JOIN specialties specialty ON specialty.id = professional_specialty.specialty_id
        LEFT JOIN professional_availability availability
          ON availability.professional_id = professional.id AND availability.is_active
        WHERE professional.verification_status = 'approved'
          AND professional.public_profile_enabled
          AND professional.professional_type = 'doctor'
          AND specialty.is_active
        GROUP BY professional.id, person.full_name, specialty.id,professional_specialty.requires_referral
        ORDER BY full_name
      `);
      return result.rows.map((row) => ({
        id: row.id,
        fullName: row.full_name,
        bookableSlots: row.bookable_slots,
        requiresReferral: row.requires_referral,
        publicDetails: row.public_details,
        specialtyId: row.specialty_id,
        specialty: row.specialty,
        yearsExperience: row.years_experience ?? 0,
        averageRating: Number(row.average_rating),
        ratingCount: row.rating_count,
        availability: row.availability,
      }));
    });
  }

  getOwnSchedule(user: RequestUser): Promise<ProfessionalSchedule> {
    return this.database.transactionAsUser(user, async (client) => {
      const availability = await client.query<{
        id: string;
        weekday: number;
        start_time: string;
        end_time: string;
        modality: "telemedicine" | "home_visit" | "in_person";
      }>(
        `SELECT availability.id,availability.weekday,
          to_char(availability.start_time,'HH24:MI') AS start_time,
          to_char(availability.end_time,'HH24:MI') AS end_time,availability.modality
        FROM professional_availability availability
        JOIN professionals professional ON professional.id=availability.professional_id
        WHERE professional.user_id=$1 AND availability.is_active
        ORDER BY availability.weekday,availability.start_time`,
        [user.id],
      );
      const blocks = await client.query<{
        id: string;
        start_at: Date;
        end_at: Date;
        reason: string | null;
      }>(
        `SELECT block.id,block.start_at,block.end_at,block.reason
        FROM professional_time_blocks block
        JOIN professionals professional ON professional.id=block.professional_id
        WHERE professional.user_id=$1 AND block.end_at>=now()
        ORDER BY block.start_at`,
        [user.id],
      );
      return {
        availability: availability.rows.map((row) => ({
          id: row.id,
          weekday: row.weekday,
          startTime: row.start_time,
          endTime: row.end_time,
          modality: row.modality,
        })),
        timeBlocks: blocks.rows.map((row) => ({
          id: row.id,
          startAt: row.start_at,
          endAt: row.end_at,
          reason: row.reason,
        })),
      };
    });
  }

  createAvailability(
    user: RequestUser,
    input: {
      weekday: number;
      startTime: string;
      endTime: string;
      modality: "telemedicine" | "home_visit" | "in_person";
    },
  ): Promise<void> {
    if (input.endTime <= input.startTime) {
      throw new BadRequestException(
        "La hora final debe ser posterior a la inicial.",
      );
    }
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `INSERT INTO professional_availability(
          professional_id,weekday,start_time,end_time,modality
        ) SELECT professional.id,$2,$3::time,$4::time,$5::appointment_modality
        FROM professionals professional WHERE professional.user_id=$1
          AND NOT EXISTS(SELECT 1 FROM professional_availability current
            WHERE current.professional_id=professional.id AND current.is_active
              AND current.weekday=$2 AND current.start_time<$4::time
              AND current.end_time>$3::time) RETURNING id`,
        [
          user.id,
          input.weekday,
          input.startTime,
          input.endTime,
          input.modality,
        ],
      );
      if (!result.rowCount) {
        throw new BadRequestException(
          "El horario se superpone con otra disponibilidad.",
        );
      }
    });
  }

  removeAvailability(user: RequestUser, id: string): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `UPDATE professional_availability availability
        SET is_active=false FROM professionals professional
        WHERE availability.id=$1 AND professional.id=availability.professional_id
          AND professional.user_id=$2 AND availability.is_active RETURNING availability.id`,
        [id, user.id],
      );
      if (!result.rowCount)
        throw new NotFoundException("No se encontró el horario.");
    });
  }

  createTimeBlock(
    user: RequestUser,
    input: {
      startAt: Date;
      endAt: Date;
      reason?: string;
    },
  ): Promise<void> {
    if (
      !Number.isFinite(input.startAt.getTime()) ||
      !Number.isFinite(input.endAt.getTime()) ||
      input.endAt <= input.startAt
    ) {
      throw new BadRequestException("El intervalo de bloqueo no es válido.");
    }
    return this.database.transactionAsUser(user, async (client) => {
      await client.query(
        "SELECT pg_advisory_xact_lock(hashtext(id::text)) FROM professionals WHERE user_id=$1",
        [user.id],
      );
      const result = await client.query(
        `INSERT INTO professional_time_blocks(
          professional_id,start_at,end_at,reason
        ) SELECT professional.id,$2,$3,NULLIF($4,'') FROM professionals professional
        WHERE professional.user_id=$1 AND NOT EXISTS(SELECT 1 FROM appointments appointment
          WHERE appointment.professional_id=professional.id
            AND appointment.status IN ('scheduled','confirmed','rescheduled','in_progress')
            AND appointment.start_at<$3 AND appointment.end_at>$2) RETURNING id`,
        [user.id, input.startAt, input.endAt, input.reason?.trim() ?? ""],
      );
      if (!result.rowCount) {
        throw new BadRequestException(
          "Existe una cita activa dentro del intervalo seleccionado.",
        );
      }
    });
  }

  removeTimeBlock(user: RequestUser, id: string): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `DELETE FROM professional_time_blocks block
        USING professionals professional WHERE block.id=$1
          AND professional.id=block.professional_id AND professional.user_id=$2
        RETURNING block.id`,
        [id, user.id],
      );
      if (!result.rowCount)
        throw new NotFoundException("No se encontró el bloqueo.");
    });
  }

  getOwnProfile(user: RequestUser): Promise<ProfessionalProfile> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<{
        id: string;
        professional_type: string;
        license_number: string | null;
        bio: string | null;
        academic_background: string | null;
        public_certifications: string[];
        years_experience: number | null;
        verification_status: string;
        public_profile_enabled: boolean;
        pending_specialty_id: string | null;
        specialties: ProfessionalProfile["specialties"];
        documents: ProfessionalProfile["documents"];
      }>(
        `SELECT professional.id,professional.professional_type,
          professional.license_number,professional.bio,professional.years_experience,professional.academic_background,professional.public_certifications,
          professional.verification_status,professional.public_profile_enabled,professional.pending_specialty_id,
          COALESCE((SELECT jsonb_agg(jsonb_build_object('id',specialty.id,
            'name',specialty.name,'isPrimary',link.is_primary) ORDER BY link.is_primary DESC,specialty.name)
            FROM professional_specialties link JOIN specialties specialty ON specialty.id=link.specialty_id
            WHERE link.professional_id=professional.id),'[]'::jsonb) AS specialties,
          COALESCE((SELECT jsonb_agg(jsonb_build_object('id',document.id,
            'documentType',document.document_type,'fileUrl',document.file_url,
            'status',document.status,'observation',document.observation,
            'createdAt',document.created_at) ORDER BY document.created_at DESC)
            FROM professional_documents document WHERE document.professional_id=professional.id),'[]'::jsonb) AS documents
        FROM professionals professional WHERE professional.user_id=$1`,
        [user.id],
      );
      const row = result.rows[0];
      if (!row)
        throw new NotFoundException("No se encontró el perfil profesional.");
      return {
        id: row.id,
        professionalType: row.professional_type,
        licenseNumber: row.license_number,
        bio: row.bio,
        academicBackground: row.academic_background,
        publicCertifications: row.public_certifications,
        yearsExperience: row.years_experience,
        verificationStatus: row.verification_status,
        publicProfileEnabled: row.public_profile_enabled,
        pendingSpecialtyId: row.pending_specialty_id,
        specialties: row.specialties,
        documents: row.documents.map((document) => ({
          ...document,
          createdAt: new Date(document.createdAt),
        })),
      };
    });
  }

  updateOwnProfile(
    user: RequestUser,
    input: {
      academicBackground?: string;
      publicCertifications?: string[];
      licenseNumber?: string;
      specialtyId?: string;
      bio?: string;
      yearsExperience?: number;
      publicProfileEnabled?: boolean;
    },
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      const old = await client.query(
        `SELECT * FROM professionals WHERE user_id=$1 FOR UPDATE`,
        [user.id],
      );
      if (!old.rows[0])
        throw new NotFoundException("No se encontró el perfil profesional.");
      const currentSpecialty = await client.query(
        `SELECT specialty_id FROM professional_specialties WHERE professional_id=$1 AND is_primary`,
        [old.rows[0].id],
      );
      if (input.specialtyId) {
        const exists = await client.query(
          `SELECT id FROM specialties WHERE id=$1 AND is_active`,
          [input.specialtyId],
        );
        if (!exists.rows[0])
          throw new BadRequestException("La especialidad no está disponible.");
      }
      const changedPublicCredentials =
        (input.academicBackground !== undefined &&
          input.academicBackground.trim() !==
            (old.rows[0].academic_background ?? "")) ||
        (input.publicCertifications !== undefined &&
          JSON.stringify(input.publicCertifications) !==
            JSON.stringify(old.rows[0].public_certifications));
      const changedCredentials =
        changedPublicCredentials ||
        (input.licenseNumber !== undefined &&
          input.licenseNumber.trim() !== (old.rows[0].license_number ?? "")) ||
        (input.specialtyId !== undefined &&
          input.specialtyId !==
            (old.rows[0].pending_specialty_id ??
              currentSpecialty.rows[0]?.specialty_id));
      const result = await client.query(
        `UPDATE professionals SET
          license_number=CASE WHEN $2::boolean THEN NULLIF($3,'') ELSE license_number END,
          bio=CASE WHEN $4::boolean THEN NULLIF($5,'') ELSE bio END,
          years_experience=COALESCE($6,years_experience),
          public_profile_enabled=CASE WHEN $8 OR verification_status<>'approved' THEN FALSE ELSE COALESCE($7,public_profile_enabled) END,
          verification_status=CASE WHEN $8 THEN 'under_review' ELSE verification_status END,
          verified_at=CASE WHEN $8 THEN NULL ELSE verified_at END,
          pending_specialty_id=COALESCE($9::uuid,pending_specialty_id),
          academic_background=CASE WHEN $10::text IS NOT NULL THEN NULLIF($10,'') ELSE academic_background END,
          public_certifications=COALESCE($11::text[],public_certifications),updated_at=now()
        WHERE user_id=$1 RETURNING id`,
        [
          user.id,
          input.licenseNumber !== undefined,
          input.licenseNumber?.trim() ?? "",
          input.bio !== undefined,
          input.bio?.trim() ?? "",
          input.yearsExperience ?? null,
          input.publicProfileEnabled ?? null,
          changedCredentials,
          input.specialtyId ?? null,
          input.academicBackground?.trim() ?? null,
          input.publicCertifications ?? null,
        ],
      );
      if (!result.rowCount)
        throw new NotFoundException("No se encontró el perfil profesional.");
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id,old_values,new_values)
        VALUES($1,$2,'professionals',$3,'professional',$4,$5::jsonb,$6::jsonb)`,
        [
          user.id,
          user.roleCode,
          changedCredentials
            ? "professional_credentials_revalidation_requested"
            : "professional_profile_updated",
          old.rows[0].id,
          JSON.stringify({
            licenseNumber: old.rows[0].license_number,
            verificationStatus: old.rows[0].verification_status,
          }),
          JSON.stringify(input),
        ],
      );
    });
  }

  createOwnDocument(
    user: RequestUser,
    input: { documentType: string; fileUrl: string },
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      await client.query(
        "SELECT id FROM professionals WHERE user_id=$1 FOR UPDATE",
        [user.id],
      );
      const result = await client.query(
        `INSERT INTO professional_documents(
          professional_id,document_type,file_url,status
        ) SELECT professional.id,$2,$3,'pending' FROM professionals professional
        WHERE professional.user_id=$1 RETURNING id`,
        [user.id, input.documentType.trim(), input.fileUrl.trim()],
      );
      await client.query(
        "UPDATE professionals SET verification_status='under_review',public_profile_enabled=FALSE,verified_at=NULL,updated_at=now() WHERE user_id=$1",
        [user.id],
      );
      if (!result.rowCount)
        throw new NotFoundException("No se encontró el perfil profesional.");
    });
  }
  resource(
    user: RequestUser,
    resource: ProfessionalResource,
  ): Promise<unknown[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const tables: Record<ProfessionalResource, string> = {
        specialties: "specialties",
        professional_specialties: "professional_specialties",
        work_shifts: "work_shifts",
        work_shift_history: "work_shift_history",
      };
      return (await client.query(`SELECT * FROM ${tables[resource]} LIMIT 200`))
        .rows;
    });
  }
}
