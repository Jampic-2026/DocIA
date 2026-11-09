import { Injectable, Inject as InjectRepository } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import { CoinsService } from "../../coins/application/coins.service";
import { MailService } from "../../mail/application/mail.service";
import { PartnersService } from "../../partners/application/partners.service";
import {
  OPERATIONS_REPOSITORY,
  OperationsRepository,
} from "../domain/ports/operations.repository";

@Injectable()
export class OperationsService {
  constructor(
    @InjectRepository(OPERATIONS_REPOSITORY)
    private readonly repository: OperationsRepository,
    private readonly coins: CoinsService,
    private readonly partners: PartnersService,
    private readonly mail: MailService,
  ) {}

  async processDailyMaintenance(user: RequestUser) {
    const coinMaintenance = await this.coins.processMaintenance(user);
    const partnerMaintenance =
      await this.partners.processSubscriptionLifecycle(user);
    const generalMaintenance = await this.repository.runMaintenance(user);
    const emailRetries = await this.retryEmailNotifications(user);
    return {
      coinMaintenance,
      partnerMaintenance,
      generalMaintenance,
      emailRetries,
    };
  }

  private async retryEmailNotifications(user: RequestUser) {
    const pending = await this.repository.listPendingEmails(user);
    let sent = 0;
    let failed = 0;
    for (const notification of pending) {
      try {
        await this.mail.sendNotification({
          to: notification.email,
          subject: notification.title,
          body: notification.body,
          idempotencyKey: `notification-${notification.id}`,
        });
        await this.updateEmailNotification(user, notification.id, "sent", null);
        sent += 1;
      } catch (error) {
        await this.updateEmailNotification(
          user,
          notification.id,
          "failed",
          error instanceof Error
            ? error.message.slice(0, 1000)
            : "Error de envío",
        );
        failed += 1;
      }
    }
    return { processed: pending.length, sent, failed };
  }

  private updateEmailNotification(
    user: RequestUser,
    id: string,
    status: "sent" | "failed",
    failureReason: string | null,
  ) {
    return this.repository.updateEmailNotification(
      user,
      id,
      status,
      failureReason,
    );
  }
}
