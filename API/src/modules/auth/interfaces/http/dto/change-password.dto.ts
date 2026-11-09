import { IsString, IsUUID, MaxLength, MinLength } from "class-validator";
export class ChangePasswordDto {
  @IsString() currentPassword!: string;
  @IsString() @MinLength(10) @MaxLength(128) newPassword!: string;
}
export class RevokeSessionDto {
  @IsUUID() sessionId!: string;
}
