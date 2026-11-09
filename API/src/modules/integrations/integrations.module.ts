import { Module } from "@nestjs/common";
import { IntegrationsService } from "./application/integrations.service";
import { INTEGRATIONS_REPOSITORY } from "./domain/ports/integrations.repository";
import { MEET_PROVIDER } from "./domain/ports/meet-provider";
import { GoogleMeetProvider } from "./infrastructure/google/google-meet.provider";
import { PostgresIntegrationsRepository } from "./infrastructure/persistence/postgres-integrations.repository";
import { IntegrationsController } from "./interfaces/http/integrations.controller";

@Module({
  controllers: [IntegrationsController],
  providers: [
    {
      provide: INTEGRATIONS_REPOSITORY,
      useClass: PostgresIntegrationsRepository,
    },
    IntegrationsService,
    GoogleMeetProvider,
    { provide: MEET_PROVIDER, useExisting: GoogleMeetProvider },
  ],
  exports: [MEET_PROVIDER],
})
export class IntegrationsModule {}
