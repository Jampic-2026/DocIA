import {
  IsEnum,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from "class-validator";

export class CreateAppointmentDto {
  @IsOptional() @IsUUID() serviceId?: string;
  @IsOptional()
  @IsUUID()
  patientId?: string;
  @IsUUID()
  professionalId!: string;
  @IsUUID()
  specialtyId!: string;
  @IsEnum(["telemedicine", "home_visit", "in_person"])
  modality!: "telemedicine" | "home_visit" | "in_person";
  @IsISO8601()
  startAt!: string;
  @IsISO8601()
  endAt!: string;
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  reason?: string;
}
