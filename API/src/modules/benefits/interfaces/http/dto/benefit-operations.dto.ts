import {
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from "class-validator";

export class UpsertBenefitDto {
  [key: string]: unknown;
  @IsString() @Matches(/^[A-Z0-9][A-Z0-9_-]{1,79}$/) code!: string;
  @IsString() @MinLength(2) @MaxLength(180) name!: string;
  @IsOptional() @IsString() @MaxLength(1000) description?: string;
  @IsOptional() @IsNumber() @Min(0) @Max(100) discountPercent?: number;
  @IsOptional() @IsNumber() @Min(0) discountAmount?: number;
  @IsOptional() @IsInt() @Min(0) discountCoinAmount?: number;
  @IsString() @MinLength(2) @MaxLength(40) benefitType!: string;
  @IsOptional() @IsInt() @Min(1) maxUsesPerUser?: number;
  @IsOptional() @IsInt() @Min(1) maxTotalUses?: number;
  @IsOptional() @IsBoolean() isStackable?: boolean;
  @IsOptional() @IsString() @MaxLength(40) fundedBy?: string;
  @IsOptional() @IsDateString() validFrom?: string;
  @IsOptional() @IsDateString() validUntil?: string;
  @IsOptional() @IsObject() conditions?: Record<string, unknown>;
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsString() @MinLength(3) @MaxLength(1000) reason!: string;
}

export class ApplyBenefitDto {
  [key: string]: unknown;
  @IsUUID() benefitId!: string;
  @IsUUID() paymentOrderId!: string;
  @IsOptional() @IsUUID() partnerId?: string;
}

export class ValidateBenefitDto {
  [key: string]: unknown;
  @IsIn(["approved", "rejected"]) status!: "approved" | "rejected";
  @ValidateIf((value: ValidateBenefitDto) => value.status === "rejected")
  @IsString()
  @MinLength(3)
  @MaxLength(1000)
  reason?: string;
}

export class SetPartnerBenefitDto {
  [key: string]: unknown;
  @IsOptional() @IsBoolean() validationRequired?: boolean;
  @IsOptional() @IsObject() settlementTerms?: Record<string, unknown>;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

export class ReverseBenefitDto {
  [key: string]: unknown;
  @IsString() @MinLength(3) @MaxLength(1000) reason!: string;
}
