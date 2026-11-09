import { IsIn, IsString, MaxLength, MinLength } from "class-validator";

export class CreateIncidentDto {
  @IsIn([
    "appointments",
    "telemedicine",
    "prescriptions",
    "emergencies",
    "account",
    "catalog",
    "other",
  ])
  module!: string;

  @IsIn([
    "technical",
    "service",
    "information",
    "billing",
    "complaint",
    "other",
  ])
  incidentType!: string;

  @IsIn(["green", "yellow", "red"])
  severity!: string;

  @IsString()
  @MinLength(10)
  @MaxLength(2000)
  description!: string;
}
