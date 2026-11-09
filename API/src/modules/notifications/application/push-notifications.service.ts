import {
  Inject,
  Injectable,
  Logger,
  OnModuleInit,
  OnModuleDestroy,
} from "@nestjs/common";
import {
  PUSH_PROVIDER,
  PUSH_REPOSITORY,
  PushProvider,
  PushRepository,
  PushNotification,
} from "../domain/ports/push";
@Injectable()
export class PushNotificationsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PushNotificationsService.name);
  private outboxTimer?: NodeJS.Timeout;
  private processingOutbox = false;
  constructor(
    @Inject(PUSH_REPOSITORY) private readonly repository: PushRepository,
    @Inject(PUSH_PROVIDER) private readonly provider: PushProvider,
  ) {}
  get enabled() {
    return this.provider.enabled;
  }
  onModuleInit() {
    if (!this.enabled) return;
    void this.processOutbox();
    this.outboxTimer = setInterval(() => void this.processOutbox(), 5000);
    this.outboxTimer.unref();
  }
  onModuleDestroy() {
    if (this.outboxTimer) clearInterval(this.outboxTimer);
  }
  async sendToUser(userId: string, notification: PushNotification) {
    if (!this.enabled) return;
    const tokens = await this.repository.activeTokensForUser(
      userId,
      notification.eventCode,
    );
    for (let offset = 0; offset < tokens.length; offset += 500) {
      const result = await this.provider.send(
        tokens.slice(offset, offset + 500),
        notification,
      );
      if (result.invalidTokens.length)
        await this.repository.deactivateTokens(userId, result.invalidTokens);
      if (result.transientFailures)
        throw new Error("FCM transient delivery failure");
    }
  }
  async sendToPatient(patientId: string, notification: PushNotification) {
    if (!this.enabled) return;
    const userId = await this.repository.patientUserId(patientId);
    if (userId) await this.sendToUser(userId, notification);
  }
  private async processOutbox() {
    if (this.processingOutbox) return;
    this.processingOutbox = true;
    try {
      const notifications = await this.repository.claim();

      for (const notification of notifications) {
        try {
          await this.sendToUser(notification.userId, notification);
          await this.repository.complete(notification.notificationId);
        } catch (error) {
          const message =
            error instanceof Error ? error.message : "Error FCM desconocido";
          await this.repository.fail(notification.notificationId, message);
          this.logger.warn(
            `No se pudo procesar el push ${notification.notificationId}: ${message}`,
          );
        }
      }
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Error de cola desconocido";
      this.logger.error(`Error procesando la cola push: ${message}`);
    } finally {
      this.processingOutbox = false;
    }
  }
}
