import { Module } from "@nestjs/common";
import { HumanResourcesService } from "./application/human-resources.service";
import { HumanResourcesController } from "./interfaces/http/human-resources.controller";
import { HUMAN_RESOURCES_REPOSITORY } from "./domain/ports/human-resources.repository";
import { PostgresHumanResourcesRepository } from "./infrastructure/persistence/postgres-human-resources.repository";

@Module({
  controllers: [HumanResourcesController],
  providers: [
    HumanResourcesService,
    {
      provide: HUMAN_RESOURCES_REPOSITORY,
      useClass: PostgresHumanResourcesRepository,
    },
  ],
  exports: [HumanResourcesService],
})
export class HumanResourcesModule {}
