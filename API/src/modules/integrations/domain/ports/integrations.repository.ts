import { RequestUser } from "../../../../common/types/request-user";
export const INTEGRATIONS_REPOSITORY = Symbol("INTEGRATIONS_REPOSITORY");
export interface IntegrationsRepository {
  logIntegrationAction(user: RequestUser, action: string): Promise<void>;
}
