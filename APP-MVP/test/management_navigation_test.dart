import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jampic/core/authorization/route_access_policy.dart';
import 'package:jampic/app/app.dart';
import 'package:jampic/core/routing/app_router.dart';
import 'package:jampic/core/widgets/app_shell.dart';
import 'package:jampic/core/widgets/app_dialog_actions.dart';
import 'package:jampic/experiences/administration/presentation/admin_management_screen.dart';
import 'package:jampic/experiences/administration/routing/administration_routes.dart';
import 'package:jampic/experiences/operations/routing/operations_routes.dart';
import 'package:jampic/modules/auth/application/auth_controller.dart';
import 'package:jampic/modules/auth/domain/app_user.dart';
import 'package:jampic/modules/clinical_records/application/clinical_records_controller.dart';
import 'package:jampic/modules/clinical_records/presentation/completion_policy_screen.dart';
import 'package:jampic/modules/emergencies/application/emergencies_controller.dart';
import 'package:jampic/modules/guidance/application/guidance_controller.dart';
import 'package:jampic/modules/guidance/presentation/risk_policy_screen.dart';
import 'package:jampic/modules/guidance/presentation/support_calls_screen.dart';
import 'package:jampic/modules/human_resources/application/human_resources_controller.dart';
import 'package:jampic/modules/human_resources/presentation/document_requirements_screen.dart';
import 'package:jampic/modules/work_shifts/application/work_shifts_controller.dart';
import 'package:jampic/modules/work_shifts/presentation/work_shifts_screen.dart';
import 'package:jampic/experiences/patient/presentation/family_screen.dart';
import 'package:jampic/experiences/professional/presentation/doctor_dashboard_screen.dart';
import 'package:jampic/experiences/professional/routing/professional_routes.dart';
import 'package:jampic/core/routing/app_routes.dart';
import 'package:jampic/experiences/professional/presentation/patient_record_screen.dart';
import 'package:jampic/modules/appointments/application/appointments_controller.dart';
import 'package:jampic/modules/appointments/domain/appointment.dart';
import 'package:jampic/modules/clinical_records/domain/clinical_history.dart';
import 'package:jampic/modules/clinical_records/domain/professional_patient_record.dart';
import 'package:jampic/modules/clinical_records/presentation/clinical_history_screen.dart';
import 'package:jampic/modules/clinical_records/presentation/professional_vitals_screen.dart';
import 'package:jampic/modules/emergencies/presentation/professional_emergency_screen.dart';
import 'package:jampic/modules/family/application/family_controller.dart';
import 'package:jampic/modules/family/presentation/create_dependent_screen.dart';
import 'package:jampic/modules/human_resources/domain/staff_member.dart';
import 'package:jampic/modules/human_resources/presentation/professional_documents_screen.dart';
import 'package:jampic/modules/partners/presentation/diagnostic_orders_screen.dart';
import 'package:jampic/modules/partners/application/partners_controller.dart';
import 'package:jampic/modules/professional_profile/application/professional_profile_controller.dart';
import 'package:jampic/modules/professional_profile/domain/professional_profile.dart';

class _Appointments extends AppointmentsController {
  @override
  Future<List<Appointment>> build() async => [];
}

class _Auth extends AuthController {
  _Auth(this.user);
  final AppUser user;
  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated, user: user);
}

const _admin = AppUser(
  id: 'synthetic-admin',
  sessionId: 'synthetic',
  email: 'navigation@example.invalid',
  primaryRoleCode: 'admin',
  roles: {'admin'},
  permissions: {
    'administration.read',
    'professionals.read',
    'human_resources.read',
    'human_resources.manage',
    'administration.manage',
    'emergencies.manage',
    'emergencies.read',
    'ai.manage',
  },
);

