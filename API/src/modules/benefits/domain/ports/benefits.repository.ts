import { RequestUser } from "../../../../common/types/request-user";
import { Benefit, BenefitUsage } from "../benefit";

export const BENEFITS_REPOSITORY = Symbol("BENEFITS_REPOSITORY");

export interface BenefitsRepository {
  list(user: RequestUser): Promise<Benefit[]>;
  listUsages(user: RequestUser): Promise<BenefitUsage[]>;
  create(user: RequestUser, input: Record<string, unknown>): Promise<unknown>;
  update(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  apply(user: RequestUser, input: Record<string, unknown>): Promise<unknown>;
  validations(user: RequestUser): Promise<unknown[]>;
  validate(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  setPartner(
    user: RequestUser,
    benefitId: string,
    partnerId: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
  reverse(
    user: RequestUser,
    id: string,
    input: Record<string, unknown>,
  ): Promise<unknown>;
}
