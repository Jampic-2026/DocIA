import {
  BadGatewayException,
  Injectable,
  ServiceUnavailableException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import OpenAI from "openai";
import { AiProvider } from "../../domain/ports/ai-provider";

@Injectable()
export class OpenAiProvider implements AiProvider {
  private readonly client: OpenAI | null;
  private readonly model: string;

  constructor(config: ConfigService) {
    const apiKey = config.get<string>("ai.openAi.apiKey");
    this.model = config.get<string>("ai.openAi.model") ?? "";
    this.client = apiKey
      ? new OpenAI({
          apiKey,
          project: config.get<string>("ai.openAi.projectId"),
          organization: config.get<string>("ai.openAi.organizationId"),
          timeout: config.get<number>("externalHttpTimeoutMs", 15000),
          maxRetries: 2,
        })
      : null;
  }

  async reply(
    messages: Array<{ role: "user" | "assistant"; content: string }>,
  ) {
    if (!this.client || !this.model) {
      throw new ServiceUnavailableException(
        "El asistente de orientación no está configurado.",
      );
    }
    let response;
    try {
      response = await this.client.responses.create({
        model: this.model,
        instructions:
          "Eres el asistente de orientación preliminar de Doc IA para Bolivia. " +
          "Responde en español claro y neutral, sin diagnosticar ni recetar. " +
          "Haz como máximo dos preguntas útiles y recomienda atención profesional cuando corresponda. " +
          "No solicites datos identificativos. Aclara que no reemplazas una valoración médica.",
        input: messages.map((message) => ({
          role: message.role,
          content: message.content,
        })),
        max_output_tokens: 500,
      });
    } catch {
      throw new BadGatewayException(
        "El servicio de orientación no respondió correctamente.",
      );
    }
    const text = response.output_text.trim();
    if (!text) {
      throw new ServiceUnavailableException(
        "El asistente no pudo generar una respuesta.",
      );
    }
    return text;
  }
}
