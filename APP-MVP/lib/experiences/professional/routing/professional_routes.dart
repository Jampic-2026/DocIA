import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../modules/account/presentation/account_screen.dart';
import '../../../modules/benefits/presentation/benefits_screen.dart';
import '../../../modules/catalog/presentation/catalog_screen.dart';
import '../../../modules/coins/presentation/coins_screen.dart';
import '../../../modules/consents/presentation/consents_screen.dart';
import '../../../modules/help/presentation/help_screen.dart';
import '../../../modules/incidents/presentation/incidents_screen.dart';
import '../../../modules/payments/presentation/payments_screen.dart';
import '../../patient/presentation/telemedicine_screen.dart';
import '../presentation/clinical_note_screen.dart';
import '../presentation/doctor_agenda_screen.dart';
import '../presentation/doctor_dashboard_screen.dart';
import '../presentation/doctor_patients_screen.dart';
import '../presentation/prescription_screen.dart';
import '../presentation/patient_record_screen.dart';
import '../presentation/professional_schedule_screen.dart';
import '../presentation/professional_profile_screen.dart';
import '../../../modules/guidance/presentation/support_calls_screen.dart';
import '../../../modules/emergencies/presentation/professional_emergency_screen.dart';

RouteBase professionalRoutes(GlobalKey<NavigatorState> rootNavigatorKey) {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, shell) {
      final location = state.uri.path;
      final actionSelected =
          location.endsWith('/${AppRoutes.professionalProfile}') ||
          location.endsWith('/${AppRoutes.professionalSchedule}') ||
          location.endsWith('/help') ||
          location.endsWith('/consents') ||
          location.endsWith('/incidents');
      return AppShell(
        navigationShell: shell,
        selectedDestinationIndex: actionSelected ? -1 : null,
        destinations: const [
          ShellDestination(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: 'Inicio',
            location: AppRoutes.doctorHome,
          ),
          ShellDestination(
            icon: Icons.event_note_outlined,
            selectedIcon: Icons.event_note_rounded,
            label: 'Agenda',
            location: AppRoutes.doctorAgenda,
          ),
          ShellDestination(
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups_rounded,
            label: 'Pacientes',
            location: AppRoutes.doctorPatients,
          ),
          ShellDestination(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: 'Cuenta',
            location: AppRoutes.doctorProfile,
          ),
        ],
        actions: [
          const ShellAction.header('Menú profesional'),
          ShellAction(
            icon: Icons.medical_information_outlined,
            label: 'Perfil profesional',
            selected: location.endsWith('/${AppRoutes.professionalProfile}'),
            onTap: () => context.go(
              '${AppRoutes.doctorProfile}/${AppRoutes.professionalProfile}',
            ),
          ),
          ShellAction(
            icon: Icons.schedule_outlined,
            label: 'Disponibilidad',
            selected: location.endsWith('/${AppRoutes.professionalSchedule}'),
            onTap: () => context.go(
              '${AppRoutes.doctorAgenda}/${AppRoutes.professionalSchedule}',
            ),
          ),
          const ShellAction.header('Menú general'),
          ShellAction(
            icon: Icons.help_outline_rounded,
            label: 'Ayuda y demo',
            selected: location.endsWith('/help'),
            onTap: () => context.go('${AppRoutes.doctorProfile}/help'),
          ),
          ShellAction(
            icon: Icons.lock_outline_rounded,
            label: 'Privacidad',
            selected: location.endsWith('/consents'),
            onTap: () => context.go('${AppRoutes.doctorProfile}/consents'),
          ),
          ShellAction(
            icon: Icons.support_agent_rounded,
            label: 'Incidentes',
            selected: location.endsWith('/incidents'),
            onTap: () => context.go('${AppRoutes.doctorProfile}/incidents'),
          ),
        ],
      );
    },
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.doctorHome,
            builder: (_, __) => const DoctorDashboardScreen(),
            routes: [
              GoRoute(
                path: 'support-calls',
                builder: (_, state) => SupportCallsScreen(
                  callId: state.uri.queryParameters['callId'],
                ),
              ),
              GoRoute(
                path: 'emergency-cases',
                builder: (_, __) => const ProfessionalEmergencyScreen(),
              ),
              GoRoute(
                path: AppRoutes.clinicalNote,
                name: AppRoutes.clinicalNote,
                builder: (_, state) => ClinicalNoteScreen(
                  patientId: state.uri.queryParameters['patientId'] ?? '',
                  appointmentId:
                      state.uri.queryParameters['appointmentId'] ?? '',
                  patientName:
                      state.uri.queryParameters['patientName'] ?? 'Paciente',
                  age: int.tryParse(state.uri.queryParameters['age'] ?? ''),
                ),
              ),
              GoRoute(
                path: AppRoutes.prescription,
                name: AppRoutes.prescription,
                builder: (_, __) => const PrescriptionScreen(),
              ),
              GoRoute(
                path: AppRoutes.teleconsult,
                name: AppRoutes.teleconsult,
                builder: (_, __) => const TelemedicineScreen(),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.doctorAgenda,
            builder: (_, __) => const DoctorAgendaScreen(),
            routes: [
              GoRoute(
                path: AppRoutes.professionalSchedule,
                name: AppRoutes.professionalSchedule,
                builder: (_, __) => const ProfessionalScheduleScreen(),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.doctorPatients,
            builder: (_, __) => const DoctorPatientsScreen(),
            routes: [
              GoRoute(
                path: AppRoutes.professionalPatientRecord,
                name: AppRoutes.professionalPatientRecord,
                builder: (_, state) => PatientRecordScreen(
                  patientId: state.uri.queryParameters['patientId'] ?? '',
                  appointmentId: state.uri.queryParameters['appointmentId'],
                ),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.doctorProfile,
            builder: (_, __) => const AccountScreen(),
            routes: [
              GoRoute(
                path: AppRoutes.professionalProfile,
                name: AppRoutes.professionalProfile,
                builder: (_, __) => const ProfessionalProfileScreen(),
              ),
              GoRoute(path: 'help', builder: (_, __) => const HelpScreen()),
              GoRoute(
                path: 'consents',
                builder: (_, __) => const ConsentsScreen(),
              ),
              GoRoute(
                path: 'incidents',
                builder: (_, __) => const IncidentsScreen(),
              ),
              GoRoute(
                path: 'catalog',
                builder: (_, __) => const CatalogScreen(),
              ),
              GoRoute(path: 'coins', builder: (_, __) => const CoinsScreen()),
              GoRoute(
                path: 'benefits',
                builder: (_, __) => const BenefitsScreen(),
              ),
              GoRoute(
                path: 'payments',
                builder: (_, __) => const PaymentsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
