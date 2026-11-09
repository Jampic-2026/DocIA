import { Module } from "@nestjs/common";
import { ConsentsModule } from "../consents/consents.module";
import { MapsService } from "./application/maps.service";
import { MAPS_PROVIDER } from "./domain/ports/maps-provider";
import { MAPS_REPOSITORY } from "./domain/ports/maps.repository";
import { GoogleMapsProvider } from "./infrastructure/google/google-maps.provider";
import { PostgresMapsRepository } from "./infrastructure/persistence/postgres-maps.repository";
import { MapsController } from "./interfaces/http/maps.controller";

@Module({
  imports: [ConsentsModule],
  controllers: [MapsController],
  providers: [
    { provide: MAPS_REPOSITORY, useClass: PostgresMapsRepository },
    MapsService,
    GoogleMapsProvider,
    { provide: MAPS_PROVIDER, useExisting: GoogleMapsProvider },
  ],
})
export class MapsModule {}
