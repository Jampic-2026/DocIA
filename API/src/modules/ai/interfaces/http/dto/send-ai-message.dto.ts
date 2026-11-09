import {
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
  IsBoolean,
} from "class-validator";

export class SendAiMessageDto {
  @IsString()
  @MinLength(2)
  @MaxLength(1000)
  message!: string;

  @IsOptional()
  @IsUUID()
  conversationId?: string;
  @IsOptional()
  @IsBoolean()
  useClinicalContext?: boolean;
}
