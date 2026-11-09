import { Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  ADMINISTRATION_REPOSITORY,
  AdministrationRepository,
} from "../domain/ports/administration.repository";

@Injectable()
export class AdministrationService {
  constructor(
    @Inject(ADMINISTRATION_REPOSITORY)
    private readonly repository: AdministrationRepository,
  ) {}

  settings(user: RequestUser) {
    return this.repository.settings(user);
  }
  updateSetting(
    user: RequestUser,
    key: string,
    input: Record<string, unknown>,
  ) {
    return this.repository.updateSetting(user, key, input);
  }
  roles(user: RequestUser) {
    return this.repository.roles(user);
  }
  permissions(user: RequestUser) {
    return this.repository.permissions(user);
  }
  createRole(user: RequestUser, input: Record<string, unknown>) {
    return this.repository.createRole(user, input);
  }
  updateRole(user: RequestUser, id: string, input: Record<string, unknown>) {
    return this.repository.updateRole(user, id, input);
  }
  assignPermissions(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ) {
    return this.repository.assignPermissions(user, id, input);
  }
  sites(user: RequestUser) {
    return this.repository.sites(user);
  }
  createSite(user: RequestUser, input: Record<string, unknown>) {
    return this.repository.createSite(user, input);
  }
  updateSite(user: RequestUser, id: string, input: Record<string, unknown>) {
    return this.repository.updateSite(user, id, input);
  }
  rules(user: RequestUser) {
    return this.repository.rules(user);
  }
  createRule(user: RequestUser, input: Record<string, unknown>) {
    return this.repository.createRule(user, input);
  }
  updateRule(user: RequestUser, id: string, input: Record<string, unknown>) {
    return this.repository.updateRule(user, id, input);
  }
  operationalReport(user: RequestUser) {
    return this.repository.operationalReport(user);
  }
}
