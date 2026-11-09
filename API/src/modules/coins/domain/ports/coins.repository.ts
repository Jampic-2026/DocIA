import { RequestUser } from "../../../../common/types/request-user";
import { CoinOverview } from "../coin-overview";
export const COINS_REPOSITORY = Symbol("COINS_REPOSITORY");
export type CoinResource =
  "coin-purchases" | "coin-lots" | "coin-transaction-allocations";
export interface CoinsRepository {
  overview(user: RequestUser): Promise<CoinOverview>;
  resource(user: RequestUser, resource: CoinResource): Promise<unknown[]>;
  purchase(user: RequestUser, packageId: string): Promise<unknown>;
  createPackage(user: RequestUser, input: CoinPackageInput): Promise<unknown>;
  updatePackage(
    user: RequestUser,
    id: string,
    input: CoinPackageInput,
  ): Promise<unknown>;
  deletePackage(user: RequestUser, id: string): Promise<unknown>;
  processMaintenance(user: RequestUser): Promise<unknown>;
}
export type CoinPackageInput = {
  code: string;
  name: string;
  description?: string;
  coinAmount: number;
  bonusCoinAmount?: number;
  price: number;
  currency?: string;
  qrImageUrl?: string;
  isActive?: boolean;
};
