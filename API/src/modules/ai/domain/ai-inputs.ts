export type SendAiMessageDto = {
  message: string;
  conversationId?: string;
  useClinicalContext?: boolean;
};
export type EndVoiceSessionDto = {
  sessionId: string;
};
export type StartVoiceSessionDto = {
  topic?: string;
};
