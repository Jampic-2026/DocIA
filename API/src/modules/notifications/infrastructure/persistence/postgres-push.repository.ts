import { Injectable } from "@nestjs/common";
import { DatabaseService } from "../../../../database/database.service";
import { PushRepository, QueuedPush } from "../../domain/ports/push";
@Injectable()
export class PostgresPushRepository implements PushRepository {
  constructor(private readonly database: DatabaseService) {}
  async claim(): Promise<QueuedPush[]> {
    return this.database.transactionWithSettings(
      {
        "app.roles": JSON.stringify(["admin"]),
        "app.permissions": JSON.stringify(["notifications.manage"]),
        "app.role_code": "system",
      },
      async (client) => {
        const result = await client.query<{
          notificationId: string;
          userId: string;
          eventCode: string;
          title: string;
          body: string;
          relatedEntityType?: string;
          relatedEntityId?: string;
        }>(
          `WITH claimed AS (
             SELECT outbox.notification_id
             FROM notification_push_outbox outbox
             WHERE outbox.processed_at IS NULL
               AND outbox.available_at <= now()
               AND outbox.attempts < 8
             ORDER BY outbox.created_at
             LIMIT 25
             FOR UPDATE SKIP LOCKED
           )
           UPDATE notification_push_outbox outbox
           SET attempts=outbox.attempts+1,
               available_at=now()+interval '5 minutes'
           FROM claimed, notifications notification
           WHERE outbox.notification_id=claimed.notification_id
             AND notification.id=outbox.notification_id
           RETURNING notification.id AS "notificationId",
             notification.user_id AS "userId",
             notification.event_code AS "eventCode",
             notification.title,
             notification.body,
             notification.related_entity_type AS "relatedEntityType",
             notification.related_entity_id AS "relatedEntityId"`,
        );
        return result.rows;
      },
    );
  }
  async patientUserId(patientId: string) {
    return this.database.transactionWithSettings(
      {
        "app.roles": JSON.stringify(["admin"]),
        "app.permissions": JSON.stringify(["patients.read"]),
        "app.role_code": "system",
      },
      async (client) => {
        const result = await client.query<{ userId: string }>(
          `SELECT person.user_id AS "userId"
       FROM patients patient
       JOIN persons person ON person.id=patient.person_id
       WHERE patient.id=$1 AND person.user_id IS NOT NULL`,
          [patientId],
        );
        return result.rows[0]?.userId;
      },
    );
  }
  async activeTokensForUser(userId: string, eventCode: string) {
    return this.database.transactionWithSettings(
      { "app.user_id": userId },
      async (client) => {
        const result = await client.query<{ token: string }>(
          `SELECT token
       FROM push_device_tokens
       WHERE user_id=$1 AND is_active
         AND COALESCE((
           SELECT preference.enabled
           FROM notification_preferences preference
           WHERE preference.user_id=$1
             AND preference.channel='push'
             AND (
               preference.event_code=$2
               OR $2 LIKE preference.event_code || '.%'
             )
           ORDER BY preference.event_code=$2 DESC
           LIMIT 1
         ),true)
       ORDER BY last_seen_at DESC`,
          [userId, eventCode],
        );
        return result.rows.map((row) => row.token);
      },
    );
  }
  async deactivateTokens(userId: string, tokens: string[]) {
    await this.database.transactionWithSettings(
      { "app.user_id": userId },
      async (client) => {
        await client.query(
          `UPDATE push_device_tokens
       SET is_active=false,updated_at=now()
       WHERE token=ANY($1::text[])`,
          [tokens],
        );
      },
    );
  }
  async complete(id: string) {
    await this.database.query(
      "UPDATE notification_push_outbox SET processed_at=now(),last_error=NULL WHERE notification_id=$1",
      [id],
    );
  }
  async fail(id: string, message: string) {
    await this.database.query(
      "UPDATE notification_push_outbox SET last_error=$2,available_at=now()+LEAST(attempts,8)*interval '5 minutes' WHERE notification_id=$1",
      [id, message.slice(0, 1000)],
    );
  }
}
