import { RequestUser } from "../../../../common/types/request-user";
import { CreateEmergency, EmergencyCare } from "../emergency-policy";
export const EMERGENCIES_REPOSITORY = Symbol("EMERGENCIES_REPOSITORY");
export type EmergencyRecord = {
  id: string;
  status: string;
  riskLevel: string;
  openedAt: Date;
  [key: string]: unknown;
};
export type EmergencyResource =
  | "emergency-status-history"
  | "emergency-triage-answers"
  | "emergency-care-records"
  | "support-call-requests";
export interface EmergenciesRepository {
  list(user: RequestUser): Promise<{ items: EmergencyRecord[] }>;
  resource(
    user: RequestUser,
    resource: EmergencyResource,
  ): Promise<{ items: unknown[] }>;
  create(user: RequestUser, input: CreateEmergency): Promise<EmergencyRecord>;
  cancel(user: RequestUser, id: string): Promise<EmergencyRecord>;
  assign(
    user: RequestUser,
    id: string,
    input: { professionalId?: string; operatorId?: string },
  ): Promise<EmergencyRecord>;
  updateStatus(
    user: RequestUser,
    id: string,
    input: { status: string; notes?: string },
  ): Promise<EmergencyRecord>;
  decideAssignment(
    user: RequestUser,
    id: string,
    input: { decision: "accepted" | "rejected"; reason?: string },
  ): Promise<{ id: string; decision: string; status: string }>;
  recordCare(
    user: RequestUser,
    id: string,
    input: EmergencyCare,
  ): Promise<unknown>;
  careHistory(user: RequestUser, id: string): Promise<unknown[]>;
}
