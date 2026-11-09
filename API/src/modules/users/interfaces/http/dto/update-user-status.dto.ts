import { IsIn, IsOptional, IsString, MaxLength } from "class-validator";
export class UpdateUserStatusDto {
  @IsIn(["active", "suspended", "inactive"]) status!:
    "active" | "suspended" | "inactive";
  @IsOptional() @IsString() @MaxLength(500) reason?: string;
}
