import { IsString, Matches, MinLength } from "class-validator";

export class ResetPasswordDto {
  @IsString()
  @MinLength(32)
  token!: string;

  @IsString()
  @MinLength(8)
  @Matches(/[a-z]/, { message: "La contraseña debe incluir una minúscula." })
  @Matches(/[A-Z]/, { message: "La contraseña debe incluir una mayúscula." })
  @Matches(/[0-9]/, { message: "La contraseña debe incluir un número." })
  @Matches(/[^A-Za-z0-9]/, {
    message: "La contraseña debe incluir un carácter especial.",
  })
  newPassword!: string;
}
