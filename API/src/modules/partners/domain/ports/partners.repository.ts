import { RequestUser } from "../../../../common/types/request-user";
import { PartnerSummary } from "../partner-summary";
export const PARTNERS_REPOSITORY = Symbol("PARTNERS_REPOSITORY");
export type PartnerResource =
  | "partner_subscription_plans"
  | "partner_plan_benefits"
  | "partner_subscriptions"
  | "partner_subscription_usage"
  | "partner_users"
  | "partner_documents"
  | "operating_sites"
  | "coverage_zones"
  | "partner_catalog_items"
  | "partner_requests"
  | "partner_request_items"
  | "diagnostic_orders";
export interface PartnersRepository {
  list(user: RequestUser): Promise<PartnerSummary[]>;
  resource(user: RequestUser, resource: PartnerResource): Promise<unknown[]>;
  createPlan(user: RequestUser, input: SubscriptionPlanInput): Promise<unknown>;
  updatePlan(
    user: RequestUser,
    id: string,
    input: SubscriptionPlanInput,
  ): Promise<unknown>;
  createSubscription(
    user: RequestUser,
    input: {
      partnerId: string;
      planId: string;
      payerUserId: string;
      autoRenew?: boolean;
    },
  ): Promise<unknown>;
  setPlanBenefit(
    user: RequestUser,
    planId: string,
    input: { benefitId: string; usageLimit?: number; period?: string },
  ): Promise<unknown>;
  removePlanBenefit(
    user: RequestUser,
    planId: string,
    benefitId: string,
  ): Promise<unknown>;
  cancelSubscription(
    user: RequestUser,
    id: string,
    reason: string,
  ): Promise<unknown>;
  renewSubscription(
    user: RequestUser,
    id: string,
    input: { payerUserId: string; autoRenew?: boolean },
  ): Promise<unknown>;
  recordUsage(
    user: RequestUser,
    id: string,
    input: {
      featureCode: string;
      quantity: number;
      periodStart?: string;
      periodEnd?: string;
    },
  ): Promise<unknown>;
  processSubscriptionLifecycle(user: RequestUser): Promise<unknown>;
  createPartner(
    user: RequestUser,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  updatePartner(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  addDocument(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  reviewDocument(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  assignUser(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  createRequest(
    user: RequestUser,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  confirmRequest(user: RequestUser, id: string): Promise<unknown>;
  respondRequest(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  createDiagnosticOrder(
    user: RequestUser,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  completeDiagnosticOrder(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
}
export type SubscriptionPlanInput = {
  code: string;
  name: string;
  description?: string;
  billingPeriod: string;
  price: number;
  currency?: string;
  features?: Record<string, unknown>;
  limits?: Record<string, unknown>;
  discountPercent?: number;
  isActive?: boolean;
};
