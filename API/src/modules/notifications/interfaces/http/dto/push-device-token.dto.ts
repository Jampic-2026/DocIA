import { IsIn, IsOptional, IsString, MaxLength } from "class-validator";

export class PushDeviceTokenDto {
  @IsString()
  @MaxLength(4096)
  token!: string;

  @IsIn(["android", "ios", "web", "unknown"])
  platform!: "android" | "ios" | "web" | "unknown";

  @IsOptional()
  @IsString()
  @MaxLength(160)
  deviceId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  appVersion?: string;
}

export class UnregisterPushDeviceDto {
  @IsString()
  @MaxLength(4096)
  token!: string;
}
