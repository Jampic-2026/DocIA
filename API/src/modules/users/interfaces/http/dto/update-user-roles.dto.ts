import { ArrayMaxSize, IsArray, IsString } from "class-validator";
export class UpdateUserRolesDto {
  @IsArray() @ArrayMaxSize(10) @IsString({ each: true }) roleCodes!: string[];
}
