export const AI_PROVIDER = Symbol("AI_PROVIDER");

export interface AiProvider {
  reply(
    messages: Array<{ role: "user" | "assistant"; content: string }>,
  ): Promise<string>;
}
