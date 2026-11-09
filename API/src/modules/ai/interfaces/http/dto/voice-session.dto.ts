import { IsOptional, IsString, IsUUID, MaxLength } from "class-validator";

export class StartVoiceSessionDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  topic?: string;
}

export class EndVoiceSessionDto {
  @IsUUID()
  sessionId!: string;
}