Future<void> _mount(
  WidgetTester tester,
  GoRouter? router, {
  AppUser user = _admin,
  Widget? home,
  List<StaffMember> staff = const [],
  bool application = false,
  bool webNavigation = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        sidebarAlwaysVisibleProvider.overrideWithValue(webNavigation),
        authControllerProvider.overrideWith(() => _Auth(user)),
        staffProvider.overrideWith((ref) async => staff),
        familyProvider.overrideWith((ref) async => []),
        partnersProvider.overrideWith((ref) async => []),
        appointmentsControllerProvider.overrideWith(_Appointments.new),
        professionalProfileProvider.overrideWith(
          (ref) async => const ProfessionalProfile(
            id: 'synthetic-professional',
            professionalType: 'nurse',
            verificationStatus: 'approved',
            publicProfileEnabled: false,
            specialties: [],
            documents: [],
          ),
        ),
        professionalPatientRecordProvider.overrideWith(
          (ref, id) async => ProfessionalPatientRecord(
            patientId: id,
            fullName: 'Paciente sintético',
            statements: [],
            vitalSigns: [],
            documents: [],
          ),
        ),
        profileCompletionProvider.overrideWith(
          (ref, id) async => {
            'configured': false,
            'missing': [],
            'rewardEnabled': false,
          },
        ),
        clinicalHistoryProvider.overrideWith((ref, id) async => []),
        clinicalTrendsProvider.overrideWith(
          (ref, query) async => const ClinicalTrends(points: [], summary: {}),
        ),
        diagnosticOrdersProvider.overrideWith((ref) async => []),
        professionalDocumentsProvider.overrideWith((ref, id) async => []),
        personnelApplicationsProvider.overrideWith((ref) async => []),
        personnelDocumentsProvider.overrideWith((ref) async => []),
        documentRequirementsProvider.overrideWith((ref) async => []),
        verificationSpecialtiesProvider.overrideWith((ref) async => []),
        workShiftsProvider.overrideWith((ref, month) async => []),
        availableStaffProvider.overrideWith((ref, filter) async => []),
        supportCallsProvider.overrideWith((ref) async => []),
        emergencyEventsProvider.overrideWith((ref) async => []),
        completionPolicyProvider.overrideWith((ref) async => {'rules': []}),
        riskPolicyProvider.overrideWith(
          (ref) async => {
            'policy': {'rules': []},
            'enabled': false,
            'revision': 1,
          },
        ),
      ],
      child: application
          ? const DocIaApp()
          : home == null
          ? MaterialApp.router(routerConfig: router)
          : MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'Professional record and orientation preserve web sidebar at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final root = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: root,
          initialLocation: AppRoutes.doctorHome,
          routes: [professionalRoutes(root)],
        );
        addTearDown(router.dispose);
        await _mount(tester, router, webNavigation: true);
        router.pushNamed(
          AppRoutes.professionalPatientRecord,
          queryParameters: {'patientId': 'synthetic-patient'},
        );
        await tester.pumpAndSettle();
        expect(find.byType(PatientRecordScreen), findsOneWidget);
        expect(find.text('Cerrar sesión').hitTestable(), findsOneWidget);
        expect(
          AppShellLayout.maybeOf(
            tester.element(find.byType(PatientRecordScreen)),
          )?.usesSidebar,
          isTrue,
        );
        router.go(AppRoutes.doctorHome);
        await tester.pumpAndSettle();
        final button = find.text('Llamadas de orientación asignadas');
        await tester.ensureVisible(button);
        final bounds = tester.getRect(button);
        await tester.tapAt(Offset(bounds.left + 4, bounds.center.dy));
        await tester.pumpAndSettle();
        expect(find.byType(SupportCallsScreen), findsOneWidget);
        expect(find.text('Cerrar sesión').hitTestable(), findsOneWidget);
        expect(
          AppShellLayout.maybeOf(
            tester.element(find.byType(SupportCallsScreen)),
          )?.usesSidebar,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets('Dashboard navigation survives layout changes and reassembly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _mount(tester, null, application: true);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DocIaApp)),
    );
    var router = container.read(routerProvider);
    addTearDown(() => router.dispose());
    expect(find.text('Panel administrativo'), findsOneWidget);
    for (final width in [390.0, 1440.0, 500.0, 1722.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpAndSettle();
      tester.binding.buildOwner!.reassemble(tester.binding.rootElement!);
      await tester.pumpAndSettle();
      router.go('/admin/management?tab=document_requirements');
      await tester.pumpAndSettle();
      expect(find.byType(DocumentRequirementsScreen), findsOneWidget);
      router.go('/admin');
      await tester.pumpAndSettle();
      expect(find.text('Panel administrativo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    container.invalidate(routerProvider);
    await tester.pumpAndSettle();
    router = container.read(routerProvider);
    expect(find.text('Panel administrativo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('New module permissions also grant entry through the route guard', () {
    final admin = RouteAccessPolicy.requiredAnyPermission('/admin/management')!;
    for (final permission in [
      'human_resources.manage',
      'ai.manage',
      'emergencies.manage',
      'administration.read',
    ]) {
      expect(admin.contains(permission), isTrue, reason: permission);
    }
    expect(
      RouteAccessPolicy.requiredAnyPermission(
        '/operations',
      )!.contains('ai.manage'),
      isTrue,
    );
    expect(admin.contains('patients.read'), isFalse);
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'Web keeps sidebar and horizontal requirement actions at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          initialLocation: '/admin/management?tab=document_requirements',
          routes: [administrationRoutes()],
        );
        addTearDown(router.dispose);
        await _mount(
          tester,
          router,
          webNavigation: true,
          staff: const [
            StaffMember(
              professionalId: 'synthetic-professional',
              fullName: 'Profesional sintético',
              professionalType: 'nurse',
              verificationStatus: 'approved',
            ),
          ],
        );
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.text('Cerrar sesión'), findsOneWidget);
        expect(
          AppShellLayout.maybeOf(
            tester.element(find.byType(DocumentRequirementsScreen)),
          )!.usesSidebar,
          isTrue,
        );
        if (width < 600) {
          final scroll = find.ancestor(
            of: find.byType(DocumentRequirementsScreen),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is SingleChildScrollView &&
                  w.scrollDirection == Axis.horizontal,
            ),
          );
          await tester.drag(scroll, const Offset(-260, 0));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Medicina general'));
        await tester.pumpAndSettle();
        expect(find.byType(AppDialogActions), findsOneWidget);
        final cancel = find.widgetWithText(OutlinedButton, 'Cancelar');
        final save = find.widgetWithText(FilledButton, 'Guardar');
        expect(tester.getRect(cancel).top, tester.getRect(save).top);
        expect(tester.getRect(cancel).height, tester.getRect(save).height);
        expect(tester.takeException(), isNull);
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        router.go('/admin/management?tab=professionals');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Profesional sintético'));
        final nameBounds = tester.getRect(find.text('Profesional sintético'));
        await tester.tapAt(Offset(nameBounds.left + 4, nameBounds.center.dy));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Revisar documentos'));
        await tester.pumpAndSettle();
        expect(find.byType(ProfessionalDocumentsScreen), findsOneWidget);
        expect(find.text('Cerrar sesión'), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'Professional details survives removal of its opening screen at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final visible = ValueNotifier(true);
        addTearDown(visible.dispose);
        await _mount(
          tester,
          null,
          home: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, show, _) => show
                ? const AdminManagementScreen(initialTabCode: 'professionals')
                : const Scaffold(body: Text('Pantalla de origen retirada')),
          ),
          staff: const [
            StaffMember(
              professionalId: 'synthetic-professional',
              fullName: 'Profesional sintético',
              professionalType: 'nurse',
              verificationStatus: 'approved',
            ),
          ],
        );
        await tester.tap(find.text('Profesional sintético'));
        await tester.pumpAndSettle();
        expect(find.text('Detalle del profesional'), findsOneWidget);
        visible.value = false;
        await tester.pumpAndSettle();
        tester.binding.buildOwner!.reassemble(tester.binding.rootElement!);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Detalle del profesional'), findsOneWidget);
        await tester.tap(find.text('Cerrar'));
        await tester.pumpAndSettle();
        expect(find.text('Pantalla de origen retirada'), findsOneWidget);
      },
    );
    testWidgets(
      'Patient and professional links open the six other new views at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _mount(tester, null, home: const FamilyScreen());
        await tester.tap(find.byTooltip('Registrar menor a cargo'));
        await tester.pumpAndSettle();
        expect(find.byType(CreateDependentScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _mount(
          tester,
          null,
          home: const PatientRecordScreen(
            patientId: 'synthetic-patient',
            appointmentId: 'synthetic-appointment',
          ),
        );
        for (final entry in <String, Type>{
          'Estudios diagnósticos': DiagnosticOrdersScreen,
          'Evolución clínica': ClinicalHistoryScreen,
          'Registrar signos vitales': ProfessionalVitalsScreen,
        }.entries) {
          await tester.tap(find.byTooltip(entry.key));
          await tester.pumpAndSettle();
          expect(find.byType(entry.value), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pageBack();
          await tester.pumpAndSettle();
        }

        await _mount(
          tester,
          null,
          home: const DoctorDashboardScreen(),
          user: const AppUser(
            id: 'synthetic-nurse',
            sessionId: 'synthetic',
            email: 'nurse@example.invalid',
            primaryRoleCode: 'nurse',
            roles: {'nurse'},
            permissions: {'appointments.read', 'clinical_records.manage'},
          ),
        );
        await tester.ensureVisible(find.text('Casos asignados'));
        await tester.tap(find.text('Casos asignados'));
        await tester.pumpAndSettle();
        expect(find.byType(ProfessionalEmergencyScreen), findsOneWidget);
        expect(find.text('Sin casos activos'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Dispose the polling timer before mounting another experience.
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Mis turnos'));
        await tester.tap(find.text('Mis turnos'));
        await tester.pumpAndSettle();
        expect(find.byType(WorkShiftsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        final router = GoRouter(
          initialLocation: '/admin/management?tab=professionals',
          routes: [administrationRoutes()],
        );
        addTearDown(router.dispose);
        await _mount(
          tester,
          router,
          staff: const [
            StaffMember(
              professionalId: 'synthetic-professional',
              fullName: 'Profesional sintético',
              professionalType: 'nurse',
              verificationStatus: 'approved',
            ),
          ],
        );
        await tester.tap(find.text('Profesional sintético'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Revisar documentos'));
        await tester.pumpAndSettle();
        expect(find.byType(ProfessionalDocumentsScreen), findsOneWidget);
        expect(
          find.textContaining('No hay documentos registrados'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('Admin opens all five new modules at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/admin/management',
        routes: [administrationRoutes()],
      );
      addTearDown(router.dispose);
      await _mount(tester, router);
      // Opening Gestión must not silently select the newly inserted risk tab.
      expect(find.byType(RiskPolicyScreen), findsNothing);
      if (width < 600) {
        final bar = tester.widget<TabBar>(find.byType(TabBar).first);
        final controller = DefaultTabController.of(
          tester.element(find.byType(TabBar).first),
        );
        expect((bar.tabs[controller.index] as Tab).text, 'Profesionales');
      }
      final modules = <String, Type>{
        'Requisitos': DocumentRequirementsScreen,
        'Turnos': WorkShiftsScreen,
        'Completitud': CompletionPolicyScreen,
        'Orientación': SupportCallsScreen,
        'Reglas clínicas': RiskPolicyScreen,
      };
      for (final entry in modules.entries) {
        final link = width < 600
            ? find.widgetWithText(Tab, entry.key).first
            : find.text(entry.key).first;
        await tester.ensureVisible(link);
        await tester.tap(link);
        await tester.pumpAndSettle();
        expect(find.byType(entry.value), findsOneWidget, reason: entry.key);
        expect(tester.takeException(), isNull, reason: entry.key);
      }
      // A URL change must update an already mounted mobile TabController too.
      router.go('/admin/management?tab=document_requirements');
      await tester.pumpAndSettle();
      expect(find.byType(DocumentRequirementsScreen), findsOneWidget);
      expect(
        find.textContaining('Define los tipos de documentos'),
        findsOneWidget,
      );
    });

    testWidgets('Operations opens orientation and risk rules at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/operations',
        routes: [operationsRoutes()],
      );
      addTearDown(router.dispose);
      await _mount(tester, router);
      expect(find.text('Sin emergencias activas'), findsOneWidget);
      for (final entry in <String, Type>{
        'Orientación': SupportCallsScreen,
        'Reglas clínicas': RiskPolicyScreen,
      }.entries) {
        final link = width < 600
            ? find.widgetWithText(Tab, entry.key)
            : find.text(entry.key).first;
        await tester.ensureVisible(link);
        await tester.tap(link);
        await tester.pumpAndSettle();
        expect(find.byType(entry.value), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'Admin role alone cannot expose modules without their permissions',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/admin/management?tab=document_requirements',
        routes: [administrationRoutes()],
      );
      addTearDown(router.dispose);
      await _mount(
        tester,
        router,
        user: const AppUser(
          id: 'synthetic-restricted',
          sessionId: 'synthetic',
          email: 'restricted@example.invalid',
          primaryRoleCode: 'admin',
          roles: {'admin'},
          permissions: {'professionals.read'},
        ),
      );
      expect(find.text('Requisitos'), findsNothing);
      expect(find.byType(DocumentRequirementsScreen), findsNothing);
      expect(find.byType(RiskPolicyScreen), findsNothing);
    },
  );
}
