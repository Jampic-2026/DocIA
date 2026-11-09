import { IsBoolean, IsOptional, IsString, MaxLength } from "class-validator";

export class UpsertServiceDto {
  @IsString() @MaxLength(80) code!: string;
  @IsString() @MaxLength(180) name!: string;
  @IsString() @MaxLength(80) category!: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsBoolean() isActive?: boolean;
}
