import { Inject, Injectable, Inject as InjectRepository } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import { MAPS_PROVIDER, MapsProvider } from "../domain/ports/maps-provider";
import {
  MAPS_REPOSITORY,
  MapsRepository,
} from "../domain/ports/maps.repository";

@Injectable()
export class MapsService {
  constructor(
    @Inject(MAPS_PROVIDER) private readonly provider: MapsProvider,
    @InjectRepository(MAPS_REPOSITORY)
    private readonly repository: MapsRepository,
  ) {}

  async locationPreview(
    user: RequestUser,
    latitude: number,
    longitude: number,
  ) {
    const result = await this.provider.locationPreview(latitude, longitude);
    await this.repository.logLocationPreview(user, latitude, longitude);
    return result;
  }
}
