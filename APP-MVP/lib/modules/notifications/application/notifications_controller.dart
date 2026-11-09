import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/app_notification.dart';
import '../domain/notifications_repository.dart';
import '../infrastructure/api/api_notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) =>
      ApiNotificationsRepository(ref.watch(authenticatedApiClientProvider)),
);

class NotificationsController extends AsyncNotifier<List<AppNotification>> {
  Timer? _pollingTimer;

  @override
  Future<List<AppNotification>> build() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      refreshSilently();
    });
    ref.onDispose(() => _pollingTimer?.cancel());
    return ref.read(notificationsRepositoryProvider).list();
  }

  Future<void> refreshSilently() async {
    try {
      final items = await ref.read(notificationsRepositoryProvider).list();
      state = AsyncData(items);
    } catch (_) {}
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    await ref.read(notificationsRepositoryProvider).markRead(notification.id);
    ref.invalidateSelf();
  }

  Future<void> markAllRead() async {
    await ref.read(notificationsRepositoryProvider).markAllRead();
    ref.invalidateSelf();
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, List<AppNotification>>(
      NotificationsController.new,
    );

final notificationPreferencesProvider =
    FutureProvider<List<NotificationPreference>>(
      (ref) => ref.watch(notificationsRepositoryProvider).listPreferences(),
    );
