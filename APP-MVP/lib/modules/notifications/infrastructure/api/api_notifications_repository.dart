import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/app_notification.dart';
import '../../domain/notifications_repository.dart';

class ApiNotificationsRepository implements NotificationsRepository {
  ApiNotificationsRepository(this._client);

  final AuthenticatedApiClient _client;

  @override
  Future<List<AppNotification>> list() async {
    final response = await _client.get<Map<String, dynamic>>('notifications');
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  }

  @override
  Future<void> markRead(String id) async {
    await _client.patch<Map<String, dynamic>>(
      'notifications/$id/read',
      data: const <String, dynamic>{},
    );
  }

  @override
  Future<void> markAllRead() async {
    await _client.post<Map<String, dynamic>>(
      'notifications/read-all',
      data: const <String, dynamic>{},
    );
  }

  @override
  Future<List<NotificationPreference>> listPreferences() async {
    final response = await _client.get<Map<String, dynamic>>(
      'notifications/preferences',
    );
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(NotificationPreference.fromJson)
        .toList();
  }

  @override
  Future<NotificationPreference> updatePreference({
    required String eventCode,
    required String channel,
    required bool enabled,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      'notifications/preferences',
      data: {'eventCode': eventCode, 'channel': channel, 'enabled': enabled},
    );
    return NotificationPreference.fromJson(response.data!);
  }

  @override
  Future<void> registerPushDevice({
    required String token,
    required String platform,
    String? deviceId,
    String? appVersion,
  }) async {
    await _client.post<Map<String, dynamic>>(
      'notifications/push-devices',
      data: {
        'token': token,
        'platform': platform,
        if (deviceId != null) 'deviceId': deviceId,
        if (appVersion != null) 'appVersion': appVersion,
      },
    );
  }

  @override
  Future<void> unregisterPushDevice(String token) async {
    await _client.post<Map<String, dynamic>>(
      'notifications/push-devices/unregister',
      data: {'token': token},
    );
  }
}
