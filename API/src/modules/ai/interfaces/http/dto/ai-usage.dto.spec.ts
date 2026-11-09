import { validate } from "class-validator";
import { SendAiMessageDto } from "./send-ai-message.dto";
import {
  EndVoiceSessionDto,
  StartVoiceSessionDto,
} from "./voice-session.dto";

describe("AI usage DTOs", () => {
  it("accepts messages up to 1000 characters", async () => {
    const dto = new SendAiMessageDto();
    dto.message = "a".repeat(1000);

    await expect(validate(dto)).resolves.toHaveLength(0);
  });

  it("rejects messages longer than 1000 characters", async () => {
    const dto = new SendAiMessageDto();
    dto.message = "a".repeat(1001);

    await expect(validate(dto)).resolves.toEqual(
      expect.arrayContaining([
        expect.objectContaining({ property: "message" }),
      ]),
    );
  });

  it("accepts optional voice session topic", async () => {
    const dto = new StartVoiceSessionDto();
    dto.topic = "Dolor de cabeza";

    await expect(validate(dto)).resolves.toHaveLength(0);
  });

  it("requires a UUID to end a voice session", async () => {
    const dto = new EndVoiceSessionDto();
    dto.sessionId = "not-a-uuid";

    await expect(validate(dto)).resolves.toEqual(
      expect.arrayContaining([
        expect.objectContaining({ property: "sessionId" }),
      ]),
    );
  });
});
