import { Module } from "@nestjs/common";
import { HomeServicesService } from "./application/home-services.service";
import { HomeServicesController } from "./interfaces/http/home-services.controller";
import { HOME_SERVICES_REPOSITORY } from "./domain/ports/home-services.repository";
import { PostgresHomeServicesRepository } from "./infrastructure/persistence/postgres-home-services.repository";

@Module({
  controllers: [HomeServicesController],
  providers: [
    HomeServicesService,
    {
      provide: HOME_SERVICES_REPOSITORY,
      useClass: PostgresHomeServicesRepository,
    },
  ],
  exports: [HomeServicesService],
})
export class HomeServicesModule {}
