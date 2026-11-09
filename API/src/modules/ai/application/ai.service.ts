import {
  BadRequestException,
  Inject,
  Injectable,
  Inject as InjectRepository,
  GoneException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { RequestUser } from "../../../common/types/request-user";
import { ConsentsService } from "../../consents/application/consents.service";
import { GuidanceService } from "../../guidance/application/guidance.service";
import { RiskEvaluation } from "../../guidance/domain/risk-policy";
import { CHAT_MESSAGE_COST } from "../domain/ai-persistence-types";
import { AI_PROVIDER, AiProvider } from "../domain/ports/ai-provider";
import { AI_REPOSITORY, AiRepository } from "../domain/ports/ai.repository";
import { SendAiMessageDto } from "../interfaces/http/dto/send-ai-message.dto";
import {
  EndVoiceSessionDto,
  StartVoiceSessionDto,
} from "../interfaces/http/dto/voice-session.dto";

@Injectable()
export class AiService {
  constructor(
    @InjectRepository(AI_REPOSITORY) private readonly repository: AiRepository,
    private readonly config: ConfigService,
    private readonly consents: ConsentsService,
    @Inject(AI_PROVIDER) private readonly provider: AiProvider,
    private readonly guidance: GuidanceService,
  ) {}

  async send(user: RequestUser, input: SendAiMessageDto) {
    await this.consents.assertAccepted(user, "ai_orientation");
    const message = input.message.trim();
    if (message.length > 1000) {
      throw new BadRequestException(
        "El mensaje no puede superar 1000 caracteres.",
      );
    }
    const prepared = await this.repository.prepareChatMessage(
      user,
      input,
      message,
      this.config.get<string>("ai.openAi.model"),
    );

    const urgent = this.detectUrgency(message);
    let reply: string;
    let safetyData: RiskEvaluation & { assessmentId: string };
    try {
      const { evaluation, revision, contextUsed } =
        await this.guidance.evaluate(
          user,
          prepared.patientId,
          prepared.history
            .filter((item) => item.role === "user")
            .map((item) => item.content)
            .join("\n"),
          input.useClinicalContext === true,
        );
      if (urgent)
        Object.assign(evaluation, {
          riskLevel: "red",
          recommendedAction: "emergency",
          classificationStatus: "preventive_alert",
          questions: [],
        });
      const immediate = urgent || evaluation.recommendedAction === "emergency";
      reply = immediate
        ? "Lo que describes puede requerir atención inmediata. Llama al servicio de emergencias disponible en tu zona o acude al centro de salud más cercano. Si puedes, solicita ayuda a una persona de confianza. No esperes una respuesta del asistente para buscar atención."
        : evaluation.questions.length
          ? "Para continuar la orientación se necesita información adicional:\n" +
            evaluation.questions.join("\n")
          : await this.provider.reply(prepared.history);
      const assessmentId = await this.guidance.saveAssessment(
        user,
        prepared.conversationId,
        evaluation,
        contextUsed,
        revision,
      );
      safetyData = { ...evaluation, assessmentId };
      await this.repository.saveChatResponse(
        prepared,
        reply,
        user,
        immediate,
        safetyData,
      );
    } catch (error) {
      await this.repository.refundChatCharge(user, prepared);
      throw error;
    }

    return {
      conversationId: prepared.conversationId,
      message: reply,
      ...safetyData,
      coinCost: CHAT_MESSAGE_COST,
      balance: await this.repository.chatBalance(user),
    };
  }

  async startVoiceSession(user: RequestUser, input: StartVoiceSessionDto) {
    await this.consents.assertAccepted(user, "ai_orientation");
    void input;
    throw new GoneException(
      "Solicita orientación humana desde guidance/support-calls. No se crean nuevas sesiones de voz IA sin interlocutor.",
    );
  }

  async endVoiceSession(user: RequestUser, input: EndVoiceSessionDto) {
    return this.repository.endVoiceSession(input, user);
  }

  async conversations(user: RequestUser) {
    return this.repository.listConversations(user);
  }

  async messages(user: RequestUser, conversationId: string) {
    return this.repository.listMessages(conversationId, user);
  }

  async close(user: RequestUser, conversationId: string) {
    return this.repository.closeConversation(conversationId, user);
  }

  async riskAssessments(user: RequestUser) {
    return this.repository.listRiskAssessments(user);
  }

  async processVoiceSessionMaintenance(user: RequestUser) {
    return this.repository.maintainVoiceSessions(user);
  }

  private detectUrgency(message: string) {
    const normalized = message.toLocaleLowerCase("es");
    return [
      /no puedo respirar|dificultad (grave )?para respirar|me falta el aire/,
      /dolor (fuerte|intenso) (en el )?pecho/,
      /perd[ií] el conocimiento|est[aá] inconsciente/,
      /convulsi[oó]n|convulsionando/,
      /sangrado (fuerte|abundante|incontrolable)/,
      /quiero (morir|matarme)|suicid/,
    ].some((pattern) => pattern.test(normalized));
  }
}
