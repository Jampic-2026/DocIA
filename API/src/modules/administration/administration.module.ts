import { Module } from "@nestjs/common";
import { AdministrationService } from "./application/administration.service";
import { AdministrationController } from "./interfaces/http/administration.controller";
import { ADMINISTRATION_REPOSITORY } from "./domain/ports/administration.repository";
import { PostgresAdministrationRepository } from "./infrastructure/persistence/postgres-administration.repository";

@Module({
  controllers: [AdministrationController],
  providers: [
    AdministrationService,
    {
      provide: ADMINISTRATION_REPOSITORY,
      useClass: PostgresAdministrationRepository,
    },
  ],
  exports: [AdministrationService],
})
export class AdministrationModule {}
