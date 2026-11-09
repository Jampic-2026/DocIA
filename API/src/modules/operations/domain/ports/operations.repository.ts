import { RequestUser } from "../../../../common/types/request-user";
export const OPERATIONS_REPOSITORY = Symbol("OPERATIONS_REPOSITORY");
export interface OperationsRepository {
  runMaintenance(user: RequestUser): Promise<{
    expiredPrescriptions: number;
    expiredBenefits: number;
    revokedSessions: number;
    invalidatedPasswordTokens: number;
    invalidatedRegistrationTokens: number;
    invalidatedOauthStates: number;
    prescriptionNotices: number;
    appointmentNotices: number;
    followupNotices: number;
    retriedInAppNotifications: number;
  }>;
  listPendingEmails(
    user: RequestUser,
  ): Promise<{ id: string; email: string; title: string; body: string }[]>;
  updateEmailNotification(
    user: RequestUser,
    id: string,
    status: "sent" | "failed",
    failureReason: string | null,
  ): Promise<void>;
}
