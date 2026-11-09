import {
  IsArray,
  IsEmail,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from "class-validator";

export class UpdateClinicalProfileDto {
  @IsOptional()
  @IsString()
  @IsIn(["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"])
  bloodType?: string;

  @IsOptional()
  @IsNumber()
  @Min(30)
  @Max(250)
  heightCm?: number;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(500)
  weightKg?: number;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  insuranceProvider?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  insuranceNumber?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  profileNotes?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(300, { each: true })
  allergies?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(500, { each: true })
  chronicConditions?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(500, { each: true })
  currentMedications?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(500, { each: true })
  medicalHistory?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(500, { each: true })
  familyHistory?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(500, { each: true })
  surgicalHistory?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(180)
  emergencyContactName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  emergencyContactRelationship?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  emergencyContactPhone?: string;

  @IsOptional()
  @IsEmail()
  @MaxLength(254)
  emergencyContactEmail?: string;
}
