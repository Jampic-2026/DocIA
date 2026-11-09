import { Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  COINS_REPOSITORY,
  CoinResource,
  CoinsRepository,
} from "../domain/ports/coins.repository";
import { UpsertCoinPackageDto } from "../interfaces/http/dto/coin-package.dto";
@Injectable()
export class CoinsService {
  constructor(
    @Inject(COINS_REPOSITORY) private readonly repository: CoinsRepository,
  ) {}
  async overview(user: RequestUser) {
    const value = await this.repository.overview(user);
    return {
      ...value,
      transactions: value.transactions.map((t) => ({
        ...t,
        createdAt: t.createdAt.toISOString(),
      })),
    };
  }
  async resource(user: RequestUser, resource: CoinResource) {
    return { items: await this.repository.resource(user, resource) };
  }
  purchase(user: RequestUser, packageId: string) {
    return this.repository.purchase(user, packageId);
  }
  createPackage(user: RequestUser, input: UpsertCoinPackageDto) {
    return this.repository.createPackage(user, input);
  }
  updatePackage(user: RequestUser, id: string, input: UpsertCoinPackageDto) {
    return this.repository.updatePackage(user, id, input);
  }
  deletePackage(user: RequestUser, id: string) {
    return this.repository.deletePackage(user, id);
  }
  processMaintenance(user: RequestUser) {
    return this.repository.processMaintenance(user);
  }
}
