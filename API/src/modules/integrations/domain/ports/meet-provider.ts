export const MEET_PROVIDER = Symbol("MEET_PROVIDER");

export interface MeetSpace {
  name: string;
  meetingUri: string;
  meetingCode?: string;
}

export interface MeetProvider {
  createAuthorizationUrl(userId: string): Promise<string>;
  completeAuthorization(code: string, state: string): Promise<void>;
  status(): Promise<{
    connected: boolean;
    expiresAt: Date | null;
    connectedByName: string | null;
    redirectUri: string;
  }>;
  disconnect(): Promise<void>;
  createSpace(): Promise<MeetSpace>;
  allowDirectJoin(spaceName: string): Promise<void>;
  endActiveConference(spaceName: string): Promise<void>;
}
