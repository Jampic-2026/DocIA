import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notifications_controller.dart';
import 'notification_destination.dart';
import '../domain/app_notification.dart';
import '../../auth/application/auth_controller.dart';
import '../../../core/routing/app_router.dart';

final pushNotificationsServiceProvider = Provider<PushNotificationsService>(
  (ref) => PushNotificationsService(ref),
);

class PushNotificationsService {
  PushNotificationsService(this._ref);

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _localInitialized = false;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  Future<void> initializeForSession() async {
    if (kIsWeb || _initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp();
      await _configureLocalNotifications();

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        _registerToken,
      );
      _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
        _showForegroundNotification(message);
        _ref.invalidate(notificationsControllerProvider);
      });
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _openPayload(message.data),
      );
      final initial = await messaging.getInitialMessage();
      if (initial != null) _openPayload(initial.data);
    } catch (_) {
      _initialized = false;
    }
  }

  Future<void> endSession({bool unregisterFromServer = true}) async {
    if (kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (unregisterFromServer && token != null) {
        await _ref
            .read(notificationsRepositoryProvider)
            .unregisterPushDevice(token);
      }
      await messaging.deleteToken();
    } catch (_) {
      // El cierre de sesión no debe quedar bloqueado por FCM o por la red.
    } finally {
      await _tokenSubscription?.cancel();
      await _messageSubscription?.cancel();
      await _openedSubscription?.cancel();
      _tokenSubscription = null;
      _messageSubscription = null;
      _openedSubscription = null;
      _initialized = false;
    }
  }

  Future<void> _configureLocalNotifications() async {
    if (_localInitialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null) return;
        try {
          _openPayload(
            (jsonDecode(response.payload!) as Map).cast<String, dynamic>(),
          );
        } catch (_) {
          // Ignore malformed platform payloads; never treat them as URLs.
        }
      },
    );
    final launch = await _localNotifications.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && payload != null) {
      try {
        _openPayload((jsonDecode(payload) as Map).cast<String, dynamic>());
      } catch (_) {}
    }

    const channel = AndroidNotificationChannel(
      'docia_notifications',
      'Doc IA',
      description: 'Alertas y actualizaciones de Doc IA',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _localInitialized = true;
  }

  Future<void> _registerToken(String token) {
    return _ref
        .read(notificationsRepositoryProvider)
        .registerPushDevice(token: token, platform: _platformName());
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'docia_notifications',
          'Doc IA',
          channelDescription: 'Alertas y actualizaciones de Doc IA',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _openPayload(Map<String, dynamic> payload) {
    final user = _ref.read(authControllerProvider).user;
    if (user == null) return;
    final notification = AppNotification(
      id: '',
      eventCode: payload['eventCode'] is String
          ? payload['eventCode'] as String
          : '',
      channel: 'push',
      title: '',
      body: '',
      status: 'sent',
      createdAt: DateTime.now(),
      relatedEntityType: payload['relatedEntityType'] is String
          ? payload['relatedEntityType'] as String
          : null,
      relatedEntityId: payload['relatedEntityId'] is String
          ? payload['relatedEntityId'] as String
          : null,
    );
    final destination = notificationDestination(notification, user);
    _ref.read(routerProvider).go(destination ?? '/notifications');
    _ref.invalidate(notificationsControllerProvider);
  }

  String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'unknown';
    }
  }
}
