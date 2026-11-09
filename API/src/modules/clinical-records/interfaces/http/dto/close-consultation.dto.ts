import {
  IsIn,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from "class-validator";

export class CloseConsultationDto {
  @IsUUID() appointmentId!: string;
  @IsUUID() patientId!: string;
  @IsString() @MinLength(3) @MaxLength(5000) subjective!: string;
  @IsOptional() @IsString() @MaxLength(5000) objective?: string;
  @IsString() @MinLength(3) @MaxLength(5000) assessment!: string;
  @IsOptional() @IsString() @MaxLength(5000) plan?: string;
  @IsString() @MinLength(2) @MaxLength(1000) diagnosis!: string;
  @IsIn(["presumptive", "definitive", "differential"])
  diagnosisType!: string;
  @IsOptional() @IsString() @MaxLength(2000) treatment?: string;
  @IsOptional() @IsString() @MaxLength(2000) treatmentInstructions?: string;
  @IsOptional() @IsISO8601() followupDueAt?: string;
  @IsOptional() @IsString() @MaxLength(2000) followupInstructions?: string;
}
