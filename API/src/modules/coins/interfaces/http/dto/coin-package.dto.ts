import { Type } from "class-transformer";
import {
  IsBoolean,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
} from "class-validator";

export class PurchaseCoinPackageDto {
  @IsUUID() packageId!: string;
}

export class UpsertCoinPackageDto {
  @IsString() @MaxLength(80) code!: string;
  @IsString() @MaxLength(160) name!: string;
  @IsOptional() @IsString() description?: string;
  @Type(() => Number) @IsInt() @Min(1) coinAmount!: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) bonusCoinAmount?: number;
  @Type(() => Number) @IsNumber() @Min(0.01) price!: number;
  @IsOptional() @IsString() @MaxLength(3) currency?: string;
  @IsOptional() @IsString() @MaxLength(1000) qrImageUrl?: string;
  @IsOptional() @IsBoolean() isActive?: boolean;
}
