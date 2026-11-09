import { Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import { OperationsRepository } from "../../domain/ports/operations.repository";
@Injectable()
export class PostgresOperationsRepository implements OperationsRepository {
  constructor(
    private readonly database: DatabaseService,
    private readonly config: ConfigService,
  ) {}
  runMaintenance(user: RequestUser): Promise<{
    expiredPrescriptions: number;
    expiredBenefits: number;
    revokedSessions: number;
    invalidatedPasswordTokens: number;
    invalidatedRegistrationTokens: number;
    invalidatedOauthStates: number;
    prescriptionNotices: number;
    appointmentNotices: number;
    followupNotices: number;
    retriedInAppNotifications: number;
  }> {
    return this.database.transactionAsUser(user, async (client) => {
      const prescriptions = await client.query(
        `UPDATE prescriptions SET status='expired',updated_at=now()
         WHERE status='issued' AND expires_at<=now() RETURNING id`,
      );
      const benefits = await client.query(
        `UPDATE benefits SET is_active=FALSE
         WHERE is_active AND valid_until<current_date RETURNING id`,
      );
      const sessions = await client.query(
        `UPDATE user_sessions SET revoked_at=now()
         WHERE revoked_at IS NULL AND expires_at<=now() RETURNING id`,
      );
      const passwordTokens = await client.query(
        `UPDATE password_reset_tokens SET used_at=now()
         WHERE used_at IS NULL AND expires_at<=now() RETURNING id`,
      );
      const registrationTokens = await client.query(
        `UPDATE registration_email_tokens SET consumed_at=now()
         WHERE consumed_at IS NULL AND expires_at<=now() RETURNING id`,
      );
      const oauthStates = await client.query(
        `UPDATE oauth_authorization_states SET used_at=now()
         WHERE used_at IS NULL AND expires_at<=now() RETURNING id`,
      );
      const prescriptionNotices = await client.query(
        `INSERT INTO notifications(user_id,event_code,channel,title,body,
           related_entity_type,related_entity_id,status,sent_at)
         SELECT person.user_id,'prescription.expiring','in_app',
           'Tu receta está próxima a vencer','Revisa la vigencia de tu receta en Doc IA.',
           'prescription',prescription.id,'sent',now()
         FROM prescriptions prescription
         JOIN patients patient ON patient.id=prescription.patient_id
         JOIN persons person ON person.id=patient.person_id
         WHERE prescription.status='issued' AND person.user_id IS NOT NULL
           AND prescription.expires_at>now()
           AND prescription.expires_at<=now()+interval '48 hours'
           AND NOT EXISTS(SELECT 1 FROM notifications notification
             WHERE notification.user_id=person.user_id
               AND notification.event_code='prescription.expiring'
               AND notification.related_entity_id=prescription.id)
         RETURNING id`,
      );
      const appointmentNotices = await client.query(
        `INSERT INTO notifications(user_id,event_code,channel,title,body,
           related_entity_type,related_entity_id,status,sent_at)
         SELECT person.user_id,'appointment.reminder','in_app','Recordatorio de consulta',
           concat('Tienes una consulta programada para el ',
             to_char(appointment.start_at AT TIME ZONE 'America/La_Paz','DD/MM/YYYY HH24:MI'),'.'),
           'appointment',appointment.id,'sent',now()
         FROM appointments appointment
         JOIN patients patient ON patient.id=appointment.patient_id
         JOIN persons person ON person.id=patient.person_id
         WHERE appointment.status IN ('scheduled','confirmed','rescheduled')
           AND appointment.start_at>now() AND appointment.start_at<=now()+interval '24 hours'
           AND person.user_id IS NOT NULL
           AND NOT EXISTS(SELECT 1 FROM notifications notification
             WHERE notification.user_id=person.user_id
               AND notification.event_code='appointment.reminder'
               AND notification.related_entity_id=appointment.id)
         RETURNING id`,
      );
      const followupNotices = await client.query(
        `INSERT INTO notifications(user_id,event_code,channel,title,body,
           related_entity_type,related_entity_id,status,sent_at)
         SELECT person.user_id,'clinical.followup','in_app','Seguimiento médico pendiente',
           COALESCE(followup.instructions,'Tienes un seguimiento médico pendiente.'),
           'appointment_followup',followup.id,'sent',now()
         FROM appointment_followups followup
         JOIN appointments appointment ON appointment.id=followup.source_appointment_id
         JOIN patients patient ON patient.id=appointment.patient_id
         JOIN persons person ON person.id=patient.person_id
         WHERE followup.status='pending' AND followup.due_at IS NOT NULL
           AND followup.due_at<=now()+interval '24 hours' AND person.user_id IS NOT NULL
           AND NOT EXISTS(SELECT 1 FROM notifications notification
             WHERE notification.user_id=person.user_id
               AND notification.event_code='clinical.followup'
               AND notification.related_entity_id=followup.id)
         RETURNING id`,
      );
      const notificationRetries = await client.query(
        `UPDATE notifications SET status='sent',sent_at=now(),failure_reason=NULL
         WHERE channel='in_app' AND status IN ('pending','failed')
         RETURNING id`,
      );
      const result = {
        expiredPrescriptions: prescriptions.rowCount ?? 0,
        expiredBenefits: benefits.rowCount ?? 0,
        revokedSessions: sessions.rowCount ?? 0,
        invalidatedPasswordTokens: passwordTokens.rowCount ?? 0,
        invalidatedRegistrationTokens: registrationTokens.rowCount ?? 0,
        invalidatedOauthStates: oauthStates.rowCount ?? 0,
        prescriptionNotices: prescriptionNotices.rowCount ?? 0,
        appointmentNotices: appointmentNotices.rowCount ?? 0,
        followupNotices: followupNotices.rowCount ?? 0,
        retriedInAppNotifications: notificationRetries.rowCount ?? 0,
      };
      await client.query(
        `INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,new_values)
         VALUES($1,$2,'operations','daily_maintenance_processed','maintenance',$3::jsonb)`,
        [user.id, user.roleCode, JSON.stringify(result)],
      );
      return result;
    });
  }
  listPendingEmails(
    user: RequestUser,
  ): Promise<{ id: string; email: string; title: string; body: string }[]> {
    return this.database.transactionAsUser(
      user,
      async (client) =>
        (
          await client.query<{
            id: string;
            email: string;
            title: string;
            body: string;
          }>(
            `SELECT notification.id,users.email::text,notification.title,
              notification.body
             FROM notifications notification
             JOIN users ON users.id=notification.user_id
             WHERE notification.channel='email'
               AND notification.status IN ('pending','failed')
             ORDER BY notification.created_at LIMIT 50`,
          )
        ).rows,
    );
  }
  updateEmailNotification(
    user: RequestUser,
    id: string,
    status: "sent" | "failed",
    failureReason: string | null,
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      await client.query(
        `UPDATE notifications SET status=$2,sent_at=CASE WHEN $2='sent' THEN now() ELSE sent_at END,
           failure_reason=$3 WHERE id=$1`,
        [id, status, failureReason],
      );
    });
  }
}
