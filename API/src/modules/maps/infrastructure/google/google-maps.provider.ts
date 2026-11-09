import { Injectable, ServiceUnavailableException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import {
  LocationPreview,
  MapsProvider,
} from "../../domain/ports/maps-provider";

@Injectable()
export class GoogleMapsProvider implements MapsProvider {
  private readonly enabled: boolean;
  private readonly apiKey: string;
  private readonly timeoutMs: number;

  constructor(config: ConfigService) {
    this.enabled = config.get<boolean>("maps.enabled") ?? false;
    this.apiKey = config.get<string>("maps.google.serverApiKey") ?? "";
    this.timeoutMs = config.get<number>("externalHttpTimeoutMs", 15000);
  }

  async locationPreview(
    latitude: number,
    longitude: number,
  ): Promise<LocationPreview> {
    if (!this.enabled || !this.apiKey) {
      throw new ServiceUnavailableException("Google Maps no está configurado.");
    }
    const point = `${latitude.toFixed(7)},${longitude.toFixed(7)}`;
    const geocodeUrl = new URL(
      "https://maps.googleapis.com/maps/api/geocode/json",
    );
    geocodeUrl.search = new URLSearchParams({
      latlng: point,
      language: "es",
      region: "bo",
      key: this.apiKey,
    }).toString();
    const mapUrl = new URL("https://maps.googleapis.com/maps/api/staticmap");
    mapUrl.search = new URLSearchParams({
      center: point,
      zoom: "16",
      size: "640x320",
      scale: "2",
      maptype: "roadmap",
      markers: `color:red|${point}`,
      key: this.apiKey,
    }).toString();

    const [geocodeResult, mapResult] = await Promise.allSettled([
      fetch(geocodeUrl, { signal: AbortSignal.timeout(this.timeoutMs) }),
      fetch(mapUrl, { signal: AbortSignal.timeout(this.timeoutMs) }),
    ]);

    let address: string | null = null;
    if (geocodeResult.status === "fulfilled") {
      const response = geocodeResult.value;
      const geocode = (await response.json().catch(() => null)) as {
        status?: string;
        results?: Array<{ formatted_address?: string }>;
      } | null;
      if (
        response.ok &&
        ["OK", "ZERO_RESULTS"].includes(geocode?.status ?? "")
      ) {
        address = geocode?.results?.[0]?.formatted_address ?? null;
      }
    }

    let imageBase64: string | null = null;
    let imageMimeType: string | null = null;
    if (mapResult.status === "fulfilled") {
      const response = mapResult.value;
      const contentType = response.headers.get("content-type") ?? "";
      if (response.ok && contentType.startsWith("image/")) {
        const image = Buffer.from(await response.arrayBuffer());
        imageBase64 = image.toString("base64");
        imageMimeType = contentType.split(";")[0];
      }
    }

    return {
      address: address ?? `Ubicación GPS: ${point}`,
      imageBase64,
      imageMimeType,
    };
  }
}
