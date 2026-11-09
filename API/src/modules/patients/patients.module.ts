import { Module } from "@nestjs/common";
import { PatientsService } from "./application/patients.service";
import { PatientsController } from "./interfaces/http/patients.controller";
import { PATIENTS_REPOSITORY } from "./domain/ports/patients.repository";
import { PostgresPatientsRepository } from "./infrastructure/persistence/postgres-patients.repository";

@Module({
  controllers: [PatientsController],
  providers: [
    PatientsService,
    {
      provide: PATIENTS_REPOSITORY,
      useClass: PostgresPatientsRepository,
    },
  ],
  exports: [PatientsService],
})
export class PatientsModule {}
