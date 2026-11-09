import { Module } from "@nestjs/common";
import { ConsentsService } from "./application/consents.service";
import { CONSENTS_REPOSITORY } from "./domain/ports/consents.repository";
import { PostgresConsentsRepository } from "./infrastructure/persistence/postgres-consents.repository";
import { ConsentsController } from "./interfaces/http/consents.controller";

@Module({
  controllers: [ConsentsController],
  providers: [
    ConsentsService,
    {
      provide: CONSENTS_REPOSITORY,
      useClass: PostgresConsentsRepository,
    },
  ],
  exports: [ConsentsService],
})
export class ConsentsModule {}
