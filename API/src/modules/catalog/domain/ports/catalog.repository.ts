import { RequestUser } from "../../../../common/types/request-user";
import { CatalogItem } from "../catalog-item";
export const CATALOG_REPOSITORY = Symbol("CATALOG_REPOSITORY");
export interface CatalogRepository {
  list(user: RequestUser): Promise<CatalogItem[]>;
  createPrice(user: RequestUser, input: PriceInput): Promise<unknown>;
  createService(user: RequestUser, input: ServiceInput): Promise<unknown>;
  updateService(
    user: RequestUser,
    id: string,
    input: ServiceInput,
  ): Promise<unknown>;
  closePrice(
    user: RequestUser,
    id: string,
    validUntil: string,
  ): Promise<unknown>;
  management(user: RequestUser): Promise<unknown>;
}
export type ServiceInput = {
  code: string;
  name: string;
  category: string;
  description?: string;
  isActive?: boolean;
};
export type PriceInput = {
  serviceId: string;
  chargeMode: "coins" | "fiat";
  coinPrice?: number;
  price?: number;
  currency?: string;
  validFrom?: string;
  validUntil?: string;
};
