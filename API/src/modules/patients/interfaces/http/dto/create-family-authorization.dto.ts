import {
  IsBoolean,
  IsEmail,
  IsNotEmpty,
  IsString,
  MaxLength,
} from "class-validator";

export class CreateFamilyAuthorizationDto {
  @IsEmail()
  email!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  relationship!: string;

  @IsBoolean()
  canViewHistory!: boolean;

  @IsBoolean()
  canBookAppointments!: boolean;

  @IsBoolean()
  canHandleEmergencies!: boolean;
}
