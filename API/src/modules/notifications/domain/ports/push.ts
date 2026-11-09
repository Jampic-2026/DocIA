export type PushNotification = {
  eventCode: string;
  title: string;
  body: string;
  relatedEntityType?: string;
  relatedEntityId?: string;
};
export type QueuedPush = PushNotification & {
  notificationId: string;
  userId: string;
};
export const PUSH_REPOSITORY = Symbol("PUSH_REPOSITORY");
export interface PushRepository {
  claim(): Promise<QueuedPush[]>;
  patientUserId(patientId: string): Promise<string | undefined>;
  activeTokensForUser(userId: string, eventCode: string): Promise<string[]>;
  deactivateTokens(userId: string, tokens: string[]): Promise<void>;
  complete(id: string): Promise<void>;
  fail(id: string, message: string): Promise<void>;
}
export const PUSH_PROVIDER = Symbol("PUSH_PROVIDER");
export interface PushProvider {
  readonly enabled: boolean;
  send(
    tokens: string[],
    notification: PushNotification,
  ): Promise<{ invalidTokens: string[]; transientFailures: number }>;
}
