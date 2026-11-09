import {
  IsEmail,
  IsOptional,
  IsString,
  MinLength,
  Matches,
  ValidateIf,
} from "class-validator";

export class LoginDto {
  @ValidateIf((dto: LoginDto) => !dto.phone)
  @IsEmail()
  @IsOptional()
  email?: string;

  @ValidateIf((dto: LoginDto) => !dto.email)
  @IsString()
  @IsOptional()
  phone?: string;

  @IsString()
  @MinLength(8)
  password!: string;
  @IsOptional() @Matches(/^\d{6}$/) mfaCode?: string;
}
