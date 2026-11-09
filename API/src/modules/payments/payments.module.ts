import { Module } from "@nestjs/common";
import { PaymentsService } from "./application/payments.service";
import { PaymentsController } from "./interfaces/http/payments.controller";
import { PAYMENTS_REPOSITORY } from "./domain/ports/payments.repository";
import { PostgresPaymentsRepository } from "./infrastructure/persistence/postgres-payments.repository";
import { StripePaymentsProvider } from "./infrastructure/stripe/stripe-payments.provider";

import { NotificationsModule } from "../notifications/notifications.module";

@Module({
  imports: [NotificationsModule],
  controllers: [PaymentsController],
  providers: [
    PaymentsService,
    {
      provide: PAYMENTS_REPOSITORY,
      useClass: PostgresPaymentsRepository,
    },
    StripePaymentsProvider,
  ],
  exports: [PaymentsService],
})
export class PaymentsModule {}
