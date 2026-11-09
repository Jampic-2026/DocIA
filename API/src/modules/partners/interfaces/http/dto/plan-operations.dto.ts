import { Type } from "class-transformer";
import {
  IsBoolean,
  IsDateString,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
} from "class-validator";

export class SetPlanBenefitDto {
  @IsUUID() benefitId!: string;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) usageLimit?: number;
  @IsOptional() @IsString() @MaxLength(30) period?: string;
}
export class CancelSubscriptionDto {
  @IsString() @MaxLength(1000) reason!: string;
}
export class RenewSubscriptionDto {
  @IsUUID() payerUserId!: string;
  @IsOptional() @IsBoolean() autoRenew?: boolean;
}
export class RecordSubscriptionUsageDto {
  @IsString() @MaxLength(80) featureCode!: string;
  @Type(() => Number) @IsNumber() @Min(0.01) quantity!: number;
  @IsOptional() @IsDateString() periodStart?: string;
  @IsOptional() @IsDateString() periodEnd?: string;
}
