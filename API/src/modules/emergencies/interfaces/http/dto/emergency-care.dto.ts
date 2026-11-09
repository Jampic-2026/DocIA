import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from "class-validator";

export class DecideEmergencyAssignmentDto {
  @IsIn(["accepted", "rejected"])
  decision!: "accepted" | "rejected";
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(1000)
  reason?: string;
}
export class RecordEmergencyCareDto {
  @IsIn([
    "nursing_assessment",
    "medical_assessment",
    "intervention",
    "referral",
    "closure",
  ])
  careType!:
    | "nursing_assessment"
    | "medical_assessment"
    | "intervention"
    | "referral"
    | "closure";
  @IsString() @MinLength(3) @MaxLength(5000) notes!: string;
  @IsString() @MinLength(3) @MaxLength(3000) assessment!: string;
  @IsArray()
  @ArrayMaxSize(50)
  @IsString({ each: true })
  @MinLength(2, { each: true })
  @MaxLength(160, { each: true })
  symptoms!: string[];
  @IsOptional() @IsString() @MaxLength(3000) procedures?: string;
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(300)
  referralDestination?: string;
}
