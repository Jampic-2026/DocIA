import { RequestUser } from "../../../../common/types/request-user";
import { NotificationPreference, UserNotification } from "../notification";

export const NOTIFICATIONS_REPOSITORY = Symbol("NOTIFICATIONS_REPOSITORY");

export interface NotificationsRepository {
  list(user: RequestUser): Promise<UserNotification[]>;
  markRead(user: RequestUser, id: string): Promise<void>;
  markAllRead(user: RequestUser): Promise<number>;
  listPreferences(user: RequestUser): Promise<NotificationPreference[]>;
  updatePreference(
    user: RequestUser,
    preference: { eventCode: string; channel: string; enabled: boolean },
  ): Promise<NotificationPreference>;
  registerPushDevice(
    user: RequestUser,
    input: {
      token: string;
      platform: string;
      deviceId?: string;
      appVersion?: string;
    },
  ): Promise<void>;
  unregisterPushDevice(user: RequestUser, token: string): Promise<void>;
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
  ): Promise<void>;
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
  ): Promise<void>;
}
