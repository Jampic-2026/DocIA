import { IsString, Matches, MinLength } from "class-validator";
export class SetupMfaDto {
  @IsString() @MinLength(8) password!: string;
}

export class ConfirmMfaDto {
  @Matches(/^\d{6}$/) code!: string;
}
export class DisableMfaDto {
  @IsString() @MinLength(8) password!: string;
  @Matches(/^\d{6}$/) code!: string;
}
export class RequestPhoneVerificationDto {
  @Matches(/^\+?[0-9][0-9\s-]{6,38}$/) phone!: string;
}
export class ConfirmPhoneVerificationDto {
  @Matches(/^\d{6}$/) code!: string;
}
