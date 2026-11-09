import { PUSH_REPOSITORY, PUSH_PROVIDER } from "./domain/ports/push";
import { PostgresPushRepository } from "./infrastructure/persistence/postgres-push.repository";
import { FirebasePushProvider } from "./infrastructure/push/firebase-push.provider";
import { Module } from "@nestjs/common";
import { NotificationsService } from "./application/notifications.service";
import { PushNotificationsService } from "./application/push-notifications.service";
import { NotificationsController } from "./interfaces/http/notifications.controller";
import { NOTIFICATIONS_REPOSITORY } from "./domain/ports/notifications.repository";
import { PostgresNotificationsRepository } from "./infrastructure/persistence/postgres-notifications.repository";

@Module({
  controllers: [NotificationsController],
  providers: [
    { provide: PUSH_REPOSITORY, useClass: PostgresPushRepository },
    { provide: PUSH_PROVIDER, useClass: FirebasePushProvider },
    NotificationsService,
    PushNotificationsService,
    {
      provide: NOTIFICATIONS_REPOSITORY,
      useClass: PostgresNotificationsRepository,
    },
  ],
  exports: [NotificationsService, PushNotificationsService],
})
export class NotificationsModule {}
