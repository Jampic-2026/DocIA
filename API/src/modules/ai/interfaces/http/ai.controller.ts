import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { AiService } from "../../application/ai.service";
import { SendAiMessageDto } from "./dto/send-ai-message.dto";
import {
  EndVoiceSessionDto,
  StartVoiceSessionDto,
} from "./dto/voice-session.dto";

@Permissions(PermissionCodes.aiUse)
@Controller("ai")
export class AiController {
  constructor(private readonly service: AiService) {}

  @Post("messages")
  send(@CurrentUser() user: RequestUser, @Body() input: SendAiMessageDto) {
    return this.service.send(user, input);
  }

  @Post("voice-sessions")
  startVoiceSession(
    @CurrentUser() user: RequestUser,
    @Body() input: StartVoiceSessionDto,
  ) {
    return this.service.startVoiceSession(user, input);
  }

  @Patch("voice-sessions/end")
  endVoiceSession(
    @CurrentUser() user: RequestUser,
    @Body() input: EndVoiceSessionDto,
  ) {
    return this.service.endVoiceSession(user, input);
  }

  @Get("ai-conversations")
  aiConversations(@CurrentUser() user: RequestUser) {
    return this.service.conversations(user);
  }

  @Get("ai-conversations/:id/messages")
  aiMessages(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.service.messages(user, id);
  }

  @Patch("ai-conversations/:id/close")
  close(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.service.close(user, id);
  }

  @Get("ai-risk-assessments")
  aiRiskAssessments(@CurrentUser() user: RequestUser) {
    return this.service.riskAssessments(user);
  }

  @Post("voice-sessions/maintenance")
  @Permissions(PermissionCodes.aiManage)
  processVoiceSessionMaintenance(@CurrentUser() user: RequestUser) {
    return this.service.processVoiceSessionMaintenance(user);
  }
}
