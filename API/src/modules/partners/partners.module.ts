import { Module } from "@nestjs/common";
import { PartnersService } from "./application/partners.service";
import { PartnersController } from "./interfaces/http/partners.controller";
import { PARTNERS_REPOSITORY } from "./domain/ports/partners.repository";
import { PostgresPartnersRepository } from "./infrastructure/persistence/postgres-partners.repository";

@Module({
  controllers: [PartnersController],
  providers: [
    PartnersService,
    { provide: PARTNERS_REPOSITORY, useClass: PostgresPartnersRepository },
  ],
  exports: [PartnersService],
})
export class PartnersModule {}
