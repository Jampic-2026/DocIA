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
} from "class-validator";
export class CreateDeliveryDto {
  @IsUUID() partnerRequestId!: string;
  @IsUUID() deliveryAddressId!: string;
  @IsOptional() @IsUUID() recipientUserId?: string;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) deliveryFee?: number;
}
export class AssignDeliveryDto {
  @IsUUID() professionalId!: string;
}
export class UpdateDeliveryStatusDto {
  @IsIn([
    "accepted",
    "picked_up",
    "on_route",
    "delivered",
    "failed",
    "returned",
    "cancelled",
  ])
  status!: string;
  @IsOptional() @IsString() @MaxLength(1000) reason?: string;
}
export class CreateDeliveryEvidenceDto {
  @IsString() @MaxLength(60) evidenceType!: string;
  @IsUrl({ require_tld: false }) fileUrl!: string;
  @IsOptional() @IsBoolean() recipientDocumentVerified?: boolean;
  @IsOptional() @IsString() @MaxLength(1000) notes?: string;
}
