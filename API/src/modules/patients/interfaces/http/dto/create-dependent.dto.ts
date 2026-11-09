import {
  Equals,
  IsBoolean,
  IsDateString,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from "class-validator";
export class CreateDependentDto {
  @IsString() @MinLength(2) @MaxLength(100) firstName!: string;
  @IsString() @MinLength(2) @MaxLength(100) lastName!: string;
  @IsOptional() @IsString() @MaxLength(100) secondLastName?: string;
  @IsDateString() birthDate!: string;
  @IsOptional() @IsString() @MaxLength(30) documentType?: string;
  @IsOptional() @IsString() @MaxLength(60) documentNumber?: string;
  @IsString() @MinLength(2) @MaxLength(80) relationship!: string;
  @IsBoolean() @Equals(true) confirmResponsibility!: boolean;
}
