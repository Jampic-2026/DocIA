import { Type } from "class-transformer";
import {
  IsBoolean,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUrl,
  IsUUID,
  MaxLength,
  Min,
  ValidateIf,
} from "class-validator";

export class CreatePaymentOrderDto {
  @IsUUID() serviceId!: string;
  @IsOptional() @IsUUID() patientId?: string;
  @IsOptional() @IsUUID() appointmentId?: string;
  @IsOptional() @IsUUID() emergencyId?: string;
  @IsOptional() @IsString() @MaxLength(80) relatedEntityType?: string;
  @IsOptional() @IsUUID() relatedEntityId?: string;
}

export class AcceptPaymentOrderDto {
  @IsBoolean() accepted!: boolean;
  @ValidateIf((input: AcceptPaymentOrderDto) => !input.accepted)
  @IsString()
  @MaxLength(1000)
  reason?: string;
}

export class SubmitPaymentDto {
  @IsIn(["qr"])
  method!: "qr";

  @Type(() => Number)
  @IsNumber()
  @Min(0.01)
  amount!: number;

  @ValidateIf((input: SubmitPaymentDto) => input.method === "qr")
  @IsUrl({ require_tld: false })
  receiptUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  transactionReference?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  collectionContext?: string;
}

export class CreateStripePaymentIntentDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  idempotencyKey?: string;
}

export class RegisterInPersonPaymentDto {
  @IsIn(["qr", "cash"]) method!: "qr" | "cash";
  @Type(() => Number) @IsNumber() @Min(0.01) amount!: number;
  @ValidateIf((input: RegisterInPersonPaymentDto) => input.method === "qr")
  @IsUrl({ require_tld: false })
  receiptUrl?: string;
  @IsOptional() @IsString() @MaxLength(160) transactionReference?: string;
  @IsIn(["in_person_appointment", "home_service"])
  collectionContext!: string;
}

export class ConfirmInPersonPaymentDto {
  @IsBoolean() confirmed!: boolean;
  @ValidateIf((input: ConfirmInPersonPaymentDto) => !input.confirmed)
  @IsString()
  @MaxLength(2000)
  description?: string;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) reportedAmount?: number;
}

export class ReviewPaymentDto {
  @IsBoolean()
  approved!: boolean;

  @ValidateIf((input: ReviewPaymentDto) => !input.approved)
  @IsString()
  @MaxLength(1000)
  reason?: string;
}

export class ReportPaymentIncidentDto {
  @IsIn(["amount_difference", "duplicate", "failed", "other"])
  incidentType!: string;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) reportedAmount?: number;
  @IsString() @MaxLength(2000) description!: string;
}

export class ResolvePaymentIncidentDto {
  @IsIn(["reject", "adjust", "refund_fiat", "return_coins"])
  action!: "reject" | "adjust" | "refund_fiat" | "return_coins";
  @IsString() @MaxLength(2000) resolution!: string;
  @ValidateIf(
    (input: ResolvePaymentIncidentDto) => input.action === "refund_fiat",
  )
  @Type(() => Number)
  @IsNumber()
  @Min(0.01)
  amount?: number;
  @ValidateIf(
    (input: ResolvePaymentIncidentDto) => input.action === "return_coins",
  )
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  coinAmount?: number;
}
