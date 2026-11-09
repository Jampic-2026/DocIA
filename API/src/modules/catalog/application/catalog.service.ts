import { Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  CATALOG_REPOSITORY,
  CatalogRepository,
  PriceInput,
  ServiceInput,
} from "../domain/ports/catalog.repository";
@Injectable()
export class CatalogService {
  constructor(
    @Inject(CATALOG_REPOSITORY) private readonly repository: CatalogRepository,
  ) {}
  async list(user: RequestUser) {
    return { items: await this.repository.list(user) };
  }
  async prices(user: RequestUser) {
    const items = await this.repository.list(user);
    return { items: items.filter((item) => item.chargeMode != null) };
  }
  createPrice(user: RequestUser, input: PriceInput) {
    return this.repository.createPrice(user, input);
  }
  createService(user: RequestUser, input: ServiceInput) {
    return this.repository.createService(user, input);
  }
  updateService(user: RequestUser, id: string, input: ServiceInput) {
    return this.repository.updateService(user, id, input);
  }
  closePrice(user: RequestUser, id: string, validUntil: string) {
    return this.repository.closePrice(user, id, validUntil);
  }
  management(user: RequestUser) {
    return this.repository.management(user);
  }
}
