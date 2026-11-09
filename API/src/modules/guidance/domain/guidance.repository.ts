import { RequestUser } from "../../../common/types/request-user";
import { RiskEvaluation, RiskPolicy } from "./risk-policy";
import { MeetProvider } from "../../integrations/domain/ports/meet-provider";
export const GUIDANCE_REPOSITORY = Symbol("GUIDANCE_REPOSITORY");
export interface GuidanceRepository {
  policy(user: RequestUser): Promise<{
    policy: RiskPolicy;
    enabled: boolean;
    revision: number;
    reviewedBy: string | null;
  }>;
  savePolicy(user: RequestUser, policy: RiskPolicy): Promise<unknown>;
  approvePolicy(
    user: RequestUser,
    revision: number,
    reference: string,
  ): Promise<unknown>;
  context(user: RequestUser, patientId: string): Promise<string>;
  saveAssessment(
    user: RequestUser,
    conversationId: string,
    evaluation: RiskEvaluation,
    contextUsed: boolean,
    revision: number,
  ): Promise<string>;
  decision(
    user: RequestUser,
    id: string,
    decision: string,
    relatedId?: string,
  ): Promise<unknown>;
  calls(user: RequestUser): Promise<{ items: Record<string, unknown>[] }>;
  requestCall(
    user: RequestUser,
    reason: string,
    assessmentId?: string,
    emergencyId?: string,
  ): Promise<unknown>;
  staff(user: RequestUser): Promise<{ items: Record<string, unknown>[] }>;
  transitionCall(
    user: RequestUser,
    id: string,
    action: string,
    professionalId: string | undefined,
    notes: string | undefined,
    meet: MeetProvider,
  ): Promise<unknown>;
  joinCall(
    user: RequestUser,
    id: string,
    meet: MeetProvider,
  ): Promise<{ meetingUrl: string }>;
}
