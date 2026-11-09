import {
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  IsUUID,
} from "class-validator";

export class ReviewProfessionalDto {
  @IsIn(["approved", "rejected"])
  status!: "approved" | "rejected";

  @IsOptional()
  @IsString()
  @MaxLength(60)
  roleCode?: string;

  @IsOptional()
  @IsUUID()
  specialtyId?: string;

  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(1000)
  reason?: string;
}
