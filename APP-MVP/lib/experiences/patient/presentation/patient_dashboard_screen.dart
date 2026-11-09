import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../modules/auth/application/auth_controller.dart';
import '../../../modules/appointments/application/appointments_controller.dart';
import '../../../modules/appointments/domain/appointment.dart';
import '../../../modules/clinical_records/application/clinical_records_controller.dart';
import '../../../modules/notifications/application/notifications_controller.dart';
import 'widgets/patient_home_widgets.dart';

/// Inicio del paciente orientado a sus tres acciones prioritarias.
class PatientDashboardScreen extends ConsumerWidget {
  const PatientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).user;
    final clinicalProfile = ref.watch(clinicalProfileProvider).valueOrNull;
    final notifications = ref.watch(notificationsControllerProvider).valueOrNull;
    final appointments = ref.watch(appointmentsControllerProvider).valueOrNull;
    final unreadNotifications =
        notifications
            ?.where((notification) => !notification.isRead)
            .length ??
        0;
    final nextAppointment = _nextAppointment(appointments);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide =
              constraints.maxWidth >= AppDimensions.expandedBreakpoint;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 1180 : 760),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  PatientHomeHeader(
                    greeting: _greeting(DateTime.now()),
                    patientName: user?.firstName ?? 'Paciente',
                    unreadNotifications: unreadNotifications,
                    profile: clinicalProfile,
                    showMoreOptions: !isWide,
                    onNotificationsTap: () =>
                        context.push(AppRoutes.patientNotifications),
                    onMenuSelected: (option) =>
                        _openMenuOption(context, option),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isWide ? AppSpacing.xxl : AppSpacing.lg,
                      AppSpacing.xl,
                      isWide ? AppSpacing.xxl : AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _PatientActionSection(
                                  onEmergency: () =>
                                      context.pushNamed(AppRoutes.emergency),
                                  onSchedule: () => context.pushNamed(
                                    AppRoutes.doctorDirectory,
                                  ),
                                  onAssistant: () =>
                                      context.go(AppRoutes.patientAssistant),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xl),
                              Expanded(
                                flex: 2,
                                child: PatientNextAppointmentSection(
                                  appointment: nextAppointment,
                                  onViewAppointment: nextAppointment == null
                                      ? null
                                      : () => context.pushNamed(
                                            AppRoutes.appointmentDetail,
                                            queryParameters: {
                                              'id': nextAppointment.id,
                                            },
                                          ),
                                  onScheduleAppointment: () =>
                                      context.pushNamed(
                                    AppRoutes.doctorDirectory,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PatientActionSection(
                                onEmergency: () =>
                                    context.pushNamed(AppRoutes.emergency),
                                onSchedule: () => context.pushNamed(
                                  AppRoutes.doctorDirectory,
                                ),
                                onAssistant: () =>
                                    context.go(AppRoutes.patientAssistant),
                              ),
                              const SizedBox(height: AppSpacing.xxl),
                              PatientNextAppointmentSection(
                                appointment: nextAppointment,
                                onViewAppointment: nextAppointment == null
                                    ? null
                                    : () => context.pushNamed(
                                          AppRoutes.appointmentDetail,
                                          queryParameters: {
                                            'id': nextAppointment.id,
                                          },
                                        ),
                                onScheduleAppointment: () => context.pushNamed(
                                  AppRoutes.doctorDirectory,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Appointment? _nextAppointment(List<Appointment>? appointments) {
    if (appointments == null) return null;
    final valid = appointments
        .where(
          (appointment) =>
              appointment.startAt.isAfter(DateTime.now()) &&
              !const {
                AppointmentStatus.cancelled,
                AppointmentStatus.completed,
                AppointmentStatus.noShow,
              }.contains(appointment.status),
        )
        .toList()
      ..sort((first, second) => first.startAt.compareTo(second.startAt));
    return valid.isEmpty ? null : valid.first;
  }

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Buenos días';
    if (now.hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  void _openMenuOption(BuildContext context, PatientHomeMenuOption option) {
    switch (option) {
      case PatientHomeMenuOption.clinicalProfile:
        context.pushNamed(AppRoutes.clinicalProfile);
        return;
      case PatientHomeMenuOption.family:
        context.pushNamed(AppRoutes.family);
        return;
      case PatientHomeMenuOption.prescriptions:
        context.pushNamed(AppRoutes.patientPrescriptions);
        return;
    }
  }
}

class _PatientActionSection extends StatelessWidget {
  const _PatientActionSection({
    required this.onEmergency,
    required this.onSchedule,
    required this.onAssistant,
  });

  final VoidCallback onEmergency;
  final VoidCallback onSchedule;
  final VoidCallback onAssistant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Qué necesitas hoy?',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Elige una acción principal',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryPatientActionCard(
          title: 'EMERGENCIA MÉDICA',
          description: 'Necesito atención inmediata',
          icon: Icons.sos_rounded,
          color: AppColors.danger,
          onTap: onEmergency,
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryPatientActionCard(
          title: 'AGENDAR CONSULTA',
          description: 'Quiero hablar con un médico',
          icon: Icons.calendar_month_rounded,
          color: AppColors.warning,
          foregroundColor: AppColors.navyDark,
          onTap: onSchedule,
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryPatientActionCard(
          title: 'HABLAR CON DOC IA',
          description: 'Orientación inicial de síntomas',
          icon: Icons.smart_toy_rounded,
          color: AppColors.success,
          onTap: onAssistant,
        ),
      ],
    );
  }
}
