import { RequestUser } from "../../../../common/types/request-user";
export const USERS_REPOSITORY = Symbol("USERS_REPOSITORY");
export interface UsersRepository {
  overview(
    user: RequestUser,
  ): Promise<{ users: unknown[]; roles: unknown[]; permissions: unknown[] }>;
  updateStatus(
    user: RequestUser,
    id: string,
    status: string,
    reason?: string,
  ): Promise<void>;
  updateRoles(
    user: RequestUser,
    id: string,
    roleCodes: string[],
  ): Promise<void>;
}
