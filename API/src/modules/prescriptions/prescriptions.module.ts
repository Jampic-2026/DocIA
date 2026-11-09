import { Module } from "@nestjs/common";
import { PrescriptionsService } from "./application/prescriptions.service";
import { PrescriptionsController } from "./interfaces/http/prescriptions.controller";
import { PRESCRIPTIONS_REPOSITORY } from "./domain/ports/prescriptions.repository";
import { PostgresPrescriptionsRepository } from "./infrastructure/persistence/postgres-prescriptions.repository";
import { NotificationsModule } from "../notifications/notifications.module";

@Module({
  imports: [NotificationsModule],
  controllers: [PrescriptionsController],
  providers: [
    PrescriptionsService,
    {
      provide: PRESCRIPTIONS_REPOSITORY,
      useClass: PostgresPrescriptionsRepository,
    },
  ],
  exports: [PrescriptionsService],
})
export class PrescriptionsModule {}
