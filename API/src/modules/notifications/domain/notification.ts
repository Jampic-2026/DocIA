export type UserNotification = {
  id: string;
  eventCode: string;
  channel: string;
  title: string;
  body: string;
  relatedEntityType: string | null;
  relatedEntityId: string | null;
  status: string;
  sentAt: Date | null;
  readAt: Date | null;
  createdAt: Date;
};

export type NotificationPreference = {
  eventCode: string;
  channel: string;
  enabled: boolean;
  updatedAt: Date;
};
