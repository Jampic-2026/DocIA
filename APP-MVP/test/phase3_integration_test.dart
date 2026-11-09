import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jampic/modules/ai/application/ai_assistant_controller.dart';
import 'package:jampic/modules/ai/domain/ai_repository.dart';
import 'package:jampic/modules/auth/application/auth_controller.dart';
import 'package:jampic/modules/auth/domain/app_user.dart';
import 'package:jampic/modules/guidance/application/guidance_controller.dart';
import 'package:jampic/modules/guidance/domain/guidance_repository.dart';
import 'package:jampic/modules/guidance/presentation/support_calls_screen.dart';
import 'package:jampic/modules/guidance/presentation/risk_policy_screen.dart';

const patient = AppUser(
  id: 'synthetic-patient',
  sessionId: 'synthetic',
  email: 'synthetic@example.invalid',
  primaryRoleCode: 'patient',
  roles: {'patient'},
  permissions: {'ai.use', 'appointments.read'},
);

class _Auth extends AuthController {
  _Auth(this.user);
  final AppUser user;
  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated, user: user);
}

class _Ai extends Fake implements AiRepository {
  Completer<AiReply>? pending;
  bool contextUsed = false;
  AiReply reply = const AiReply(
    conversationId: 'conversation',
    message: 'Synthetic warning',
    riskLevel: 'red',
    recommendedAction: 'emergency',
    assessmentId: 'assessment',
    classificationStatus: 'preventive_alert',
    balance: 9,
  );
  @override
  Future<AiReply> send({
    required String message,
    String? conversationId,
    bool useClinicalContext = false,
  }) async {
    contextUsed = useClinicalContext;
    return pending == null ? reply : await pending!.future;
  }

  @override
  Future<List<AiConversation>> conversations() async => [];
  @override
  Future<List<AiStoredMessage>> messages(String conversationId) async => [
    AiStoredMessage(
      text: 'Synthetic saved',
      sender: 'assistant',
      createdAt: DateTime(2026, 10, 11),
      safetyFlags: const {
        'assessmentId': 'stored-assessment',
        'riskLevel': 'yellow',
        'recommendedAction': 'appointment',
        'classificationStatus': 'clinically_validated_rules',
      },
    ),
  ];
}

class _Guidance extends Fake implements GuidanceRepository {
  List<SupportCall> visibleCalls = [];
  List<SupportStaff> staffMembers = [];
  String? assignedProfessional;
  String? startedCall;
  int requests = 0;
  String? requestedAssessment;
  String? requestedEmergency;
  @override
  Future<List<SupportCall>> calls() async => visibleCalls;
  @override
  Future<List<SupportStaff>> staff() async => staffMembers;
  @override
  Future<void> transition(
    String id,
    String action, {
    String? professionalId,
    String? notes,
  }) async {
    if (action == 'start') startedCall = id;
    if (action == 'assign') assignedProfessional = professionalId;
  }

  @override
  Future<String> requestCall(
    String reason, {
    String? assessmentId,
    String? emergencyId,
  }) async {
    requests++;
    requestedAssessment = assessmentId;
    requestedEmergency = emergencyId;
    return 'synthetic-call';
  }
}

