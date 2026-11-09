import { Type } from "class-transformer";
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsEmail,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from "class-validator";

export class UpsertPartnerDto {
  [key: string]: unknown;
  @IsString() @MinLength(2) @MaxLength(180) name!: string;
  @IsIn([
    "laboratory",
    "imaging",
    "clinic",
    "hospital",
    "pharmacy",
    "ambulance",
    "other",
  ])
  partnerType!: string;
  @IsOptional() @IsString() @MaxLength(80) taxId?: string;
  @IsOptional() @IsString() @MaxLength(40) phone?: string;
  @IsOptional() @IsEmail() email?: string;
  @IsOptional() @IsString() @MaxLength(1000) address?: string;
  @IsOptional() @IsNumber() latitude?: number;
  @IsOptional() @IsNumber() longitude?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsString() @MinLength(3) @MaxLength(1000) reason!: string;
}

export class AddPartnerDocumentDto {
  [key: string]: unknown;
  @IsString() @MinLength(2) @MaxLength(80) documentType!: string;
  @IsOptional() @IsString() @MaxLength(120) documentNumber?: string;
  @IsString() @MinLength(3) @MaxLength(2000) fileUrl!: string;
  @IsOptional() @Matches(/^\d{4}-\d{2}-\d{2}$/) validUntil?: string;
}

export class ReviewPartnerDocumentDto {
  [key: string]: unknown;
  @IsIn(["approved", "rejected"]) status!: "approved" | "rejected";
  @IsOptional() @IsString() @MaxLength(1000) observation?: string;
}

export class AssignPartnerUserDto {
  [key: string]: unknown;
  @IsUUID() userId!: string;
  @IsString() @MinLength(2) @MaxLength(60) partnerRole!: string;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

class PartnerRequestItemDto {
  @IsOptional() @IsUUID() catalogItemId?: string;
  @IsOptional() @IsUUID() prescriptionItemId?: string;
  @IsString() @MinLength(2) @MaxLength(500) description!: string;
  @IsNumber() @Min(0.01) quantity!: number;
}

export class CreatePartnerRequestDto {
  [key: string]: unknown;
  @IsOptional() @IsUUID() partnerId?: string;
  @IsOptional() @IsUUID() prescriptionId?: string;
  @IsOptional() @IsString() @MaxLength(1000) notes?: string;
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => PartnerRequestItemDto)
  items!: PartnerRequestItemDto[];
}

export class RespondPartnerRequestDto {
  [key: string]: unknown;
  @IsIn(["accepted", "rejected"]) status!: "accepted" | "rejected";
  @IsOptional() @IsString() @MaxLength(1000) reason?: string;
}

export class CreateDiagnosticOrderDto {
  [key: string]: unknown;
  @IsUUID() patientId!: string;
  @IsOptional() @IsUUID() partnerId?: string;
  @IsOptional() @IsUUID() appointmentId?: string;
  @IsIn(["lab", "imaging", "other"]) orderType!: string;
  @IsString() @MinLength(3) @MaxLength(2000) description!: string;
}

export class CompleteDiagnosticOrderDto {
  [key: string]: unknown;
  @IsString() @MinLength(2) @MaxLength(80) documentType!: string;
  @IsString() @MinLength(3) @MaxLength(2000) fileUrl!: string;
  @IsOptional() @IsString() @MaxLength(255) fileName?: string;
  @IsOptional() @IsString() @MaxLength(120) mimeType?: string;
}
