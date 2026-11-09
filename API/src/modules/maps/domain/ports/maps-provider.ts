export const MAPS_PROVIDER = Symbol("MAPS_PROVIDER");

export interface LocationPreview {
  address: string | null;
  imageBase64: string | null;
  imageMimeType: string | null;
}

export interface MapsProvider {
  locationPreview(
    latitude: number,
    longitude: number,
  ): Promise<LocationPreview>;
}
