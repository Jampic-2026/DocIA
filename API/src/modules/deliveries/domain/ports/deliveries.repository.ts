import { RequestUser } from "../../../../common/types/request-user";
export const DELIVERIES_REPOSITORY = Symbol("DELIVERIES_REPOSITORY");
export interface DeliveriesRepository {
  list(user: RequestUser): Promise<unknown[]>;
  create(
    user: RequestUser,
    input: {
      partnerRequestId: string;
      deliveryAddressId: string;
      recipientUserId?: string;
      deliveryFee?: number;
    },
  ): Promise<unknown>;
  assign(
    user: RequestUser,
    id: string,
    professionalId: string,
  ): Promise<unknown>;
  updateStatus(
    user: RequestUser,
    id: string,
    status: string,
    reason?: string,
  ): Promise<unknown>;
  history(user: RequestUser, id?: string): Promise<unknown[]>;
  evidence(user: RequestUser, id?: string): Promise<unknown[]>;
  addEvidence(
    user: RequestUser,
    id: string,
    input: {
      evidenceType: string;
      fileUrl: string;
      recipientDocumentVerified?: boolean;
      notes?: string;
    },
  ): Promise<unknown>;
}
