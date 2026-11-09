import { Module } from "@nestjs/common";
import { CoinsModule } from "../coins/coins.module";
import { MailModule } from "../mail/mail.module";
import { PartnersModule } from "../partners/partners.module";
import { OperationsService } from "./application/operations.service";
import { OPERATIONS_REPOSITORY } from "./domain/ports/operations.repository";
import { PostgresOperationsRepository } from "./infrastructure/persistence/postgres-operations.repository";
import { OperationsController } from "./interfaces/http/operations.controller";

@Module({
  imports: [CoinsModule, PartnersModule, MailModule],
  controllers: [OperationsController],
  providers: [
    { provide: OPERATIONS_REPOSITORY, useClass: PostgresOperationsRepository },
    OperationsService,
  ],
})
export class OperationsModule {}
