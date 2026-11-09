import {
  IsBoolean,
  IsDefined,
  IsOptional,
  IsString,
  MaxLength,
} from "class-validator";
export class UpdateSystemSettingDto {
  [key: string]: unknown;

  @IsDefined() value!: unknown;
  @IsOptional() @IsString() @MaxLength(500) description?: string;
  @IsOptional() @IsBoolean() requiresClinicalApproval?: boolean;
}
