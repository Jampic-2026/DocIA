import { RequestUser } from "../../../../common/types/request-user";

export const ADMINISTRATION_REPOSITORY = Symbol("ADMINISTRATION_REPOSITORY");

export interface AdministrationRepository {
  settings(user: RequestUser): Promise<unknown>;
  updateSetting(
    user: RequestUser,
    key: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  roles(user: RequestUser): Promise<unknown>;
  permissions(user: RequestUser): Promise<unknown>;
  createRole(
    user: RequestUser,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  updateRole(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  assignPermissions(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  sites(user: RequestUser): Promise<unknown>;
  createSite(
    user: RequestUser,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  updateSite(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  rules(user: RequestUser): Promise<unknown>;
  createRule(
    user: RequestUser,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  updateRule(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  operationalReport(user: RequestUser): Promise<unknown>;
}
