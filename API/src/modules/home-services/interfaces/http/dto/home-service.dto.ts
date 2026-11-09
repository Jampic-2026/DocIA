import { Type } from "class-transformer";
import {
  IsDateString,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUrl,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateIf,
} from "class-validator";

export class CreateHomeServiceDto {
  @IsUUID() serviceId!: string;
  @IsUUID() addressId!: string;
  @IsOptional() @IsDateString() requestedFor?: string;
}

export class AssignHomeServiceDto {
  @IsOptional() @IsUUID() professionalId?: string;
  @IsOptional() @IsUUID() partnerId?: string;
  @ValidateIf(
    (value: AssignHomeServiceDto) => !value.professionalId && !value.partnerId,
  )
  @IsString({
    message: "Debes seleccionar un profesional o una empresa asociada.",
  })
  assignment?: string;
}

export class UpdateHomeServiceStatusDto {
  @IsIn([
    "accepted",
    "rejected",
    "in_progress",
    "completed",
    "cancelled",
    "failed",
  ])
  status!: string;
  @IsOptional() @IsString() @MaxLength(1000) reason?: string;
  @IsOptional() @IsString() @MaxLength(5000) clinicalNotes?: string;
}

export class CreateServiceLocationDto {
  @Type(() => Number) @IsNumber() @Min(-90) @Max(90) latitude!: number;
  @Type(() => Number) @IsNumber() @Min(-180) @Max(180) longitude!: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) accuracyM?: number;
}

export class CreateServiceEvidenceDto {
  @IsString() @MaxLength(60) evidenceType!: string;
  @IsUrl({ require_tld: false }) fileUrl!: string;
  @IsOptional() @IsString() @MaxLength(1000) notes?: string;
}

export class CreateHomeServiceRatingDto {
  @Type(() => Number) @IsNumber() @Min(1) @Max(5) rating!: number;
  @IsOptional() @IsString() @MaxLength(1000) comment?: string;
}
