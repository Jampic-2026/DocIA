import { Type } from "class-transformer";
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  ValidateNested,
} from "class-validator";

class CreatePrescriptionItemDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(180)
  medicationName!: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  dose?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  frequency?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  duration?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  instructions?: string;
}

export class CreatePrescriptionDto {
  @IsUUID()
  patientId!: string;

  @IsUUID()
  appointmentId!: string;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => CreatePrescriptionItemDto)
  items!: CreatePrescriptionItemDto[];
}
