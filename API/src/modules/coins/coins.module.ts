import { Module } from "@nestjs/common";
import { CoinsService } from "./application/coins.service";
import { CoinsController } from "./interfaces/http/coins.controller";
import { COINS_REPOSITORY } from "./domain/ports/coins.repository";
import { PostgresCoinsRepository } from "./infrastructure/persistence/postgres-coins.repository";

@Module({
  controllers: [CoinsController],
  providers: [
    CoinsService,
    { provide: COINS_REPOSITORY, useClass: PostgresCoinsRepository },
  ],
  exports: [CoinsService],
})
export class CoinsModule {}
