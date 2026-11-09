import { IsIn, IsOptional, IsString, MaxLength } from "class-validator";

export class UpdateEmergencyStatusDto {
  @IsIn([
    "confirming",
    "validating",
    "assigned",
    "on_route",
    "on_site",
    "in_care",
    "referred",
    "closed",
    "cancelled",
    "false_alarm",
  ])
  status!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  notes?: string;
}