void main() {
  for (final hasAvailable in [true, false]) {
    testWidgets(
      'Staff selector explains unavailable staff and only assigns eligible people ($hasAvailable)',
      (tester) async {
        const operator = AppUser(
          id: 'synthetic-operator',
          sessionId: 'synthetic',
          email: 'operator@example.invalid',
          primaryRoleCode: 'operator',
          roles: {'operator'},
          permissions: {'appointments.read', 'emergencies.manage'},
        );
        final guidance = _Guidance()
          ..visibleCalls = [
            const SupportCall(
              id: 'pending',
              status: 'pending',
              priority: 'green',
              reason: 'Synthetic request',
              requestedBy: 'synthetic-patient',
            ),
          ]
          ..staffMembers = [
            if (hasAvailable)
              const SupportStaff(
                'available',
                'Profesional disponible de prueba',
                available: true,
              ),
            const SupportStaff(
              'unavailable',
              'Profesional fuera de horario de prueba',
              reasons: [
                'Fuera de horario laboral: sin turno o disponibilidad vigente',
              ],
            ),
          ];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              guidanceRepositoryProvider.overrideWithValue(guidance),
              authControllerProvider.overrideWith(() => _Auth(operator)),
            ],
            child: const MaterialApp(home: SupportCallsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Asignar'));
        // The screen keeps a progress indicator while the modal is open.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.text('Disponibles (${hasAvailable ? 1 : 0})'),
          findsOneWidget,
        );
        expect(find.text('No disponibles (1)'), findsOneWidget);
        if (hasAvailable) {
          await tester.tap(find.text('No disponibles (1)'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }
        expect(
          find.text(
            'Fuera de horario laboral: sin turno o disponibilidad vigente',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Profesional fuera de horario de prueba'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(guidance.assignedProfessional, isNull);
        expect(find.text('Asignar personal clínico'), findsOneWidget);
        if (hasAvailable) {
          await tester.tap(find.text('Disponibles (1)'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.text('Profesional disponible de prueba'));
          await tester.pumpAndSettle();
          expect(guidance.assignedProfessional, 'available');
        } else {
          await tester.tap(find.text('Cerrar'));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
  for (final patientView in [true, false]) {
    testWidgets(
      patientView
          ? 'Patient sees own requests only'
          : 'Operator keeps the pending assignment queue',
      (tester) async {
        const operator = AppUser(
          id: 'synthetic-operator',
          sessionId: 'synthetic',
          email: 'operator@example.invalid',
          primaryRoleCode: 'operator',
          roles: {'operator'},
          permissions: {'appointments.read', 'emergencies.manage'},
        );
        final guidance = _Guidance()
          ..visibleCalls = [
            const SupportCall(
              id: 'own',
              status: 'pending',
              priority: 'green',
              reason: 'Synthetic own request',
              requestedBy: 'synthetic-patient',
            ),
            const SupportCall(
              id: 'other',
              status: 'pending',
              priority: 'green',
              reason: 'Synthetic other request',
              requestedBy: 'other-patient',
            ),
          ];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              guidanceRepositoryProvider.overrideWithValue(guidance),
              authControllerProvider.overrideWith(
                () => _Auth(patientView ? patient : operator),
              ),
            ],
            child: MaterialApp(
              home: SupportCallsScreen(patientMode: patientView),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Synthetic own request'), findsOneWidget);
        expect(
          find.text('Synthetic other request'),
          patientView ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('Asignar'),
          patientView ? findsNothing : findsNWidgets(2),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'Assigned doctor can accept the call; pending calls cannot be started',
    (tester) async {
      const doctor = AppUser(
        id: 'synthetic-doctor',
        sessionId: 'synthetic',
        email: 'doctor@example.invalid',
        primaryRoleCode: 'doctor',
        roles: {'doctor'},
        permissions: {'appointments.read'},
      );
      final guidance = _Guidance()
        ..visibleCalls = [
          const SupportCall(
            id: 'assigned-call',
            status: 'assigned',
            priority: 'green',
            reason: 'Synthetic assigned call',
            requestedBy: 'synthetic-patient',
            assignedUserId: 'synthetic-doctor',
          ),
          const SupportCall(
            id: 'pending-call',
            status: 'pending',
            priority: 'green',
            reason: 'Synthetic pending call',
            requestedBy: 'synthetic-patient',
          ),
          const SupportCall(
            id: 'other-call',
            status: 'assigned',
            priority: 'green',
            reason: 'Synthetic other professional call',
            requestedBy: 'synthetic-patient',
            assignedUserId: 'other-doctor',
          ),
        ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            guidanceRepositoryProvider.overrideWithValue(guidance),
            authControllerProvider.overrideWith(() => _Auth(doctor)),
          ],
          child: const MaterialApp(home: SupportCallsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Aceptar e iniciar'), findsOneWidget);
      expect(find.text('Synthetic assigned call'), findsOneWidget);
      expect(find.text('Synthetic pending call'), findsNothing);
      expect(find.text('Synthetic other professional call'), findsNothing);
      await tester.tap(find.text('Aceptar e iniciar'));
      await tester.pumpAndSettle();
      expect(guidance.startedCall, 'assigned-call');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  test(
    'A delayed response cannot attach its assessment to a newly opened conversation',
    () async {
      final ai = _Ai()..pending = Completer<AiReply>();
      final container = ProviderContainer(
        overrides: [
          aiRepositoryProvider.overrideWithValue(ai),
          authControllerProvider.overrideWith(() => _Auth(patient)),
        ],
      );
      addTearDown(container.dispose);
      final sending = container
          .read(aiAssistantProvider.notifier)
          .send('Synthetic delayed input');
      container.read(aiAssistantProvider.notifier).startNew();
      ai.pending!.complete(ai.reply);
      await sending;
      expect(container.read(aiAssistantProvider).assessmentId, isNull);
      expect(container.read(aiAssistantProvider).conversationId, isNull);
    },
  );
  test(
    'Assistant preserves safety decisions, clears stale actions and restores saved orientation',
    () async {
      final ai = _Ai();
      final container = ProviderContainer(
        overrides: [
          aiRepositoryProvider.overrideWithValue(ai),
          authControllerProvider.overrideWith(() => _Auth(patient)),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(aiAssistantProvider.notifier)
          .send('Synthetic input', useClinicalContext: true);
      expect(ai.contextUsed, isTrue);
      expect(
        container.read(aiAssistantProvider).recommendedAction,
        'emergency',
      );
      expect(container.read(aiAssistantProvider).assessmentId, 'assessment');
      ai.reply = const AiReply(
        conversationId: 'conversation',
        message: 'Synthetic unclassified',
        riskLevel: 'undetermined',
        assessmentId: 'next',
        classificationStatus: 'disabled',
      );
      await container
          .read(aiAssistantProvider.notifier)
          .send('Synthetic second input');
      expect(container.read(aiAssistantProvider).recommendedAction, isNull);
      await container
          .read(aiAssistantProvider.notifier)
          .load('conversation', isClosed: false);
      expect(
        container.read(aiAssistantProvider).assessmentId,
        'stored-assessment',
      );
      expect(
        container.read(aiAssistantProvider).recommendedAction,
        'appointment',
      );
    },
  );
  testWidgets(
    'Patient cannot assign or begin a call and can request linked human attention',
    (tester) async {
      final guidance = _Guidance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            guidanceRepositoryProvider.overrideWithValue(guidance),
            authControllerProvider.overrideWith(() => _Auth(patient)),
          ],
          child: const MaterialApp(
            home: SupportCallsScreen(
              patientMode: true,
              assessmentId: 'assessment',
              emergencyId: 'emergency',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Asignar'), findsNothing);
      expect(find.text('Aceptar e iniciar'), findsNothing);
      await tester.tap(find.text('Solicitar orientación'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'Synthetic request');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(guidance.requests, 1);
      expect(guidance.requestedAssessment, 'assessment');
      expect(guidance.requestedEmergency, 'emergency');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'Empty clinical configuration stays disabled and cannot be activated by an administrator',
    (tester) async {
      const admin = AppUser(
        id: 'synthetic-admin',
        sessionId: 'synthetic',
        email: 'admin@example.invalid',
        primaryRoleCode: 'admin',
        roles: {'admin'},
        permissions: {'ai.manage'},
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _Auth(admin)),
            riskPolicyProvider.overrideWith(
              (ref) async => {
                'policy': {'rules': []},
                'revision': 1,
                'enabled': false,
              },
            ),
          ],
          child: const MaterialApp(home: RiskPolicyScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Clasificación desactivada; no se presume bajo riesgo'),
        findsOneWidget,
      );
      expect(find.text('Validar clínicamente y activar'), findsNothing);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar y desactivar'),
      );
      expect(button.onPressed, isNull);
    },
  );
}
