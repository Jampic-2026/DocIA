import { IsString, MinLength, MaxLength } from "class-validator";
export class NoShowDto {
  @IsString() @MinLength(3) @MaxLength(1000) reason!: string;
}
