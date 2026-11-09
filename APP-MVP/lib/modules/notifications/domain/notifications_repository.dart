import 'app_notification.dart';

abstract interface class NotificationsRepository {
  Future<List<AppNotification>> list();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<List<NotificationPreference>> listPreferences();
  Future<NotificationPreference> updatePreference({
    required String eventCode,
    required String channel,
    required bool enabled,
  });
  Future<void> registerPushDevice({
    required String token,
    required String platform,
    String? deviceId,
    String? appVersion,
  });
  Future<void> unregisterPushDevice(String token);
}
