import { IsDateString } from "class-validator";

export class ClosePriceDto {
  @IsDateString() validUntil!: string;
}
