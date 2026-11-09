import { IsString, Length, Matches } from "class-validator";

export class RedeemGuardianLinkCodeDto {
  @IsString()
  @Matches(/^JMP-[A-Z0-9]{4}-[A-Z0-9]{4}$/)
  code!: string;

  @IsString()
  @Length(2, 80)
  relationship!: string;
}
