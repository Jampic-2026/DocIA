import { IsString, IsUUID, MaxLength, MinLength } from "class-validator";

export class CreateClinicalCorrectionDto {
  @IsUUID()
  clinicalRecordId!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(2000)
  requestedChange!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(1000)
  reason!: string;
}
