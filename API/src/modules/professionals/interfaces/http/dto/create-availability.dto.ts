import { IsIn, IsInt, Matches, Max, Min } from "class-validator";

export class CreateAvailabilityDto {
  @IsInt()
  @Min(0)
  @Max(6)
  weekday!: number;

  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  startTime!: string;

  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  endTime!: string;

  @IsIn(["telemedicine", "home_visit", "in_person"])
  modality!: "telemedicine" | "home_visit" | "in_person";
}
