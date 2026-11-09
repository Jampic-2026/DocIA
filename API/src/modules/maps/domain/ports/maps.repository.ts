import { RequestUser } from "../../../../common/types/request-user";
export const MAPS_REPOSITORY = Symbol("MAPS_REPOSITORY");
export interface MapsRepository {
  logLocationPreview(
    user: RequestUser,
    latitude: number,
    longitude: number,
  ): Promise<void>;
}
