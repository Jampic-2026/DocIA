import { IsBoolean, IsIn, IsString, MaxLength } from "class-validator";

export class UpdateNotificationPreferenceDto {
  @IsString()
  @MaxLength(100)
  eventCode!: string;

  @IsIn(["email", "push", "sms", "instant_message", "in_app"])
  channel!: string;

  @IsBoolean()
  enabled!: boolean;
}
