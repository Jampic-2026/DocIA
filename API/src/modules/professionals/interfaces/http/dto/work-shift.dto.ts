import {
  IsDateString,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from "class-validator";
export class SaveWorkShiftDto {
  @IsUUID() professionalId!: string;
  @IsDateString() startAt!: string;
  @IsDateString() endAt!: string;
  @IsString() @MinLength(2) @MaxLength(180) location!: string;
  @IsOptional() @IsString() @MaxLength(160) area?: string;
  @IsOptional() @IsString() @MaxLength(2000) notes?: string;
  @IsIn(["assigned", "cancelled"]) status!: "assigned" | "cancelled";
  @IsString() @MinLength(3) @MaxLength(1000) reason!: string;
}
export class ShiftQueryDto {
  @IsOptional() @IsDateString() from?: string;
  @IsOptional() @IsDateString() to?: string;
}
export class StaffAvailabilityQueryDto {
  @IsOptional() @IsString() @MaxLength(60) role?: string;
  @IsOptional() @IsString() @MaxLength(180) location?: string;
  @IsOptional() @IsUUID() specialtyId?: string;
  @IsOptional() @IsIn(["true", "false"]) availableOnly?: string;
  @IsOptional()
  @IsIn(["telemedicine", "in_person", "home_visit"])
  serviceType?: string;
}
