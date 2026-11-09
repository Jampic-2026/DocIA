import { Type } from "class-transformer";
import {
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  ValidateIf,
} from "class-validator";

export class CreatePriceDto {
  @IsUUID() serviceId!: string;
  @IsIn(["coins", "fiat"]) chargeMode!: "coins" | "fiat";
  @ValidateIf((value: CreatePriceDto) => value.chargeMode === "coins")
  @Type(() => Number)
  @IsInt()
  @Min(0)
  coinPrice?: number;
  @ValidateIf((value: CreatePriceDto) => value.chargeMode === "fiat")
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  price?: number;
  @IsOptional() @IsString() @MaxLength(3) currency?: string;
  @IsOptional() @IsDateString() validFrom?: string;
  @IsOptional() @IsDateString() validUntil?: string;
}
