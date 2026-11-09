import {
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from "class-validator";

export class CreateClinicalNoteDto {
  @IsUUID()
  appointmentId!: string;

  @IsUUID()
  patientId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(5000)
  subjective!: string;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  objective?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(5000)
  assessment!: string;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  plan?: string;
}
