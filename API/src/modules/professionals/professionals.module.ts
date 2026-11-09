import { Module } from "@nestjs/common";
import { ProfessionalsService } from "./application/professionals.service";
import { ProfessionalsController } from "./interfaces/http/professionals.controller";
import { PROFESSIONALS_REPOSITORY } from "./domain/ports/professionals.repository";
import { PostgresProfessionalsRepository } from "./infrastructure/persistence/postgres-professionals.repository";

@Module({
  controllers: [ProfessionalsController],
  providers: [
    ProfessionalsService,
    {
      provide: PROFESSIONALS_REPOSITORY,
      useClass: PostgresProfessionalsRepository,
    },
  ],
  exports: [ProfessionalsService],
})
export class ProfessionalsModule {}
