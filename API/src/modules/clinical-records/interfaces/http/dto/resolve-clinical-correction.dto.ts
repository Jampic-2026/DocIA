import { IsIn, IsString, MaxLength, MinLength } from "class-validator";

export class ResolveClinicalCorrectionDto {
  @IsIn(["accepted", "rejected"])
  status!: "accepted" | "rejected";

  @IsString()
  @MinLength(3)
  @MaxLength(1000)
  resolution!: string;
}
