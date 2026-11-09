import {
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from "class-validator";
export class CreateProfessionalVitalsDto {
  @IsOptional() @IsUUID() appointmentId?: string;
  @IsOptional() @IsUUID() emergencyId?: string;
  @IsInt() @Min(40) @Max(300) systolicPressure!: number;
  @IsInt() @Min(20) @Max(200) diastolicPressure!: number;
  @IsInt() @Min(20) @Max(250) heartRate!: number;
  @IsNumber() @Min(30) @Max(45) temperatureC!: number;
  @IsNumber() @Min(40) @Max(100) oxygenSaturation!: number;
  @IsOptional() @IsInt() @Min(5) @Max(80) respiratoryRate?: number;
  @IsOptional() @IsNumber() @Min(20) @Max(1000) glucoseMgDl?: number;
  @IsOptional() @IsNumber() @Min(1) @Max(500) weightKg?: number;
  @IsOptional() @IsNumber() @Min(30) @Max(250) heightCm?: number;
  @IsOptional() @IsString() @MaxLength(500) notes?: string;
}
