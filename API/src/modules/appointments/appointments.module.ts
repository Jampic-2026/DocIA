import { Module } from "@nestjs/common";
import { ConsentsModule } from "../consents/consents.module";
import { IntegrationsModule } from "../integrations/integrations.module";
import { NotificationsModule } from "../notifications/notifications.module";
import { AppointmentsService } from "./application/appointments.service";
import { TelemedicineService } from "./application/telemedicine.service";
import { APPOINTMENTS_REPOSITORY } from "./domain/ports/appointments.repository";
import { TELEMEDICINE_REPOSITORY } from "./domain/ports/telemedicine.repository";
import { PostgresAppointmentsRepository } from "./infrastructure/persistence/postgres-appointments.repository";
import { PostgresTelemedicineRepository } from "./infrastructure/persistence/postgres-telemedicine.repository";
import { AppointmentsController } from "./interfaces/http/appointments.controller";

@Module({
  imports: [IntegrationsModule, ConsentsModule, NotificationsModule],
  controllers: [AppointmentsController],
  providers: [
    {
      provide: TELEMEDICINE_REPOSITORY,
      useClass: PostgresTelemedicineRepository,
    },
    AppointmentsService,
    TelemedicineService,
    {
      provide: APPOINTMENTS_REPOSITORY,
      useClass: PostgresAppointmentsRepository,
    },
  ],
  exports: [AppointmentsService],
})
export class AppointmentsModule {}
