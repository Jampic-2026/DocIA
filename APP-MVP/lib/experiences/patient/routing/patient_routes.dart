import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../modules/account/presentation/account_screen.dart';
import '../../../modules/benefits/presentation/benefits_screen.dart';
import '../presentation/ai_assistant_screen.dart';
import '../presentation/appointments_screen.dart';
import '../presentation/appointment_detail_screen.dart';
import '../presentation/clinical_profile_screen.dart';
import '../presentation/doctor_directory_screen.dart';
import '../presentation/emergency_screen.dart';
import '../presentation/family_screen.dart';
import '../presentation/vital_signs_screen.dart';
import '../presentation/clinical_documents_screen.dart';
import '../presentation/patient_dashboard_screen.dart';
import '../presentation/telemedicine_screen.dart';
import '../../../modules/prescriptions/presentation/prescriptions_screen.dart';
import '../../../modules/catalog/presentation/catalog_screen.dart';
import '../../../modules/coins/presentation/coins_screen.dart';
import '../../../modules/consents/presentation/consents_screen.dart';
import '../../../modules/help/presentation/help_screen.dart';
import '../../../modules/clinical_records/presentation/clinical_corrections_screen.dart';
import '../../../modules/human_resources/presentation/professional_application_screen.dart';
import '../../../modules/incidents/presentation/incidents_screen.dart';
import '../../../modules/notifications/presentation/notifications_screen.dart';
import '../../../modules/guidance/presentation/support_calls_screen.dart';
import '../../../modules/payments/presentation/payments_screen.dart';

RouteBase patientRoutes(GlobalKey<NavigatorState> rootNavigatorKey) {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, shell) {
      final path = state.uri.path;
      final clinicalProfileSelected =
          shell.currentIndex == 4 ||
          path.endsWith('/${AppRoutes.clinicalProfile}');
      final familySelected =
          shell.currentIndex == 5 || path.endsWith('/${AppRoutes.family}');
      final prescriptionsSelected =
          shell.currentIndex == 6 ||
          path.endsWith('/${AppRoutes.patientPrescriptions}');
      final secondarySelected =
          clinicalProfileSelected || familySelected || prescriptionsSelected;

      return AppShell(
        navigationShell: shell,
        selectedDestinationIndex: secondarySelected ? -1 : null,
        destinations: const [
          ShellDestination(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Inicio',
            location: AppRoutes.patientHome,
          ),
          ShellDestination(
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month_rounded,
            label: 'Citas',
            location: AppRoutes.patientAppointments,
          ),
          ShellDestination(
            icon: Icons.smart_toy_outlined,
            selectedIcon: Icons.smart_toy_rounded,
            label: 'Asistente',
            location: AppRoutes.patientAssistant,
          ),
          ShellDestination(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: 'Cuenta',
            location: AppRoutes.patientProfile,
          ),
        ],
        actions: [
          ShellAction(
            icon: Icons.folder_shared_rounded,
            label: 'Perfil clínico',
            selected: clinicalProfileSelected,
            onTap: () => shell.goBranch(4),
          ),
          ShellAction(
            icon: Icons.groups_rounded,
            label: 'Familiares',
            selected: familySelected,
            onTap: () => shell.goBranch(5),
          ),
          ShellAction(
            icon: Icons.receipt_long_rounded,
            label: 'Recetas',
            selected: prescriptionsSelected,
            onTap: () => shell.goBranch(6),
          ),
        ],
      );
    },
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.patientHome,
            builder: (_, __) => const PatientDashboardScreen(),
            routes: [
              GoRoute(
                path: 'support-calls',
                builder: (_, state) => SupportCallsScreen(
                  patientMode: true,
                  callId: state.uri.queryParameters['callId'],
                ),
              ),
              GoRoute(
                path: AppRoutes.vitalSigns,
                name: AppRoutes.vitalSigns,
                builder: (_, __) => const VitalSignsScreen(),
              ),
              GoRoute(
                path: AppRoutes.clinicalDocuments,
                name: AppRoutes.clinicalDocuments,
                builder: (_, __) => const ClinicalDocumentsScreen(),
              ),
              GoRoute(
                path: AppRoutes.clinicalCorrections,
                name: AppRoutes.clinicalCorrections,
                parentNavigatorKey: rootNavigatorKey,
                builder: (_, __) => const ClinicalCorrectionsScreen(),
              ),
              GoRoute(
                path: AppRoutes.telemedicine,
                name: AppRoutes.telemedicine,
                parentNavigatorKey: rootNavigatorKey,
                builder: (_, __) => const TelemedicineScreen(),
              ),
              GoRoute(
                path: AppRoutes.catalog,
                name: AppRoutes.catalog,
                builder: (_, __) => const CatalogScreen(),
              ),
              GoRoute(
                path: AppRoutes.coins,
                name: AppRoutes.coins,
                builder: (_, __) => const CoinsScreen(),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.patientAppointments,
            builder: (_, __) => const AppointmentsScreen(),
            routes: [
              GoRoute(
                path: AppRoutes.appointmentDetail,
                name: AppRoutes.appointmentDetail,
                parentNavigatorKey: rootNavigatorKey,
                builder: (_, state) => AppointmentDetailScreen(
                  appointmentId: state.uri.queryParameters['id'] ?? '',
                ),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.patientAssistant,
            builder: (_, __) => const AiAssistantScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.patientProfile,
            builder: (_, __) => const AccountScreen(),
            routes: [
              GoRoute(
                path: AppRoutes.consents,
                name: AppRoutes.consents,
                builder: (_, __) => const ConsentsScreen(),
              ),
              GoRoute(
                path: AppRoutes.professionalApplication,
                name: AppRoutes.professionalApplication,
                builder: (_, __) => const ProfessionalApplicationScreen(),
              ),
              GoRoute(path: 'help', builder: (_, __) => const HelpScreen()),
              GoRoute(
                path: 'incidents',
                builder: (_, __) => const IncidentsScreen(),
              ),
              GoRoute(
                path: 'benefits',
                builder: (_, __) => const BenefitsScreen(),
              ),
              GoRoute(
                path: 'payments',
                builder: (_, __) => const PaymentsScreen(),
              ),
              GoRoute(
                path: 'catalog',
                builder: (_, __) => const CatalogScreen(),
              ),
              GoRoute(path: 'coins', builder: (_, __) => const CoinsScreen()),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '${AppRoutes.patientHome}/${AppRoutes.clinicalProfile}',
            name: AppRoutes.clinicalProfile,
            builder: (_, __) => const ClinicalProfileScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '${AppRoutes.patientHome}/${AppRoutes.family}',
            name: AppRoutes.family,
            builder: (_, __) => const FamilyScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '${AppRoutes.patientHome}/${AppRoutes.patientPrescriptions}',
            name: AppRoutes.patientPrescriptions,
            builder: (_, __) => const PrescriptionsScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '${AppRoutes.patientHome}/${AppRoutes.emergency}',
            name: AppRoutes.emergency,
            builder: (_, __) => const EmergencyScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '${AppRoutes.patientHome}/${AppRoutes.doctorDirectory}',
            name: AppRoutes.doctorDirectory,
            builder: (_, __) => const DoctorDirectoryScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.patientNotifications,
            builder: (_, __) => const NotificationsScreen(),
          ),
        ],
      ),
    ],
  );
}
