import {
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from "class-validator";
export class CreateEmergencyDto {
  @IsOptional()
  @IsUUID()
  patientId?: string;
  @IsEnum(["green", "yellow", "red"])
  riskLevel!: "green" | "yellow" | "red";
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;
  @IsOptional()
  @IsString()
  @MaxLength(500)
  manualAddress?: string;
  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;
  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;
}
