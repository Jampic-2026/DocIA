import {
  IsBoolean,
  IsDateString,
  IsEmail,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
  ValidateIf,
} from "class-validator";

export class RequestRegistrationDto {
  @IsEmail() email!: string;
}

export class CompleteRegistrationDto {
  @IsString() @MinLength(32) token!: string;
  @IsString() @MinLength(10) @MaxLength(128) password!: string;
  @IsString() @MinLength(1) @MaxLength(100) @Matches(/\S/) firstName!: string;
  @IsString() @MinLength(1) @MaxLength(100) @Matches(/\S/) lastName!: string;
  @IsOptional() @IsString() @MaxLength(100) secondLastName?: string;
  @IsOptional() @Matches(/^\+?[0-9][0-9\s-]{6,38}$/) phone?: string;
  @IsDateString() birthDate!: string;
  @IsOptional() @IsString() @MaxLength(30) documentType?: string;
  @IsOptional() @IsString() @MaxLength(60) documentNumber?: string;
  @IsOptional() @IsString() @MaxLength(120) municipality?: string;
  @IsOptional() @IsString() @MaxLength(120) zone?: string;
  @IsOptional() @IsString() @MaxLength(1000) addressLine?: string;
  @IsBoolean() acceptRequiredConsents!: boolean;
  @IsOptional() @IsEmail() guardianEmail?: string;
  @ValidateIf((input: CompleteRegistrationDto) => Boolean(input.guardianEmail))
  @IsString()
  @MaxLength(80)
  guardianRelationship?: string;
}
