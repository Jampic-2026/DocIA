import { Type } from "class-transformer";
import {
  IsBoolean,
  IsDateString,
  IsIn,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
  IsArray,
  ArrayNotEmpty,
  ArrayMaxSize,
  ArrayUnique,
} from "class-validator";

export class SubmitPersonnelApplicationDto {
  [key: string]: unknown;

  @IsString()
  @MinLength(2)
  @MaxLength(60)
  requestedRoleCode!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(100)
  licenseNumber!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(160)
  requestedSpecialty!: string;
}

export class AddPersonnelDocumentDto {
  [key: string]: unknown;

  @IsString()
  @MinLength(2)
  @MaxLength(80)
  documentType!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(2000)
  fileUrl!: string;

  @IsOptional()
  @IsDateString()
  validUntil?: string;
}

export class ReviewPersonnelDocumentDto {
  [key: string]: unknown;

  @IsIn(["approved", "rejected"])
  status!: "approved" | "rejected";

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  observation?: string;
}

export class ReviewPersonnelApplicationDto {
  [key: string]: unknown;

  @IsIn(["under_review", "approved", "rejected"])
  status!: "under_review" | "approved" | "rejected";

  @IsOptional()
  @IsUUID()
  specialtyId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  reason?: string;

  @IsOptional()
  @IsIn([
    "doctor",
    "nurse",
    "operator",
    "admin",
    "delivery",
    "clinical_supervisor",
    "human_resources",
  ])
  professionalType?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  licenseNumber?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  employeeCode?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  contractType?: string;

  @IsOptional()
  @IsDateString()
  hiredAt?: string;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}

export class ConfigureProfessionalRequirementsDto {
  @IsArray()
  @ArrayNotEmpty()
  @ArrayMaxSize(30)
  @ArrayUnique()
  @IsString({ each: true })
  @MinLength(2, { each: true })
  @MaxLength(80, { each: true })
  documentTypes!: string[];
}

export class UpdateEmploymentRecordDto {
  [key: string]: unknown;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  employeeCode?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  contractType?: string;

  @IsOptional()
  @IsDateString()
  hiredAt?: string;

  @IsOptional()
  @IsDateString()
  endedAt?: string;

  @IsOptional()
  @IsIn(["active", "suspended", "ended"])
  status?: "active" | "suspended" | "ended";

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;

  @IsString()
  @MinLength(3)
  @MaxLength(1000)
  reason!: string;
}

export class CreatePersonnelObservationDto {
  [key: string]: unknown;

  @IsUUID()
  professionalId!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(60)
  observationType!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(4000)
  description!: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  actionTaken?: string;

  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  isConfidential?: boolean;
}
