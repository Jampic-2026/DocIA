import { Module } from "@nestjs/common";
import { IncidentsService } from "./application/incidents.service";
import { IncidentsController } from "./interfaces/http/incidents.controller";
import { INCIDENTS_REPOSITORY } from "./domain/ports/incidents.repository";
import { PostgresIncidentsRepository } from "./infrastructure/persistence/postgres-incidents.repository";
import { NotificationsModule } from "../notifications/notifications.module";

@Module({
  imports: [NotificationsModule],
  controllers: [IncidentsController],
  providers: [
    IncidentsService,
    {
      provide: INCIDENTS_REPOSITORY,
      useClass: PostgresIncidentsRepository,
    },
  ],
  exports: [IncidentsService],
})
export class IncidentsModule {}
