import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  IsUUID,
  IsArray,
  ArrayMaxSize,
} from "class-validator";

export class UpdateProfessionalProfileDto {
  @IsOptional() @IsString() @MaxLength(3000) academicBackground?: string;
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(30)
  @IsString({ each: true })
  @MaxLength(200, { each: true })
  publicCertifications?: string[];
  @IsOptional()
  @IsUUID()
  specialtyId?: string;
  @IsOptional()
  @IsString()
  @MaxLength(100)
  licenseNumber?: string;

  @IsOptional()
  @IsString()
  @MaxLength(3000)
  bio?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(80)
  yearsExperience?: number;

  @IsOptional()
  @IsBoolean()
  publicProfileEnabled?: boolean;
}
