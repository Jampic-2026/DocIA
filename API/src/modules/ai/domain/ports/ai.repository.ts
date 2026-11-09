import {
  SendAiMessageDto,
  EndVoiceSessionDto,
  StartVoiceSessionDto,
} from "../ai-inputs";
import { RequestUser } from "../../../../common/types/request-user";
import { MeetSpace } from "../../../integrations/domain/ports/meet-provider";

export const AI_REPOSITORY = Symbol("AI_REPOSITORY");
export interface AiRepository {
  prepareChatMessage(
    user: RequestUser,
    input: SendAiMessageDto,
    message: string,
    configurationValue1: string | undefined,
  ): Promise<{
    conversationId: string;
    patientId: string;
    charge: {
      transactionId: string;
      amount: number;
      balanceAfter: number;
      allocations: { id: string; amount: number }[];
      relatedEntityType: string;
      relatedEntityId: string;
    };
    history: { role: "user" | "assistant"; content: string }[];
  }>;
  refundChatCharge(
    user: RequestUser,
    prepared: {
      conversationId: string;
      patientId: string;
      charge: {
        transactionId: string;
        amount: number;
        balanceAfter: number;
        allocations: { id: string; amount: number }[];
        relatedEntityType: string;
        relatedEntityId: string;
      };
      history: { role: "user" | "assistant"; content: string }[];
    },
  ): Promise<void>;
  saveChatResponse(
    prepared: {
      conversationId: string;
      patientId: string;
      charge: {
        transactionId: string;
        amount: number;
        balanceAfter: number;
        allocations: { id: string; amount: number }[];
        relatedEntityType: string;
        relatedEntityId: string;
      };
      history: { role: "user" | "assistant"; content: string }[];
    },
    reply: string,
    user: RequestUser,
    urgent: boolean,
    safetyData?: Record<string, unknown>,
  ): Promise<void>;
  chatBalance(user: RequestUser): Promise<number>;
  prepareVoiceSession(
    user: RequestUser,
  ): Promise<{ patientId: string; maxBillableMinutes: number }>;
  createVoiceSession(
    user: RequestUser,
    prepared: { patientId: string; maxBillableMinutes: number },
    input: StartVoiceSessionDto,
    space: MeetSpace,
  ): Promise<any>;
  endVoiceSession(input: EndVoiceSessionDto, user: RequestUser): Promise<any>;
  listConversations(user: RequestUser): Promise<{ items: any[] }>;
  listMessages(
    conversationId: string,
    user: RequestUser,
  ): Promise<{ items: any[] }>;
  closeConversation(
    conversationId: string,
    user: RequestUser,
  ): Promise<{ closed: boolean }>;
  listRiskAssessments(user: RequestUser): Promise<{ items: any[] }>;
  maintainVoiceSessions(user: RequestUser): Promise<{ closed: number }>;
}
