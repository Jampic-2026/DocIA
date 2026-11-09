import { Module } from "@nestjs/common";
import { BenefitsService } from "./application/benefits.service";
import { BenefitsController } from "./interfaces/http/benefits.controller";
import { BENEFITS_REPOSITORY } from "./domain/ports/benefits.repository";
import { PostgresBenefitsRepository } from "./infrastructure/persistence/postgres-benefits.repository";

@Module({
  controllers: [BenefitsController],
  providers: [
    BenefitsService,
    {
      provide: BENEFITS_REPOSITORY,
      useClass: PostgresBenefitsRepository,
    },
  ],
  exports: [BenefitsService],
})
export class BenefitsModule {}
