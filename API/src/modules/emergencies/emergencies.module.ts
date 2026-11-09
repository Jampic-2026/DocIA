import { Module } from "@nestjs/common";
import { ConsentsModule } from "../consents/consents.module";
import { NotificationsModule } from "../notifications/notifications.module";
import { EmergenciesService } from "./application/emergencies.service";
import { EmergenciesController } from "./interfaces/http/emergencies.controller";
import { EMERGENCIES_REPOSITORY } from "./domain/ports/emergencies.repository";
import { PostgresEmergenciesRepository } from "./infrastructure/persistence/postgres-emergencies.repository";

@Module({
  imports: [ConsentsModule, NotificationsModule],
  controllers: [EmergenciesController],
  providers: [
    EmergenciesService,
    {
      provide: EMERGENCIES_REPOSITORY,
      useClass: PostgresEmergenciesRepository,
    },
  ],
  exports: [EmergenciesService],
})
export class EmergenciesModule {}
