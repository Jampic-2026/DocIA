import { Module } from "@nestjs/common";
import { DeliveriesService } from "./application/deliveries.service";
import { DeliveriesController } from "./interfaces/http/deliveries.controller";
import { DELIVERIES_REPOSITORY } from "./domain/ports/deliveries.repository";
import { PostgresDeliveriesRepository } from "./infrastructure/persistence/postgres-deliveries.repository";

@Module({
  controllers: [DeliveriesController],
  providers: [
    DeliveriesService,
    { provide: DELIVERIES_REPOSITORY, useClass: PostgresDeliveriesRepository },
  ],
  exports: [DeliveriesService],
})
export class DeliveriesModule {}
