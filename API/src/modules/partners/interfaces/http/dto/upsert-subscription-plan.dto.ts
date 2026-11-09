import { Type } from "class-transformer";
import {
  IsBoolean,
  IsIn,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from "class-validator";

export class UpsertSubscriptionPlanDto {
  @IsString() @MaxLength(80) code!: string;
  @IsString() @MaxLength(160) name!: string;
  @IsOptional() @IsString() description?: string;
  @IsIn(["monthly", "quarterly", "annual"]) billingPeriod!: string;
  @Type(() => Number) @IsNumber() @Min(0) price!: number;
  @IsOptional() @IsString() @MaxLength(3) currency?: string;
  @IsOptional() @IsObject() features?: Record<string, unknown>;
  @IsOptional() @IsObject() limits?: Record<string, unknown>;
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(100)
  discountPercent?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
}
