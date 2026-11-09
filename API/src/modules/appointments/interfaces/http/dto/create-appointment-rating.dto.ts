import {
  IsInt,
  IsBoolean,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from "class-validator";

export class CreateAppointmentRatingDto {
  @IsOptional() @IsBoolean() publicComment?: boolean;
  @IsInt()
  @Min(1)
  @Max(5)
  rating!: number;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  comment?: string;
}
