import {
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from "class-validator";

export class UpdateFamilyAuthorizationDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(80) relationship?: string;
  @IsBoolean() canViewHistory!: boolean;
  @IsBoolean() canBookAppointments!: boolean;
  @IsBoolean() canHandleEmergencies!: boolean;
}
