import { Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  PARTNERS_REPOSITORY,
  PartnerResource,
  PartnersRepository,
  SubscriptionPlanInput,
} from "../domain/ports/partners.repository";
@Injectable()
export class PartnersService {
  constructor(
    @Inject(PARTNERS_REPOSITORY)
    private readonly repository: PartnersRepository,
  ) {}
  async list(user: RequestUser) {
    return { items: await this.repository.list(user) };
  }
  async resource(user: RequestUser, resource: PartnerResource) {
    return { items: await this.repository.resource(user, resource) };
  }
  createPlan(user: RequestUser, input: SubscriptionPlanInput) {
    return this.repository.createPlan(user, input);
  }
  updatePlan(user: RequestUser, id: string, input: SubscriptionPlanInput) {
    return this.repository.updatePlan(user, id, input);
  }
  createSubscription(
    user: RequestUser,
    input: {
      partnerId: string;
      planId: string;
      payerUserId: string;
      autoRenew?: boolean;
    },
  ) {
    return this.repository.createSubscription(user, input);
  }
  setPlanBenefit(
    user: RequestUser,
    planId: string,
    input: { benefitId: string; usageLimit?: number; period?: string },
  ) {
    return this.repository.setPlanBenefit(user, planId, input);
  }
  removePlanBenefit(user: RequestUser, planId: string, benefitId: string) {
    return this.repository.removePlanBenefit(user, planId, benefitId);
  }
  cancelSubscription(user: RequestUser, id: string, reason: string) {
    return this.repository.cancelSubscription(user, id, reason);
  }
  renewSubscription(
    user: RequestUser,
    id: string,
    input: { payerUserId: string; autoRenew?: boolean },
  ) {
    return this.repository.renewSubscription(user, id, input);
  }
  recordUsage(
    user: RequestUser,
    id: string,
    input: {
      featureCode: string;
      quantity: number;
      periodStart?: string;
      periodEnd?: string;
    },
  ) {
    return this.repository.recordUsage(user, id, input);
  }
  processSubscriptionLifecycle(user: RequestUser) {
    return this.repository.processSubscriptionLifecycle(user);
  }
  createPartner(user: RequestUser, input: Record<string, unknown>) {
    return this.repository.createPartner(user, input);
  }
  updatePartner(user: RequestUser, id: string, input: Record<string, unknown>) {
    return this.repository.updatePartner(user, id, input);
  }
  addDocument(user: RequestUser, id: string, input: Record<string, unknown>) {
    return this.repository.addDocument(user, id, input);
  }
  reviewDocument(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ) {
    return this.repository.reviewDocument(user, id, input);
  }
  assignUser(user: RequestUser, id: string, input: Record<string, unknown>) {
    return this.repository.assignUser(user, id, input);
  }
  createRequest(user: RequestUser, input: Record<string, unknown>) {
    return this.repository.createRequest(user, input);
  }
  confirmRequest(user: RequestUser, id: string) {
    return this.repository.confirmRequest(user, id);
  }
  respondRequest(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ) {
    return this.repository.respondRequest(user, id, input);
  }
  createDiagnosticOrder(user: RequestUser, input: Record<string, unknown>) {
    return this.repository.createDiagnosticOrder(user, input);
  }
  completeDiagnosticOrder(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ) {
    return this.repository.completeDiagnosticOrder(user, id, input);
  }
}
