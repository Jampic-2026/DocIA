import { Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  BENEFITS_REPOSITORY,
  BenefitsRepository,
} from "../domain/ports/benefits.repository";

@Injectable()
export class BenefitsService {
  constructor(
    @Inject(BENEFITS_REPOSITORY)
    private readonly repository: BenefitsRepository,
  ) {}

  async list(user: RequestUser) {
    return { items: await this.repository.list(user) };
  }

  async usages(user: RequestUser) {
    return { items: await this.repository.listUsages(user) };
  }
  create(user: RequestUser, input: Record<string, unknown>) {
    return this.repository.create(user, input);
  }
  update(user: RequestUser, id: string, input: Record<string, unknown>) {
    return this.repository.update(user, id, input);
  }
  apply(user: RequestUser, input: Record<string, unknown>) {
    return this.repository.apply(user, input);
  }
  async validations(user: RequestUser) {
    return { items: await this.repository.validations(user) };
  }
  validate(user: RequestUser, id: string, input: Record<string, unknown>) {
    return this.repository.validate(user, id, input);
  }
  setPartner(
    user: RequestUser,
    benefitId: string,
    partnerId: string,
    input: Record<string, unknown>,
  ) {
    return this.repository.setPartner(user, benefitId, partnerId, input);
  }
  reverse(user: RequestUser, id: string, input: Record<string, unknown>) {
    return this.repository.reverse(user, id, input);
  }
}
