import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { PoolClient } from "pg";
import { DatabaseService } from "../../../database/database.service";
import { RequestUser } from "../../../common/types/request-user";
import { GuidanceRepository } from "../domain/guidance.repository";
import { RiskEvaluation, RiskPolicy } from "../domain/risk-policy";
import { MeetProvider } from "../../integrations/domain/ports/meet-provider";
@Injectable()
export class PostgresGuidanceRepository implements GuidanceRepository {
  constructor(private readonly database: DatabaseService) {}
  policy(user: RequestUser) {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<{
        policy: RiskPolicy;
        enabled: boolean;
        revision: number;
        reviewedBy: string | null;
      }>(
        `SELECT policy,app_risk_policy_is_active() AS enabled,
         revision,reviewed_by AS "reviewedBy" FROM ai_risk_policy WHERE singleton`,
      );
      return result.rows[0];
    });
  }
  savePolicy(user: RequestUser, policy: RiskPolicy) {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `UPDATE ai_risk_policy SET policy=$1::jsonb,enabled=false,revision=revision+1,
        reviewed_by=NULL,review_reference=NULL,updated_by=$2 WHERE singleton RETURNING revision`,
        [JSON.stringify(policy), user.id],
      );
      await this.audit(
        client,
        user,
        "risk_policy_changed",
        "ai_risk_policy",
        null,
      );
      return result.rows[0];
    });
  }
  approvePolicy(user: RequestUser, revision: number, reference: string) {
    return this.database.transactionAsUser(user, async (client) => {
      if (!user.roles.includes("clinical_supervisor"))
        throw new ForbiddenException(
          "La activación requiere supervisión clínica.",
        );
      const reviewer = await client.query(
        `SELECT 1 FROM professionals WHERE user_id=$1 AND verification_status='approved'`,
        [user.id],
      );
      if (!reviewer.rowCount)
        throw new ForbiddenException(
          "El revisor clínico debe estar habilitado.",
        );
      const result = await client.query(
        `UPDATE ai_risk_policy SET enabled=true,reviewed_by=$1,review_reference=$2
        WHERE singleton AND revision=$3 AND jsonb_array_length(policy->'rules')>0 RETURNING revision`,
        [user.id, reference, revision],
      );
      if (!result.rowCount)
        throw new ConflictException(
          "La política cambió o no tiene reglas. Revisa la versión actual.",
        );
      await this.audit(
        client,
        user,
        "risk_policy_clinically_approved",
        "ai_risk_policy",
        null,
      );
      return result.rows[0];
    });
  }
  context(user: RequestUser, patientId: string) {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `SELECT antecedent.description AS text FROM medical_antecedents antecedent
        JOIN patients patient ON patient.id=antecedent.patient_id JOIN persons person ON person.id=patient.person_id
        WHERE antecedent.patient_id=$1 AND person.user_id=$2 AND antecedent.is_active AND antecedent.validation_status='validated'
        UNION ALL SELECT allergy.substance AS text FROM allergies allergy
        JOIN patients patient ON patient.id=allergy.patient_id JOIN persons person ON person.id=patient.person_id
        WHERE allergy.patient_id=$1 AND person.user_id=$2 AND allergy.is_active AND allergy.validation_status='validated'`,
        [patientId, user.id],
      );
      return result.rows.map((row) => row.text).join("\n");
    });
  }
  saveAssessment(
    user: RequestUser,
    conversationId: string,
    evaluation: RiskEvaluation,
    contextUsed: boolean,
    revision: number,
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      if (evaluation.classificationStatus === "clinically_validated_rules") {
        const active = await client.query(
          "SELECT app_verify_risk_revision($1) AS active",
          [revision],
        );
        if (!active.rows[0]?.active)
          throw new ConflictException(
            "Los criterios clínicos cambiaron; vuelve a solicitar orientación.",
          );
      }
      const result = await client.query<{ id: string }>(
        `INSERT INTO ai_risk_assessments(conversation_id,patient_id,risk_level,reasons,
        recommended_action,classification_status,context_used,policy_revision,questions)
        SELECT id,patient_id,$3::risk_level,$4::jsonb,$5,$6,$7,$8,$9::jsonb FROM ai_conversations
        WHERE id=$1 AND created_by_user_id=$2 RETURNING id`,
        [
          conversationId,
          user.id,
          evaluation.riskLevel,
          JSON.stringify(evaluation.matchedRules),
          evaluation.recommendedAction,
          evaluation.classificationStatus,
          contextUsed,
          revision,
          JSON.stringify(evaluation.questions),
        ],
      );
      if (!result.rows[0])
        throw new NotFoundException("Conversación no disponible.");
      await this.audit(
        client,
        user,
        "risk_assessment_recorded",
        "ai_risk_assessment",
        result.rows[0].id,
      );
      return result.rows[0].id;
    });
  }
  decision(
    user: RequestUser,
    id: string,
    decision: string,
    relatedId?: string,
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `SELECT assessment.* FROM ai_risk_assessments assessment
        JOIN ai_conversations conversation ON conversation.id=assessment.conversation_id
        WHERE assessment.id=$1 AND conversation.created_by_user_id=$2 FOR UPDATE OF assessment`,
        [id, user.id],
      );
      const assessment = result.rows[0];
      if (!assessment) throw new NotFoundException("Evaluación no disponible.");
      if (
        !["emergency", "appointment", "call_operator", "declined"].includes(
          decision,
        )
      )
        throw new BadRequestException("Decisión no válida.");
      if (relatedId) {
        const table =
          decision === "emergency"
            ? "emergency_events"
            : decision === "appointment"
              ? "appointments"
              : decision === "call_operator"
                ? "support_call_requests"
                : null;
        if (!table)
          throw new BadRequestException("La decisión no admite vínculo.");
        const linked = await client.query(
          `SELECT 1 FROM ${table} WHERE id=$1 AND patient_id=$2`,
          [relatedId, assessment.patient_id],
        );
        if (!linked.rowCount)
          throw new NotFoundException(
            "La atención no corresponde al paciente.",
          );
      }
      await client.query(
        `UPDATE ai_risk_assessments SET user_decision=$2,decision_at=now(),related_entity_id=$3 WHERE id=$1`,
        [id, decision, relatedId ?? null],
      );
      await this.audit(
        client,
        user,
        "orientation_decision",
        "ai_risk_assessment",
        id,
      );
      return { recorded: true };
    });
  }
  calls(user: RequestUser) {
    const managesQueue =
      user.permissions.includes("emergencies.manage") &&
      user.roles.some((role) =>
        ["admin", "operator", "clinical_supervisor"].includes(role),
      );
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `SELECT call.id,call.priority,call.reason,call.status,call.result_notes AS "resultNotes",
        call.assigned_operator_id AS "professionalId",professional.user_id AS "assignedUserId",call.requested_by_user_id AS "requestedBy",
        call.requested_at AS "requestedAt",call.meeting_url AS "meetingUrl",call.duration_seconds AS "durationSeconds"
        FROM support_call_requests call LEFT JOIN professionals professional ON professional.id=call.assigned_operator_id
        WHERE $2::boolean
          OR (professional.user_id=$1 AND professional.verification_status='approved')
          OR ($3::boolean AND call.requested_by_user_id=$1)
        ORDER BY CASE priority WHEN 'red' THEN 0 WHEN 'yellow' THEN 1 ELSE 2 END,requested_at LIMIT 200`,
        [user.id, managesQueue, user.roles.includes("patient")],
      );
      return { items: result.rows };
    });
  }
  requestCall(
    user: RequestUser,
    reason: string,
    assessmentId?: string,
    emergencyId?: string,
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const patient = await client.query(
        `SELECT patient.id FROM patients patient JOIN persons person ON person.id=patient.person_id WHERE person.user_id=$1`,
        [user.id],
      );
      if (!patient.rows[0])
        throw new NotFoundException("Perfil de paciente requerido.");
      await client.query(
        "SELECT pg_advisory_xact_lock(hashtextextended($1,0))",
        [user.id],
      );
      const active = await client.query(
        `SELECT id FROM support_call_requests WHERE requested_by_user_id=$1 AND status IN('pending','assigned','in_progress')`,
        [user.id],
      );
      if (active.rowCount)
        throw new ConflictException("Ya existe una solicitud activa.");
      let priority = "green";
      if (assessmentId) {
        const assessment = await client.query(
          `SELECT risk_level FROM ai_risk_assessments WHERE id=$1 AND patient_id=$2`,
          [assessmentId, patient.rows[0].id],
        );
        if (!assessment.rows[0])
          throw new NotFoundException("Evaluación no disponible.");
        priority =
          assessment.rows[0].risk_level === "undetermined"
            ? "green"
            : assessment.rows[0].risk_level;
      }
      if (emergencyId) {
        const emergency = await client.query(
          `SELECT id FROM emergency_events WHERE id=$1 AND patient_id=$2 AND status NOT IN('closed','cancelled','false_alarm') FOR SHARE`,
          [emergencyId, patient.rows[0].id],
        );
        if (!emergency.rows[0])
          throw new NotFoundException("Emergencia activa no disponible.");
        priority = "red";
      }
      const result = await client.query(
        `INSERT INTO support_call_requests(patient_id,requested_by_user_id,reason,priority,escalation_type,escalation_reference_id)
        VALUES($1,$2,$3,$4::risk_level,$5,$6) RETURNING id,status`,
        [
          patient.rows[0].id,
          user.id,
          reason,
          priority,
          emergencyId ? "emergency" : null,
          emergencyId ?? null,
        ],
      );
      if (assessmentId)
        await client.query(
          `UPDATE ai_risk_assessments SET user_decision='call_operator',decision_at=now(),related_entity_id=$2 WHERE id=$1`,
          [assessmentId, result.rows[0].id],
        );
      await this.audit(
        client,
        user,
        "support_call_requested",
        "support_call_request",
        result.rows[0].id,
      );
      return result.rows[0];
    });
  }
  staff(user: RequestUser) {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        "SELECT * FROM app_support_staff_status()",
      );
      return { items: result.rows };
    });
  }
  transitionCall(
    user: RequestUser,
    id: string,
    action: string,
    professionalId: string | undefined,
    notes: string | undefined,
    meet: MeetProvider,
  ) {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `SELECT call.*,professional.user_id AS assigned_user FROM support_call_requests call
        LEFT JOIN professionals professional ON professional.id=call.assigned_operator_id WHERE call.id=$1 FOR UPDATE OF call`,
        [id],
      );
      const call = result.rows[0];
      if (!call) throw new NotFoundException("Solicitud no disponible.");
      const coordinator = user.roles.some((role) =>
        ["admin", "operator", "clinical_supervisor"].includes(role),
      );
      if (action === "cancel") {
        if (call.requested_by_user_id !== user.id && !coordinator)
          throw new ForbiddenException();
        if (!["pending", "assigned"].includes(call.status))
          throw new ConflictException("Solo se cancela antes de iniciar.");
        await client.query(
          `UPDATE support_call_requests SET status='cancelled',cancelled_at=now() WHERE id=$1`,
          [id],
        );
      } else if (action === "assign") {
        if (!coordinator || !professionalId) throw new ForbiddenException();
        if (!["pending", "assigned"].includes(call.status))
          throw new ConflictException("La solicitud ya inició o terminó.");
        const eligible = await client.query(
          "SELECT app_support_assignable($1,$2) AS allowed",
          [professionalId, id],
        );
        if (!eligible.rows[0]?.allowed)
          throw new ConflictException(
            "Personal clínico no habilitado o con otra llamada asignada.",
          );
        await client.query(
          `UPDATE support_call_requests SET assigned_operator_id=$2,status='assigned' WHERE id=$1`,
          [id, professionalId],
        );
      } else if (action === "start") {
        if (call.assigned_user !== user.id)
          throw new ForbiddenException(
            "Solo el profesional asignado puede iniciar.",
          );
        if (call.status !== "assigned")
          throw new ConflictException("La llamada no está asignada.");
        const valid = await client.query(
          `SELECT 1 FROM professionals WHERE user_id=$1 AND verification_status='approved' AND app_staff_is_available(id)`,
          [user.id],
        );
        if (!valid.rowCount)
          throw new ForbiddenException("Profesional no habilitado.");
        const space = await meet.createSpace();
        await client.query(
          `UPDATE support_call_requests SET status='in_progress',started_at=now(),meeting_url=$2,external_meeting_id=$3 WHERE id=$1`,
          [id, space.meetingUri, space.name],
        );
      } else if (action === "reject") {
        if (call.assigned_user !== user.id) throw new ForbiddenException();
        if (call.status !== "assigned" || !notes?.trim())
          throw new ConflictException(
            "Se requiere asignación y motivo de rechazo.",
          );
        await client.query("SELECT app_reject_support_call($1,$2)", [
          id,
          notes.trim(),
        ]);
      } else if (action === "complete") {
        if (call.assigned_user !== user.id)
          throw new ForbiddenException(
            "Solo el profesional asignado puede cerrar.",
          );
        if (call.status !== "in_progress" || !notes?.trim())
          throw new ConflictException(
            "Se requiere atención iniciada y resultado.",
          );
        await meet.endActiveConference(call.external_meeting_id);
        await client.query(
          `UPDATE support_call_requests SET status='completed',ended_at=now(),result_notes=$2,
          duration_seconds=GREATEST(0,EXTRACT(EPOCH FROM now()-started_at)::int) WHERE id=$1`,
          [id, notes.trim()],
        );
      } else throw new BadRequestException("Transición no válida.");
      await this.audit(
        client,
        user,
        "support_call_" + action,
        "support_call_request",
        id,
      );
      if (notes && action !== "reject")
        await client.query(
          `INSERT INTO support_call_history(call_id,actor_user_id,action,notes) VALUES($1,$2,$3,$4)`,
          [id, user.id, action, notes.trim()],
        );
      return { updated: true };
    });
  }
  async joinCall(user: RequestUser, id: string, meet: MeetProvider) {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<{
        meetingUrl: string;
        spaceName: string;
      }>(
        `SELECT call.meeting_url AS "meetingUrl",call.external_meeting_id AS "spaceName" FROM support_call_requests call
        LEFT JOIN professionals professional ON professional.id=call.assigned_operator_id WHERE call.id=$1 AND call.status='in_progress'
        AND (call.requested_by_user_id=$2 OR (professional.user_id=$2 AND professional.verification_status='approved'))`,
        [id, user.id],
      );
      if (!result.rows[0])
        throw new NotFoundException("Llamada no disponible para tu cuenta.");
      await meet.allowDirectJoin(result.rows[0].spaceName);
      await this.audit(
        client,
        user,
        "support_call_join",
        "support_call_request",
        id,
      );
      return { meetingUrl: result.rows[0].meetingUrl };
    });
  }
  private async audit(
    client: PoolClient,
    user: RequestUser,
    action: string,
    entity: string,
    id: string | null,
  ) {
    await client.query(
      `INSERT INTO audit_events(actor_user_id,module,action,entity_type,entity_id) VALUES($1,'guidance',$2,$3,$4)`,
      [user.id, action, entity, id],
    );
  }
}
