import { Module } from "@nestjs/common";
import { GuidanceModule } from "../guidance/guidance.module";
import { ConsentsModule } from "../consents/consents.module";
import { IntegrationsModule } from "../integrations/integrations.module";
import { AiService } from "./application/ai.service";
import { AI_PROVIDER } from "./domain/ports/ai-provider";
import { AI_REPOSITORY } from "./domain/ports/ai.repository";
import { OpenAiProvider } from "./infrastructure/openai/openai-ai.provider";
import { PostgresAiRepository } from "./infrastructure/persistence/postgres-ai.repository";
import { AiController } from "./interfaces/http/ai.controller";

@Module({
  imports: [ConsentsModule, IntegrationsModule, GuidanceModule],
  controllers: [AiController],
  providers: [
    { provide: AI_REPOSITORY, useClass: PostgresAiRepository },
    AiService,
    OpenAiProvider,
    { provide: AI_PROVIDER, useExisting: OpenAiProvider },
  ],
  exports: [AiService],
})
export class AiModule {}
