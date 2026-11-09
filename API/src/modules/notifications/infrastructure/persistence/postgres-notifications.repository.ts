import { Injectable, NotFoundException } from "@nestjs/common";
import { RequestUser } from "../../../../common/types/request-user";
import { DatabaseService } from "../../../../database/database.service";
import {
  NotificationPreference,
  UserNotification,
} from "../../domain/notification";
import { NotificationsRepository } from "../../domain/ports/notifications.repository";

@Injectable()
export class PostgresNotificationsRepository implements NotificationsRepository {
  constructor(private readonly database: DatabaseService) {}

  list(user: RequestUser): Promise<UserNotification[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<UserNotification>(
        `SELECT id,event_code AS "eventCode",channel::text,title,body,
          related_entity_type AS "relatedEntityType",
          related_entity_id AS "relatedEntityId",status,
          sent_at AS "sentAt",read_at AS "readAt",created_at AS "createdAt"
         FROM notifications
         WHERE user_id=$1
         ORDER BY created_at DESC LIMIT 100`,
        [user.id],
      );
      return result.rows;
    });
  }

  markRead(user: RequestUser, id: string): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `UPDATE notifications
         SET read_at=COALESCE(read_at,now()),status='read'
         WHERE id=$1 AND user_id=$2 RETURNING id`,
        [id, user.id],
      );
      if (!result.rows[0]) {
        throw new NotFoundException("La notificación no existe.");
      }
    });
  }

  markAllRead(user: RequestUser): Promise<number> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query(
        `UPDATE notifications SET read_at=COALESCE(read_at,now()),status='read'
         WHERE user_id=$1 AND read_at IS NULL`,
        [user.id],
      );
      return result.rowCount ?? 0;
    });
  }

  listPreferences(user: RequestUser): Promise<NotificationPreference[]> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<NotificationPreference>(
        `SELECT event_code AS "eventCode",channel::text,enabled,
          updated_at AS "updatedAt"
         FROM notification_preferences WHERE user_id=$1
         ORDER BY event_code,channel`,
        [user.id],
      );
      return result.rows;
    });
  }

  updatePreference(
    user: RequestUser,
    preference: { eventCode: string; channel: string; enabled: boolean },
  ): Promise<NotificationPreference> {
    return this.database.transactionAsUser(user, async (client) => {
      const result = await client.query<NotificationPreference>(
        `INSERT INTO notification_preferences
          (user_id,event_code,channel,enabled)
         VALUES($1,$2,$3::notification_channel,$4)
         ON CONFLICT(user_id,event_code,channel) DO UPDATE
         SET enabled=EXCLUDED.enabled,updated_at=now()
         RETURNING event_code AS "eventCode",channel::text,enabled,
          updated_at AS "updatedAt"`,
        [user.id, preference.eventCode, preference.channel, preference.enabled],
      );
      return result.rows[0];
    });
  }

  registerPushDevice(
    user: RequestUser,
    input: {
      token: string;
      platform: string;
      deviceId?: string;
      appVersion?: string;
    },
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      await client.query(
        `INSERT INTO push_device_tokens
          (user_id,token,platform,device_id,app_version,is_active,last_seen_at)
         VALUES($1,$2,$3,$4,$5,true,now())
         ON CONFLICT(token) DO UPDATE
         SET user_id=EXCLUDED.user_id,
          platform=EXCLUDED.platform,
          device_id=EXCLUDED.device_id,
          app_version=EXCLUDED.app_version,
          is_active=true,
          last_seen_at=now(),
          updated_at=now()`,
        [
          user.id,
          input.token,
          input.platform,
          input.deviceId ?? null,
          input.appVersion ?? null,
        ],
      );
    });
  }

  unregisterPushDevice(user: RequestUser, token: string): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      await client.query(
        `UPDATE push_device_tokens
         SET is_active=false,updated_at=now()
         WHERE user_id=$1 AND token=$2`,
        [user.id, token],
      );
    });
  }

  createForUser(
    user: RequestUser,
    targetUserId: string,
    notification: {
      eventCode: string;
      title: string;
      body: string;
      relatedEntityType?: string;
      relatedEntityId?: string;
    },
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      await client.query(
        `INSERT INTO notifications
          (user_id,event_code,channel,title,body,related_entity_type,
           related_entity_id,status,sent_at)
         SELECT $1,$2::varchar(100),'in_app',$3,$4,
           NULLIF($5,'')::varchar(80),$6,'sent',now()
         WHERE COALESCE((
           SELECT preference.enabled FROM notification_preferences preference
           WHERE preference.user_id=$1 AND preference.event_code=$2
             AND preference.channel='in_app'
         ),true)`,
        [
          targetUserId,
          notification.eventCode,
          notification.title,
          notification.body,
          notification.relatedEntityType ?? "",
          notification.relatedEntityId ?? null,
        ],
      );
    });
  }

  createForPatient(
    user: RequestUser,
    patientId: string,
    notification: {
      eventCode: string;
      title: string;
      body: string;
      relatedEntityType?: string;
      relatedEntityId?: string;
    },
  ): Promise<void> {
    return this.database.transactionAsUser(user, async (client) => {
      await client.query(
        `INSERT INTO notifications
          (user_id,event_code,channel,title,body,related_entity_type,
           related_entity_id,status,sent_at)
         SELECT person.user_id,$2::varchar(100),'in_app',$3,$4,
           NULLIF($5,'')::varchar(80),$6,'sent',now()
         FROM patients patient
         JOIN persons person ON person.id=patient.person_id
         WHERE patient.id=$1 AND person.user_id IS NOT NULL
           AND COALESCE((
             SELECT preference.enabled
             FROM notification_preferences preference
             WHERE preference.user_id=person.user_id
               AND preference.event_code=$2
               AND preference.channel='in_app'
           ),true)`,
        [
          patientId,
          notification.eventCode,
          notification.title,
          notification.body,
          notification.relatedEntityType ?? "",
          notification.relatedEntityId ?? null,
        ],
      );
    });
  }
}
