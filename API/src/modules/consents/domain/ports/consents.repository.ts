import { RequestUser } from "../../../../common/types/request-user";

export const CONSENTS_REPOSITORY = Symbol("CONSENTS_REPOSITORY");

export interface ConsentsRepository {
  listForUser(user: RequestUser): Promise<unknown[]>;
  isAccepted(user: RequestUser, code: string): Promise<boolean>;
  accept(
    user: RequestUser,
    code: string,
    metadata: { ipAddress?: string; userAgent?: string },
  ): Promise<unknown>;
  revoke(user: RequestUser, code: string): Promise<unknown>;
}
