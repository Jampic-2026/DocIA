import { IsDateString, IsOptional, IsString, MaxLength } from "class-validator";

export class IssuePrescriptionDto {
  @IsDateString()
  expiresAt!: string;
  @IsOptional()
  @IsString()
  @MaxLength(64)
  allergyFingerprint?: string;
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  allergyReviewReason?: string;
}
