import { Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  NOTIFICATIONS_REPOSITORY,
  NotificationsRepository,
} from "../domain/ports/notifications.repository";
import { UpdateNotificationPreferenceDto } from "../interfaces/http/dto/update-notification-preference.dto";
import { PushDeviceTokenDto } from "../interfaces/http/dto/push-device-token.dto";

@Injectable()
export class NotificationsService {
  constructor(
    @Inject(NOTIFICATIONS_REPOSITORY)
    private readonly repository: NotificationsRepository,
  ) {}

  async list(user: RequestUser) {
    return { items: await this.repository.list(user) };
  }

  markRead(user: RequestUser, id: string) {
    return this.repository.markRead(user, id).then(() => ({ updated: true }));
  }

  async markAllRead(user: RequestUser) {
    return { updated: await this.repository.markAllRead(user) };
  }

  async preferences(user: RequestUser) {
    return { items: await this.repository.listPreferences(user) };
  }

  updatePreference(user: RequestUser, input: UpdateNotificationPreferenceDto) {
    return this.repository.updatePreference(user, input);
  }

  async registerPushDevice(user: RequestUser, input: PushDeviceTokenDto) {
    await this.repository.registerPushDevice(user, input);
    return { registered: true };
  }

  async unregisterPushDevice(user: RequestUser, token: string) {
    await this.repository.unregisterPushDevice(user, token);
    return { unregistered: true };
  }

  async notifyUser(
    user: RequestUser,
    targetUserId: string,
    notification: {
      eventCode: string;
      title: string;
      body: string;
      relatedEntityType?: string;
      relatedEntityId?: string;
    },
  ) {
    await this.repository.createForUser(user, targetUserId, notification);
  }

  async notifyPatient(
    user: RequestUser,
    patientId: string,
    notification: {
      eventCode: string;
      title: string;
      body: string;
      relatedEntityType?: string;
      relatedEntityId?: string;
    },
  ) {
    await this.repository.createForPatient(user, patientId, notification);
  }
}
