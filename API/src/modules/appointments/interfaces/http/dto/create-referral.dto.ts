import {
  IsDateString,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from "class-validator";

export class CreateReferralDto {
  @IsUUID() patientId!: string;
  @IsUUID() specialtyId!: string;
  @IsString() @MaxLength(2000) reason!: string;
  @IsIn(["green", "yellow", "orange", "red"])
  priority!: "green" | "yellow" | "orange" | "red";
  @IsIn(["urgent", "preferred", "ordinary", "chronic_followup"])
  referralType!: string;
  @IsOptional()
  @IsDateString()
  validUntil?: string;
}
