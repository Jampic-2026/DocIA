import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { PoolClient, QueryResultRow } from "pg";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { Appointment } from "../../domain/appointment";
import {
  AppointmentResource,
  AppointmentsRepository,
} from "../../domain/ports/appointments.repository";

type AppointmentRow = QueryResultRow & {
  id: string;
  patient_id: string;
  patient_name: string;
  professional_id: string;
  professional_name: string;
  specialty: string;
  modality: Appointment["modality"];
  status: Appointment["status"];
  start_at: Date;
  end_at: Date;
  reason: string | null;
};

@Injectable()
export class PostgresAppointmentsRepository implements AppointmentsRepository {
  markNoShow(
    user: RequestUser,
    appointmentId: string,
    reason: string,
  ): Promise<Appointment> {
    if (
      !user.roles.some((role) =>
        ["doctor_general", "doctor_specialist"].includes(role),
      )
    )
      throw new BadRequestException(
        "La inasistencia debe registrarla el médico asignado.",
      );
    return this.database.transactionAsUser(user, async (client) => {
      const current = (
        await client.query(
          `SELECT appointment.id,appointment.status,appointment.end_at FROM appointments appointment
        JOIN professionals professional ON professional.id=appointment.professional_id
        WHERE appointment.id=$1 AND professional.user_id=$2 AND professional.verification_status='approved' FOR UPDATE OF appointment`,
          [appointmentId, user.id],
        )
      ).rows[0];
      if (!current)
        throw new NotFoundException("No existe una cita asignada a tu cuenta.");
      if (
        !["scheduled", "confirmed", "rescheduled"].includes(current.status) ||
        new Date(current.end_at) > new Date()
      )
        throw new ConflictException(
          "Solo puede registrarse inasistencia al finalizar el horario de una cita pendiente.",
        );
      await client.query(
        `UPDATE appointments SET status='no_show',updated_at=now() WHERE id=$1`,
        [appointmentId],
      );
      await client.query(
        `INSERT INTO appointment_status_history(appointment_id,old_status,new_status,changed_by_user_id,reason)
        VALUES($1,$2,'no_show',$3,$4)`,
        [appointmentId, current.status, user.id, reason.trim()],
      );
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id)
        VALUES($1,$2,'appointments','no_show_recorded','appointment',$3)`,
        [user.id, user.roleCode, appointmentId],
      );
      return this.findById(client, appointmentId);
    });
  }
  constructor(private readonly database: DatabaseService) {}

  listForUser(user: RequestUser): Promise<Appointment[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const hasOperationalScope = user.roles.some((role) =>
        ["admin", "operator", "clinical_supervisor"].includes(role),
      );

      const result = await client.query<AppointmentRow>(
        `
        SELECT
          a.id,
          a.patient_id,
          concat_ws(
            ' ',
            patient_person.first_name,
            patient_person.last_name,
            patient_person.second_last_name
          ) AS patient_name,
          a.professional_id,
          professional_person.full_name AS professional_name,
          COALESCE(s.name, 'Atención médica') AS specialty,
          a.modality,
          a.status,
          a.start_at,
          a.end_at,
          a.reason
        FROM appointments a
        JOIN patients patient ON patient.id = a.patient_id
        JOIN persons patient_person ON patient_person.id = patient.person_id
        JOIN professionals professional ON professional.id = a.professional_id
        JOIN LATERAL app_appointment_professional_identity(a.id) professional_person ON TRUE
        LEFT JOIN specialties s ON s.id = a.specialty_id
        WHERE
          $2::boolean
          OR patient_person.user_id = $1
          OR app_can_patient_action(a.patient_id,'appointments.manage')
          OR professional.user_id = $1
        ORDER BY a.start_at ASC
        `,
        [user.id, hasOperationalScope],
      );

      return result.rows.map((row) => ({
        id: row.id,
        patientId: row.patient_id,
        patientName: row.patient_name,
        professionalId: row.professional_id,
        professionalName: row.professional_name,
        specialty: row.specialty,
        modality: row.modality,
        status: row.status,
        startAt: row.start_at,
        endAt: row.end_at,
        reason: row.reason,
      }));
    });
  }
  create(
    user: RequestUser,
    input: {
      professionalId: string;
      serviceId?: string;
      patientId?: string;
      specialtyId: string;
      modality: Appointment["modality"];
      startAt: Date;
      endAt: Date;
      reason?: string;
    },
  ): Promise<Appointment> {
    if (input.startAt <= new Date() || input.endAt <= input.startAt) {
      throw new BadRequestException("El horario de la cita no es válido.");
    }
    return this.database.transactionAsUser(user, async (client) => {
      await client.query("SELECT pg_advisory_xact_lock(hashtext($1))", [
        input.professionalId,
      ]);
      const patient = input.patientId
        ? await client.query<{ id: string }>(
            `SELECT id FROM patients WHERE id=$1 AND app_can_patient_action(id,'appointments.manage')`,
            [input.patientId],
          )
        : await client.query<{ id: string }>(
            `SELECT patient.id FROM patients patient
         JOIN persons person ON person.id = patient.person_id
         WHERE person.user_id = $1 LIMIT 1`,
            [user.id],
          );
      if (!patient.rows[0])
        throw new BadRequestException(
          "La cuenta no tiene un perfil de paciente.",
        );

      const professional = await client.query(
        `SELECT 1 FROM professionals professional
         JOIN professional_specialties specialty ON specialty.professional_id = professional.id
           AND specialty.specialty_id = $2
         WHERE professional.id = $1 AND professional.verification_status = 'approved'
           AND professional.public_profile_enabled`,
        [input.professionalId, input.specialtyId],
      );
      if (!professional.rows[0]) {
        throw new NotFoundException(
          "El profesional o la especialidad no está disponible.",
        );
      }
      const specialtyPolicy = (
        await client.query(
          `SELECT link.requires_referral FROM professional_specialties link JOIN specialties specialty ON specialty.id=link.specialty_id WHERE link.specialty_id=$1 AND link.professional_id=$2 AND specialty.is_active`,
          [input.specialtyId, input.professionalId],
        )
      ).rows[0];
      if (!specialtyPolicy)
        throw new NotFoundException("La especialidad no esta disponible.");
      if (
        specialtyPolicy.requires_referral &&
        !(
          await client.query(
            "SELECT app_patient_has_referral($1,$2) AS allowed",
            [patient.rows[0].id, input.specialtyId],
          )
        ).rows[0].allowed
      )
        throw new ConflictException(
          "Esta especialidad requiere una derivaci\u00f3n activa.",
        );
      const available = await client.query(
        `SELECT 1 FROM professional_availability
         WHERE professional_id = $1 AND modality = $2 AND is_active
           AND weekday = EXTRACT(DOW FROM ($3::timestamptz AT TIME ZONE 'America/La_Paz'))
           AND start_time <= (($3::timestamptz AT TIME ZONE 'America/La_Paz')::time)
           AND end_time >= (($4::timestamptz AT TIME ZONE 'America/La_Paz')::time)`,
        [input.professionalId, input.modality, input.startAt, input.endAt],
      );
      if (!available.rows[0]) {
        throw new ConflictException(
          "El horario no está dentro de la disponibilidad publicada.",
        );
      }
      const free = await client.query(
        "SELECT app_professional_slot_free($1,$2,$3) AS free",
        [input.professionalId, input.startAt, input.endAt],
      );
      if (!free.rows[0]?.free)
        throw new ConflictException(
          "El horario seleccionado ya no est\u00e1 disponible.",
        );
      const inserted = await client.query<{ id: string }>(
        `INSERT INTO appointments (patient_id, professional_id, specialty_id, modality,
          start_at, end_at, reason, created_by_user_id)
         VALUES ($1,$2,$3,$4,$5,$6,NULLIF($7,''),$8) RETURNING id`,
        [
          patient.rows[0].id,
          input.professionalId,
          input.specialtyId,
          input.modality,
          input.startAt,
          input.endAt,
          input.reason?.trim() ?? "",
          user.id,
        ],
      );
      if (input.serviceId) {
        const tariff = (
          await client.query(
            `SELECT service.id,service.code,service.name,price.charge_mode,price.coin_price,price.price,price.currency,
          COALESCE((app_professional_public_details($2)->>'isSpecialist')::boolean,FALSE) AS specialist
          FROM service_catalog service JOIN LATERAL(SELECT * FROM price_list WHERE service_id=service.id AND valid_from<=current_date
            AND (valid_until IS NULL OR valid_until>=current_date) ORDER BY valid_from DESC,created_at DESC LIMIT 1) price ON TRUE
          WHERE service.id=$1 AND service.is_active`,
            [input.serviceId, input.professionalId],
          )
        ).rows[0];
        if (!tariff)
          throw new ConflictException(
            "No existe tarifa vigente para el servicio.",
          );
        const expected =
          input.modality === "home_visit"
            ? "home_visit"
            : "consult_" +
              (tariff.specialist ? "specialist" : "general") +
              "_" +
              input.modality;
        if (
          tariff.code !== expected ||
          (tariff.charge_mode === "coins"
            ? tariff.coin_price == null
            : tariff.price == null)
        )
          throw new ConflictException(
            "La tarifa no corresponde al profesional y modalidad seleccionados.",
          );
        const order = await client.query(
          `INSERT INTO payment_orders(user_id,patient_id,service_id,appointment_id,related_entity_type,related_entity_id,concept,charge_mode,coin_amount,amount,currency,status,due_at)
          VALUES($1,$2,$3,$4,'appointment',$4,$5,$6,$7,$8,$9,'pending',now()+interval '24 hours') RETURNING id`,
          [
            user.id,
            patient.rows[0].id,
            input.serviceId,
            inserted.rows[0].id,
            tariff.name,
            tariff.charge_mode,
            tariff.charge_mode === "coins" ? tariff.coin_price : null,
            tariff.charge_mode === "fiat" ? tariff.price : null,
            tariff.currency,
          ],
        );
        await client.query(
          `INSERT INTO audit_events(actor_user_id,actor_role,patient_id,module,action,entity_type,entity_id)
          VALUES($1,$2,$3,'payments','appointment_order_created','payment_order',$4)`,
          [user.id, user.roleCode, patient.rows[0].id, order.rows[0].id],
        );
      }
      const result = await client.query<AppointmentRow>(
        `SELECT a.id, a.patient_id,
          concat_ws(' ', pp.first_name, pp.last_name, pp.second_last_name) AS patient_name,
          a.professional_id,
          dp.full_name AS professional_name,
          s.name AS specialty, a.modality, a.status, a.start_at, a.end_at, a.reason
         FROM appointments a
         JOIN patients p ON p.id=a.patient_id JOIN persons pp ON pp.id=p.person_id
         JOIN professionals d ON d.id=a.professional_id JOIN LATERAL app_appointment_professional_identity(a.id) dp ON TRUE
         JOIN specialties s ON s.id=a.specialty_id WHERE a.id=$1`,
        [inserted.rows[0].id],
      );
      const row = result.rows[0];
      return {
        id: row.id,
        patientId: row.patient_id,
        patientName: row.patient_name,
        professionalId: row.professional_id,
        professionalName: row.professional_name,
        specialty: row.specialty,
        modality: row.modality,
        status: row.status,
        startAt: row.start_at,
        endAt: row.end_at,
        reason: row.reason,
      };
    });
  }

  cancel(
    user: RequestUser,
    appointmentId: string,
    reason?: string,
  ): Promise<Appointment> {
    return this.database.transactionAsUser(user, async (client) => {
      const current = await this.findPatientAppointment(
        client,
        user,
        appointmentId,
      );
      if (!["scheduled", "confirmed", "rescheduled"].includes(current.status)) {
        throw new ConflictException("La cita ya no puede cancelarse.");
      }
      if (current.start_at <= new Date()) {
        throw new ConflictException("Una cita iniciada no puede cancelarse.");
      }
      await client.query(
        `UPDATE appointments SET status='cancelled',cancellation_reason=NULLIF($2,'')
         WHERE id=$1`,
        [appointmentId, reason?.trim() ?? ""],
      );
      await client.query(
        `INSERT INTO appointment_status_history
         (appointment_id,old_status,new_status,changed_by_user_id,reason)
         VALUES($1,$2,'cancelled',$3,NULLIF($4,''))`,
        [appointmentId, current.status, user.id, reason?.trim() ?? ""],
      );
      return this.findById(client, appointmentId);
    });
  }

  reschedule(
    user: RequestUser,
    appointmentId: string,
    startAt: Date,
    endAt: Date,
  ): Promise<Appointment> {
    if (
      Number.isNaN(startAt.getTime()) ||
      Number.isNaN(endAt.getTime()) ||
      startAt <= new Date() ||
      endAt <= startAt
    ) {
      throw new BadRequestException("El nuevo horario no es válido.");
    }
    return this.database.transactionAsUser(user, async (client) => {
      const current = await this.findPatientAppointment(
        client,
        user,
        appointmentId,
      );
      if (!["scheduled", "confirmed", "rescheduled"].includes(current.status)) {
        throw new ConflictException("La cita ya no puede reprogramarse.");
      }
      if (current.start_at <= new Date()) {
        throw new ConflictException(
          "Una cita iniciada no puede reprogramarse.",
        );
      }
      await client.query("SELECT pg_advisory_xact_lock(hashtext($1))", [
        current.professional_id,
      ]);
      const available = await client.query(
        `SELECT 1 FROM professional_availability
         WHERE professional_id=$1 AND modality=$2 AND is_active
           AND weekday=EXTRACT(DOW FROM ($3::timestamptz AT TIME ZONE 'America/La_Paz'))
           AND start_time<=(($3::timestamptz AT TIME ZONE 'America/La_Paz')::time)
           AND end_time>=(($4::timestamptz AT TIME ZONE 'America/La_Paz')::time)`,
        [current.professional_id, current.modality, startAt, endAt],
      );
      if (!available.rows[0]) {
        throw new ConflictException(
          "El horario no está dentro de la disponibilidad publicada.",
        );
      }
      if (
        !(
          await client.query(
            "SELECT app_professional_slot_free($1,$2,$3,$4) AS free",
            [current.professional_id, startAt, endAt, appointmentId],
          )
        ).rows[0]?.free
      )
        throw new ConflictException(
          "El horario seleccionado ya no est\u00e1 disponible.",
        );
      await client.query(
        `UPDATE appointments SET status='rescheduled',start_at=$2,end_at=$3
         WHERE id=$1`,
        [appointmentId, startAt, endAt],
      );
      await client.query(
        `INSERT INTO appointment_status_history
         (appointment_id,old_status,new_status,changed_by_user_id,reason)
         VALUES($1,$2,'rescheduled',$3,$4)`,
        [
          appointmentId,
          current.status,
          user.id,
          user.roles.some((role) =>
            ["doctor_general", "doctor_specialist", "nurse"].includes(role),
          )
            ? "Reprogramada por el profesional"
            : "Reprogramada por el paciente",
        ],
      );
      return this.findById(client, appointmentId);
    });
  }

  participantUserIds(user: RequestUser, appointmentId: string) {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<{
        patientUserId?: string;
        professionalUserId?: string;
        alertUserIds?: string[];
      }>(
        `SELECT patient_person.user_id AS "patientUserId",
           professional.user_id AS "professionalUserId",
           ARRAY(SELECT user_id FROM app_patient_alert_recipients(appointment.patient_id,'appointments.manage')) AS "alertUserIds"
         FROM appointments appointment
         JOIN patients patient ON patient.id=appointment.patient_id
         JOIN persons patient_person ON patient_person.id=patient.person_id
         JOIN professionals professional
           ON professional.id=appointment.professional_id
         WHERE appointment.id=$1`,
        [appointmentId],
      );
      if (!result.rows[0]) throw new NotFoundException("La cita no existe.");
      return result.rows[0];
    });
  }

  listCareActions(user: RequestUser): Promise<{
    followups: unknown[];
    referrals: unknown[];
    ratings: unknown[];
  }> {
    return this.database.transactionAsUser(user, async (client) => {
      const followups = await client.query(
        `SELECT followup.id,
          followup.source_appointment_id AS "sourceAppointmentId",
          followup.followup_appointment_id AS "followupAppointmentId",
          followup.recommended_at AS "recommendedAt",followup.due_at AS "dueAt",
          followup.instructions,followup.status,
          concat_ws(' ',person.first_name,person.last_name,person.second_last_name) AS "professionalName"
        FROM appointment_followups followup
        JOIN appointments appointment ON appointment.id=followup.source_appointment_id
        JOIN patients patient ON patient.id=appointment.patient_id
        JOIN persons patient_person ON patient_person.id=patient.person_id
        JOIN professionals professional ON professional.id=followup.recommended_by_professional_id
        JOIN persons person ON person.id=professional.person_id
        WHERE patient_person.user_id=$1 OR professional.user_id=$1
        ORDER BY COALESCE(followup.due_at,followup.recommended_at) DESC`,
        [user.id],
      );
      const referrals = await client.query(
        `SELECT referral.id,referral.patient_id AS "patientId",
          specialty.id AS "specialtyId",specialty.name AS specialty,referral.reason,
          referral.priority,referral.referral_type AS "referralType",referral.status,
          referral.valid_from AS "validFrom",referral.valid_until AS "validUntil",
          concat_ws(' ',person.first_name,person.last_name,person.second_last_name) AS "professionalName"
        FROM referrals referral JOIN specialties specialty ON specialty.id=referral.specialty_id
        JOIN patients patient ON patient.id=referral.patient_id
        JOIN persons patient_person ON patient_person.id=patient.person_id
        JOIN professionals professional ON professional.id=referral.issued_by_professional_id
        JOIN persons person ON person.id=professional.person_id
        WHERE patient_person.user_id=$1 OR professional.user_id=$1
        ORDER BY referral.created_at DESC`,
        [user.id],
      );
      const ratings = await client.query(
        `SELECT rating.id,rating.appointment_id AS "appointmentId",
          rating.rating,rating.comment,rating.created_at AS "createdAt"
        FROM appointment_ratings rating JOIN patients patient ON patient.id=rating.patient_id
        JOIN persons person ON person.id=patient.person_id
        JOIN professionals professional ON professional.id=rating.professional_id
        WHERE person.user_id=$1 OR professional.user_id=$1 ORDER BY rating.created_at DESC`,
        [user.id],
      );
      return {
        followups: followups.rows,
        referrals: referrals.rows,
        ratings: ratings.rows,
      };
    });
  }

  rate(
    user: RequestUser,
    appointmentId: string,
    rating: number,
    comment?: string,
    publicComment?: boolean,
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      try {
        await client.query(
          `SELECT app_rate_completed_appointment($1,$2,$3,$4)`,
          [appointmentId, rating, comment ?? null, publicComment ?? false],
        );
      } catch (error) {
        if (["23505", "22023"].includes((error as { code: string }).code))
          throw new BadRequestException(
            "La cita no puede calificarse o ya fue calificada.",
          );
        throw error;
      }
    });
  }

  createReferral(
    user: RequestUser,
    input: {
      patientId: string;
      specialtyId: string;
      reason: string;
      priority: string;
      referralType: string;
      validUntil?: Date;
    },
  ): Promise<string> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<{ id: string }>(
        `INSERT INTO referrals(
          patient_id,issued_by_professional_id,specialty_id,reason,priority,
          referral_type,valid_until
        ) SELECT $2,professional.id,$3,$4,$5::risk_level,$6,$7
        FROM professionals professional WHERE professional.user_id=$1
          AND EXISTS(SELECT 1 FROM specialties specialty WHERE specialty.id=$3 AND specialty.is_active)
          AND EXISTS(SELECT 1 FROM appointments appointment
            WHERE appointment.patient_id=$2 AND appointment.professional_id=professional.id
              AND appointment.status IN ('in_progress','completed')) RETURNING id`,
        [
          user.id,
          input.patientId,
          input.specialtyId,
          input.reason.trim(),
          input.priority,
          input.referralType,
          input.validUntil ?? null,
        ],
      );
      const row = result.rows[0];
      if (!row)
        throw new BadRequestException(
          "No existe una relación clínica válida para emitir la derivación.",
        );
      return row.id;
    });
  }

  private async findPatientAppointment(
    client: PoolClient,
    user: RequestUser,
    appointmentId: string,
  ) {
    const operational = user.roles.some((role) =>
      ["admin", "operator", "clinical_supervisor"].includes(role),
    );
    const result = await client.query<AppointmentRow>(
      `SELECT a.id,a.patient_id,a.professional_id,a.modality,a.status,
        a.start_at,a.end_at,a.reason,'' AS patient_name,
        '' AS professional_name,'' AS specialty
       FROM appointments a JOIN patients patient ON patient.id=a.patient_id
       JOIN persons person ON person.id=patient.person_id
       JOIN professionals professional ON professional.id=a.professional_id
       WHERE a.id=$1
         AND (person.user_id=$2 OR app_can_patient_action(a.patient_id,'appointments.manage') OR professional.user_id=$2 OR $3::boolean)
       FOR UPDATE`,
      [appointmentId, user.id, operational],
    );
    if (!result.rows[0]) {
      throw new NotFoundException("La cita no existe o no puedes modificarla.");
    }
    return result.rows[0];
  }

  private async findById(client: PoolClient, appointmentId: string) {
    const result = await client.query<AppointmentRow>(
      `SELECT a.id,a.patient_id,
        concat_ws(' ',pp.first_name,pp.last_name,pp.second_last_name) AS patient_name,
        a.professional_id,
        dp.full_name AS professional_name,
        COALESCE(s.name,'Atención médica') AS specialty,a.modality,a.status,
        a.start_at,a.end_at,a.reason
       FROM appointments a
       JOIN patients p ON p.id=a.patient_id JOIN persons pp ON pp.id=p.person_id
       JOIN professionals d ON d.id=a.professional_id JOIN LATERAL app_appointment_professional_identity(a.id) dp ON TRUE
       LEFT JOIN specialties s ON s.id=a.specialty_id WHERE a.id=$1`,
      [appointmentId],
    );
    const row = result.rows[0];
    if (!row) throw new NotFoundException("La cita no existe.");
    return {
      id: row.id,
      patientId: row.patient_id,
      patientName: row.patient_name,
      professionalId: row.professional_id,
      professionalName: row.professional_name,
      specialty: row.specialty,
      modality: row.modality,
      status: row.status,
      startAt: row.start_at,
      endAt: row.end_at,
      reason: row.reason,
    };
  }
  resource(
    user: RequestUser,
    resource: AppointmentResource,
  ): Promise<unknown[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const tables: Record<AppointmentResource, string> = {
        appointment_status_history: "appointment_status_history",
        clinical_notes: "clinical_notes",
        diagnoses: "diagnoses",
        treatments: "treatments",
      };
      return (await client.query(`SELECT * FROM ${tables[resource]} LIMIT 200`))
        .rows;
    });
  }
}
