import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jampic/modules/auth/application/auth_controller.dart';
import 'package:jampic/modules/auth/domain/app_user.dart';
import 'package:jampic/modules/notifications/application/notification_destination.dart';
import 'package:jampic/modules/notifications/application/notifications_controller.dart';
import 'package:jampic/modules/notifications/domain/app_notification.dart';
import 'package:jampic/modules/notifications/presentation/notifications_screen.dart';

AppUser user(String role, Set<String> permissions) => AppUser(
  id: 'synthetic',
  sessionId: 'synthetic',
  email: 'test@example.invalid',
  primaryRoleCode: role,
  roles: {role},
  permissions: permissions,
);
AppNotification notice({
  String type = 'support_call_request',
  String event = 'appointments',
  bool read = false,
}) => AppNotification.fromJson({
  'id': 'notification',
  'eventCode': event,
  'channel': 'in_app',
  'title': 'Aviso de prueba',
  'body': 'Contenido sintético',
  'status': read ? 'read' : 'sent',
  'createdAt': '2026-10-11T00:00:00Z',
  'relatedEntityType': type,
  'relatedEntityId': 'synthetic-call',
});

class _Auth extends AuthController {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: user('patient', {'appointments.read', 'notifications.read'}),
  );
}

class _Notifications extends NotificationsController {
  bool marked = false;
  bool fail = false;
  @override
  Future<List<AppNotification>> build() async => [notice(read: true)];
  @override
  Future<void> markRead(AppNotification notification) async {
    if (fail) throw Exception('Synthetic network error');
    marked = true;
  }
}

void main() {
  test('Notification retains entity references supplied by the API', () {
    expect(notice().relatedEntityType, 'support_call_request');
    expect(notice().relatedEntityId, 'synthetic-call');
  });
  for (final entry in {
    'patient': '/patient/support-calls?callId=synthetic-call',
    'doctor_general': '/doctor/support-calls?callId=synthetic-call',
    'operator': '/operations?tab=support_calls',
    'admin': '/admin/management?tab=support_calls',
    'clinical_supervisor': '/operations?tab=support_calls',
  }.entries) {
    test('Support notification opens the correct module for ${entry.key}', () {
      expect(
        notificationDestination(
          notice(),
          user(entry.key, {
            'appointments.read',
            'emergencies.manage',
            'emergencies.read',
            'administration.read',
          }),
        ),
        entry.value,
      );
    });
  }
  test('Entity type takes precedence over generic appointments category', () {
    expect(
      notificationDestination(
        notice(type: 'appointment'),
        user('patient', {'appointments.read'}),
      ),
      '/patient/appointments/appointment-detail?id=synthetic-call',
    );
    expect(
      notificationDestination(
        notice(type: 'telemedicine_room'),
        user('patient', {'appointments.read'}),
      ),
      '/patient/telemedicine',
    );
  });
  test(
    'Missing permissions and unknown destinations do not open an unrelated screen',
    () {
      expect(notificationDestination(notice(), user('patient', {})), isNull);
      expect(
        notificationDestination(
          notice(),
          user('operator', {'notifications.read'}),
        ),
        isNull,
      );
      expect(
        notificationDestination(
          notice(type: 'https://example.invalid', event: 'unknown'),
          user('patient', {'appointments.read'}),
        ),
        isNull,
      );
    },
  );
  for (final fail in [false, true]) {
    testWidgets(
      'Clicking notification navigates even if marking read fails ($fail)',
      (tester) async {
        final notifications = _Notifications()..fail = fail;
        final router = GoRouter(
          initialLocation: '/notifications',
          routes: [
            GoRoute(
              path: '/notifications',
              builder: (_, __) => const NotificationsScreen(),
            ),
            GoRoute(
              path: '/patient/support-calls',
              builder: (_, state) => Scaffold(
                body: Text('Destino ${state.uri.queryParameters['callId']}'),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(_Auth.new),
              notificationsControllerProvider.overrideWith(() => notifications),
              notificationPreferencesProvider.overrideWith((ref) async => []),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aviso de prueba'));
        await tester.pumpAndSettle();
        expect(find.text('Destino synthetic-call'), findsOneWidget);
        if (!fail) expect(notifications.marked, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
