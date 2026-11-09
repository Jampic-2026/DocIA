import { Module } from "@nestjs/common";
import { ClinicalRecordsService } from "./application/clinical-records.service";
import { ClinicalRecordsController } from "./interfaces/http/clinical-records.controller";
import { CLINICAL_RECORDS_REPOSITORY } from "./domain/ports/clinical-records.repository";
import { PostgresClinicalRecordsRepository } from "./infrastructure/persistence/postgres-clinical-records.repository";
import { NotificationsModule } from "../notifications/notifications.module";

@Module({
  imports: [NotificationsModule],
  controllers: [ClinicalRecordsController],
  providers: [
    ClinicalRecordsService,
    {
      provide: CLINICAL_RECORDS_REPOSITORY,
      useClass: PostgresClinicalRecordsRepository,
    },
  ],
  exports: [ClinicalRecordsService],
})
export class ClinicalRecordsModule {}
