import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  BadRequestException,
} from "@nestjs/common";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import {
  CreateEmergency,
  EmergencyCare,
  emergencyTransitions,
  isEmergencyCoordinator,
} from "../../domain/emergency-policy";
import {
  EmergenciesRepository,
  EmergencyRecord,
} from "../../domain/ports/emergencies.repository";
import { PoolClient } from "pg";

@Injectable()
export class PostgresEmergenciesRepository implements EmergenciesRepository {
  constructor(private readonly database: DatabaseService) {}

  async list(user: RequestUser) {
    const operational = user.roles.some((role) =>
      ["admin", "operator", "clinical_supervisor"].includes(role),
    );
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<EmergencyRecord>(
        `SELECT event.id,event.status,event.risk_level AS "riskLevel",
          event.description,event.latitude,event.longitude,
          event.manual_address AS "manualAddress",
          event.reference,event.coverage_available AS "coverageAvailable",
          event.opened_at AS "openedAt",
          event.assigned_professional_id AS "assignedProfessionalId",
          event.assigned_operator_id AS "assignedOperatorId",
          event.patient_id AS "patientId",event.accepted_at AS "acceptedAt",
          patient_contact.patient_name AS "patientName",
          patient_contact.patient_phone AS "patientPhone",
          assigned_contact.team_name AS "assignedTeamName",
          assigned_contact.team_phone AS "assignedTeamPhone"
         FROM emergency_events event
         LEFT JOIN LATERAL app_emergency_patient_contact(event.id)
           patient_contact ON true
         LEFT JOIN LATERAL app_emergency_assignee_contact(event.id)
           assigned_contact ON true
         WHERE $2::boolean OR event.requested_by_user_id=$1
           OR app_can_patient_action(event.patient_id,'emergencies.manage')
           OR app_is_emergency_assignee(event.id)
           OR EXISTS (
             SELECT 1 FROM patients patient
             JOIN persons person ON person.id=patient.person_id
             WHERE patient.id=event.patient_id AND person.user_id=$1
           )
         ORDER BY
           CASE event.risk_level WHEN 'red' THEN 0 WHEN 'yellow' THEN 1 ELSE 2 END,
           event.opened_at ASC`,
        [user.id, operational],
      );
      return { items: result.rows };
    });
  }

  async resource(
    user: RequestUser,
    resource:
      | "emergency-status-history"
      | "emergency-triage-answers"
      | "emergency-care-records"
      | "support-call-requests",
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const tables = {
        "emergency-status-history": "emergency_status_history",
        "emergency-triage-answers": "emergency_triage_answers",
        "emergency-care-records": "emergency_care_records",
        "support-call-requests": "support_call_requests",
      } as const;
      return {
        items: (
          await client.query(`SELECT * FROM ${tables[resource]} LIMIT 200`)
        ).rows,
      };
    });
  }

  async create(user: RequestUser, input: CreateEmergency) {
    const event = await this.database.transactionAsUser(
      user,
      async (client) => {
        const patient = await client.query<{ id: string }>(
          `SELECT patient.id FROM patients patient JOIN persons person ON person.id=patient.person_id
         WHERE ($2::uuid IS NULL AND person.user_id=$1)
           OR (patient.id=$2 AND app_can_patient_action(patient.id,'emergencies.manage')) LIMIT 1`,
          [user.id, input.patientId ?? null],
        );
        if (!patient.rows[0])
          throw new NotFoundException(
            "La cuenta no tiene un perfil de paciente.",
          );
        await client.query(
          `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`,
          [patient.rows[0].id],
        );
        const active = await client.query(
          `SELECT 1 FROM emergency_events WHERE patient_id=$1
         AND status NOT IN ('closed','cancelled','false_alarm') LIMIT 1`,
          [patient.rows[0].id],
        );
        if (active.rows[0])
          throw new ConflictException(
            "Ya existe una solicitud de emergencia activa.",
          );
        const result = await client.query<EmergencyRecord>(
          `INSERT INTO emergency_events(patient_id,requested_by_user_id,risk_level,risk_source,
          description,manual_address,latitude,longitude)
          VALUES($1,$2,$3,'external',NULLIF($4,''),NULLIF($5,''),$6,$7)
         RETURNING id,status,risk_level AS "riskLevel",description,
          manual_address AS "manualAddress",latitude,longitude,
          opened_at AS "openedAt",patient_id AS "patientId"`,
          [
            patient.rows[0].id,
            user.id,
            input.riskLevel,
            input.description?.trim() ?? "",
            input.manualAddress?.trim() ?? "",
            input.latitude ?? null,
            input.longitude ?? null,
          ],
        );
        await client.query(
          `INSERT INTO emergency_status_history
        (emergency_id,new_status,changed_by_user_id,notes) VALUES($1,'received',$2,'Solicitud del paciente')`,
          [result.rows[0].id, user.id],
        );
        await client.query(`SELECT app_notify_emergency_update($1,TRUE)`, [
          result.rows[0].id,
        ]);
        return result.rows[0];
      },
    );

    return event;
  }

  async cancel(user: RequestUser, id: string) {
    const event = await this.database.transactionAsUser(
      user,
      async (client) => {
        const result = await client.query<EmergencyRecord>(
          `UPDATE emergency_events SET status='cancelled',cancellation_reason='Cancelada por el solicitante'
         WHERE id=$1 AND requested_by_user_id=$2 AND app_can_patient_action(patient_id,'emergencies.manage') AND status IN('received','confirming','validating')
         RETURNING id,status,risk_level AS "riskLevel",description,
          manual_address AS "manualAddress",latitude,longitude,
          opened_at AS "openedAt"`,
          [id, user.id],
        );
        if (!result.rows[0])
          throw new ConflictException("La emergencia no puede cancelarse.");
        await client.query(
          `INSERT INTO emergency_status_history(emergency_id,new_status,changed_by_user_id,notes) VALUES($1,'cancelled',$2,'Cancelada por el solicitante')`,
          [id, user.id],
        );
        await client.query(`SELECT app_notify_emergency_update($1)`, [id]);
        return result.rows[0];
      },
    );

    return event;
  }

  async assign(
    user: RequestUser,
    id: string,
    input: { professionalId?: string; operatorId?: string },
  ) {
    this.assertOperational(user);
    if (!input.professionalId && !input.operatorId) {
      throw new ConflictException(
        "Selecciona al menos un integrante del equipo.",
      );
    }
    await this.database.transactionAsUser(user, async (client) => {
      const current = await client.query<{
        status: string;
        requested_by_user_id: string;
      }>(
        `SELECT status,requested_by_user_id FROM emergency_events
         WHERE id=$1 FOR UPDATE`,
        [id],
      );
      if (!current.rows[0])
        throw new NotFoundException("La emergencia no existe.");
      if (
        ["closed", "cancelled", "false_alarm"].includes(current.rows[0].status)
      ) {
        throw new ConflictException("La emergencia ya está finalizada.");
      }
      if (input.professionalId) {
        const professional = await client.query(
          `SELECT 1 FROM professionals WHERE id=$1
           AND verification_status='approved' AND professional_type IN ('doctor','nurse')`,
          [input.professionalId],
        );
        if (!professional.rows[0]) {
          throw new NotFoundException(
            "El profesional seleccionado no está habilitado.",
          );
        }
      }
      if (input.operatorId) {
        const operator = await client.query(
          `SELECT 1 FROM professionals WHERE id=$1
           AND verification_status='approved' AND professional_type='operator'`,
          [input.operatorId],
        );
        if (!operator.rows[0]) {
          throw new NotFoundException(
            "El operador seleccionado no está habilitado.",
          );
        }
      }
      await client.query(
        `UPDATE emergency_events SET assigned_professional_id=COALESCE($2,assigned_professional_id),
          assigned_operator_id=COALESCE($3,assigned_operator_id),status='assigned',
          assigned_at=now(),accepted_at=NULL,updated_at=now() WHERE id=$1`,
        [id, input.professionalId ?? null, input.operatorId ?? null],
      );
      await client.query(
        `INSERT INTO emergency_status_history
         (emergency_id,old_status,new_status,changed_by_user_id,notes)
         VALUES($1,$2,'assigned',$3,'Equipo asignado')`,
        [id, current.rows[0].status, user.id],
      );
      await client.query(`SELECT app_notify_emergency_update($1)`, [id]);
      return current.rows[0].requested_by_user_id;
    });

    return this.findEvent(user, id);
  }

  async updateStatus(
    user: RequestUser,
    id: string,
    input: { status: string; notes?: string },
  ) {
    const allowed = emergencyTransitions;
    await this.database.transactionAsUser(user, async (client) => {
      const current = await client.query<{
        status: string;
        requested_by_user_id: string;
        accepted_at: Date | null;
      }>(
        `SELECT status,requested_by_user_id,accepted_at FROM emergency_events
         WHERE id=$1 FOR UPDATE`,
        [id],
      );
      if (!current.rows[0])
        throw new NotFoundException("La emergencia no existe.");
      if (!isEmergencyCoordinator(user.roles)) {
        const assigned = await client.query(
          `SELECT app_is_emergency_assignee($1) AS allowed`,
          [id],
        );
        if (
          !assigned.rows[0]?.allowed ||
          !current.rows[0].accepted_at ||
          ![
            "on_route",
            "on_site",
            "in_care",
            "referred",
            "closed",
            "false_alarm",
          ].includes(input.status)
        ) {
          throw new ForbiddenException(
            "La acción requiere una asignación aceptada y vigente.",
          );
        }
      }
      if (["closed", "referred"].includes(input.status)) {
        const care = await client.query(
          `SELECT id FROM emergency_care_records WHERE emergency_id=$1 AND care_type=$2 LIMIT 1`,
          [id, input.status === "closed" ? "closure" : "referral"],
        );
        if (!care.rows[0])
          throw new ConflictException(
            "Registra el cierre o la derivación antes de cambiar el estado.",
          );
      }
      if (input.status === "closed") {
        const assessment = await client.query(
          `SELECT 1 FROM emergency_care_records WHERE emergency_id=$1 AND care_type IN ('nursing_assessment','medical_assessment') LIMIT 1`,
          [id],
        );
        if (!assessment.rows[0])
          throw new ConflictException(
            "Falta registrar la valoración inicial antes de cerrar la atención.",
          );
      }
      if (
        ["cancelled", "false_alarm"].includes(input.status) &&
        (input.notes?.trim().length ?? 0) < 3
      )
        throw new BadRequestException("Indica el motivo del cierre operativo.");
      if (!allowed[current.rows[0].status]?.includes(input.status)) {
        throw new ConflictException("El cambio de estado no está permitido.");
      }
      await client.query(
        `UPDATE emergency_events SET status=$2::emergency_status,
          arrived_at=CASE WHEN $2::text='on_site' THEN COALESCE(arrived_at,now()) ELSE arrived_at END,
          closed_at=CASE WHEN $2::text IN('closed','cancelled','false_alarm') THEN now() ELSE closed_at END,
          cancellation_reason=CASE WHEN $2::text='cancelled' THEN NULLIF($3,'') ELSE cancellation_reason END,
          false_alarm_reason=CASE WHEN $2::text='false_alarm' THEN NULLIF($3,'') ELSE false_alarm_reason END,
          updated_at=now() WHERE id=$1`,
        [id, input.status, input.notes?.trim() ?? ""],
      );
      await client.query(
        `INSERT INTO emergency_status_history
         (emergency_id,old_status,new_status,changed_by_user_id,notes)
         VALUES($1,$2,$3,$4,NULLIF($5,''))`,
        [
          id,
          current.rows[0].status,
          input.status,
          user.id,
          input.notes?.trim() ?? "",
        ],
      );
      await client.query(`SELECT app_notify_emergency_update($1)`, [id]);
      return current.rows[0].requested_by_user_id;
    });

    return this.findEvent(user, id);
  }

  async decideAssignment(
    user: RequestUser,
    id: string,
    input: { decision: "accepted" | "rejected"; reason?: string },
  ) {
    if (input.decision === "rejected" && (input.reason?.trim().length ?? 0) < 3)
      throw new BadRequestException("Indica el motivo del rechazo.");
    const event = await this.database.transactionAsUser(
      user,
      async (client) => {
        const current = await client.query(
          `SELECT id,status,assigned_professional_id,accepted_at FROM emergency_events WHERE id=$1 FOR UPDATE`,
          [id],
        );
        const found = current.rows[0];
        if (!found) throw new NotFoundException("La emergencia no existe.");
        const authorization = await client.query(
          `SELECT app_is_emergency_assignee($1) AS allowed`,
          [id],
        );
        if (
          !authorization.rows[0]?.allowed ||
          found.status !== "assigned" ||
          found.accepted_at
        )
          throw new ForbiddenException(
            "No tienes una asignación pendiente para este caso.",
          );
        await client.query(
          `INSERT INTO emergency_assignment_decisions(emergency_id,professional_id,decision,reason) VALUES($1,$2,$3,$4)`,
          [
            id,
            found.assigned_professional_id,
            input.decision,
            input.reason?.trim() ?? null,
          ],
        );
        // Notify while the rejecting professional still has authorized context.
        await client.query(`SELECT app_notify_emergency_update($1,$2)`, [
          id,
          input.decision === "rejected",
        ]);
        await client.query(
          `UPDATE emergency_events SET accepted_at=CASE WHEN $2='accepted' THEN now() ELSE NULL END,
        assigned_professional_id=CASE WHEN $2='rejected' THEN NULL ELSE assigned_professional_id END,
        status=CASE WHEN $2='rejected' THEN 'validating'::emergency_status ELSE status END,updated_at=now() WHERE id=$1`,
          [id, input.decision],
        );
        await client.query(
          `INSERT INTO emergency_status_history(emergency_id,old_status,new_status,changed_by_user_id,notes)
        VALUES($1,'assigned',$2,$3,$4)`,
          [
            id,
            input.decision === "rejected" ? "validating" : "assigned",
            user.id,
            input.reason?.trim() || "Asignación aceptada",
          ],
        );
        await this.auditCare(
          client,
          user,
          id,
          "emergency_assignment_decided",
          input,
        );
        return {
          id,
          decision: input.decision,
          status: input.decision === "accepted" ? "assigned" : "validating",
        };
      },
    );
    // Rejection deliberately removes access; return only the decision, not patient data.
    return event;
  }

  async recordCare(user: RequestUser, id: string, input: EmergencyCare) {
    if (input.careType === "referral" && !input.referralDestination?.trim())
      throw new BadRequestException("Indica el destino de la derivación.");
    return this.database.transactionAsUser(user, async (client) => {
      const event = await client.query(
        `SELECT patient_id,status,accepted_at,assigned_professional_id FROM emergency_events WHERE id=$1 FOR UPDATE`,
        [id],
      );
      const authorization = await client.query(
        `SELECT app_is_emergency_assignee($1) AS allowed`,
        [id],
      );
      const found = event.rows[0];
      if (
        !found ||
        !authorization.rows[0]?.allowed ||
        !found.accepted_at ||
        !["on_site", "in_care", "referred"].includes(found.status)
      )
        throw new ForbiddenException(
          "La atención requiere un caso activo, aceptado y asignado a tu cuenta.",
        );
      if (
        input.careType === "medical_assessment" &&
        !user.roles.some((role) =>
          ["doctor_general", "doctor_specialist"].includes(role),
        )
      )
        throw new ForbiddenException(
          "La valoración médica requiere habilitación médica.",
        );
      const result = await client.query(
        `INSERT INTO emergency_care_records(emergency_id,professional_id,care_type,notes,content)
        VALUES($1,$2,$3,$4,$5::jsonb) RETURNING *`,
        [
          id,
          found.assigned_professional_id,
          input.careType,
          input.notes.trim(),
          JSON.stringify({
            symptoms: input.symptoms,
            assessment: input.assessment.trim(),
            procedures: input.procedures?.trim(),
            referralDestination: input.referralDestination?.trim(),
          }),
        ],
      );
      await client.query(
        `INSERT INTO clinical_records(patient_id,record_type,title,content,source,validation_status,author_user_id,related_emergency_id)
        VALUES($1,'emergency',$2,$3::jsonb,'professional','validated',$4,$5)`,
        [
          found.patient_id,
          input.careType === "nursing_assessment"
            ? "Valoración de enfermería"
            : "Registro de atención de emergencia",
          JSON.stringify({ ...input, careRecordId: result.rows[0].id }),
          user.id,
          id,
        ],
      );
      await this.auditCare(client, user, id, "emergency_care_recorded", {
        recordId: result.rows[0].id,
        careType: input.careType,
      });
      return result.rows[0];
    });
  }

  async careHistory(user: RequestUser, id: string) {
    return this.database.transactionAsUser(user, async (client) => {
      const event = await client.query(
        `SELECT patient_id FROM emergency_events WHERE id=$1`,
        [id],
      );
      if (!event.rows[0])
        throw new NotFoundException("La emergencia no existe.");
      await client.query(
        `INSERT INTO clinical_access_logs(actor_user_id,actor_role,patient_id,section,purpose,access_granted)
        VALUES($1,$2,$3,'emergency_care','Consulta de atención',TRUE)`,
        [user.id, user.roleCode, event.rows[0].patient_id],
      );
      return (
        await client.query(
          `SELECT id,emergency_id,professional_id,care_type,notes,content,created_at FROM emergency_care_records WHERE emergency_id=$1 ORDER BY created_at`,
          [id],
        )
      ).rows;
    });
  }

  private async auditCare(
    client: PoolClient,
    user: RequestUser,
    id: string,
    action: string,
    content: unknown,
  ) {
    await client.query(
      `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id,new_values)
      VALUES($1,$2,'emergencies',$3,'emergency',$4,$5::jsonb)`,
      [user.id, user.roleCode, action, id, JSON.stringify(content)],
    );
  }

  private async findEvent(user: RequestUser, id: string) {
    const events = await this.list(user);
    const event = events.items.find((item: { id: string }) => item.id === id);
    if (!event) throw new NotFoundException("La emergencia no existe.");
    return event;
  }

  private assertOperational(user: RequestUser) {
    if (
      !user.roles.some((role) =>
        ["admin", "operator", "clinical_supervisor"].includes(role),
      )
    ) {
      throw new ForbiddenException("Esta acción requiere un rol operativo.");
    }
  }
}
