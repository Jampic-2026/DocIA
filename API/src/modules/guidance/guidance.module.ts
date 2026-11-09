import { Module } from "@nestjs/common";
import { ConsentsModule } from "../consents/consents.module";
import { IntegrationsModule } from "../integrations/integrations.module";
import { GuidanceService } from "./application/guidance.service";
import { GUIDANCE_REPOSITORY } from "./domain/guidance.repository";
import { PostgresGuidanceRepository } from "./infrastructure/postgres-guidance.repository";
import { GuidanceController } from "./interfaces/guidance.controller";
@Module({
  imports: [ConsentsModule, IntegrationsModule],
  controllers: [GuidanceController],
  providers: [
    GuidanceService,
    { provide: GUIDANCE_REPOSITORY, useClass: PostgresGuidanceRepository },
  ],
  exports: [GuidanceService],
})
export class GuidanceModule {}
