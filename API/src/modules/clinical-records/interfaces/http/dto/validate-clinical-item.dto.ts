import { IsIn, IsOptional, IsString, MaxLength } from "class-validator";

export class ValidateClinicalItemDto {
  @IsIn(["validated", "rejected"])
  status!: "validated" | "rejected";

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}
