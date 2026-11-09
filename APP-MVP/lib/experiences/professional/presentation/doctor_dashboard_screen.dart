import 'package:flutter/material.dart';
import '../../../modules/guidance/presentation/support_calls_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/authorization/permission_codes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/appointments/application/appointments_controller.dart';
import '../../../modules/appointments/domain/appointment.dart';
import '../../../modules/auth/application/auth_controller.dart';
import '../../patient/presentation/widgets/appointment_card.dart';
import '../../../modules/emergencies/presentation/professional_emergency_screen.dart';
import '../../../modules/work_shifts/presentation/work_shifts_screen.dart';

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final isNurse = user?.hasRole('nurse') ?? false;
    final roleLabel = isNurse
        ? 'Enfermería'
        : (user?.hasRole('doctor_specialist') ?? false)
        ? 'Médico especialista'
        : 'Médico general';
    final canPrescribe =
        user?.can(PermissionCodes.prescriptionsManage) ?? false;
    final appointments = ref.watch(appointmentsControllerProvider);
    final now = DateTime.now();
    final today = _appointmentsForDay(
      appointments.valueOrNull ?? const [],
      now,
    );
    final teleconsultations = today
        .where(
          (appointment) =>
              appointment.modality == AppointmentModality.telemedicine,
        )
        .length;
    final pending = today.where(_isPending).length;
    final noteAppointment = today.where(_canCreateNote).firstOrNull;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(appointmentsControllerProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(
              subtitle: 'Bienvenido',
              title: user?.firstName ?? 'Profesional',
              trailing: GestureDetector(
                onTap: () => context.go(AppRoutes.doctorProfile),
                child: UserAvatar(name: user?.displayName ?? 'D', radius: 22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${user?.specialty ?? 'Profesional de salud'} · $roleLabel',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const StatusPill(
                    label: 'Validado',
                    color: AppColors.tealLight,
                    icon: Icons.verified_rounded,
                    dense: true,
                  ),
                ],
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = _dashboardColumns(
                            constraints.maxWidth,
                          );
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: columns,
                            mainAxisSpacing: AppSpacing.md,
                            crossAxisSpacing: AppSpacing.md,
                            childAspectRatio: columns == 1 ? 2.4 : 2.0,
                            children: [
                              StatCard(
                                value: appointments.isLoading
                                    ? '-'
                                    : '${today.length}',
                                label: 'Citas hoy',
                                icon: Icons.event_available_rounded,
                                color: AppColors.blue,
                              ),
                              StatCard(
                                value: appointments.isLoading
                                    ? '-'
                                    : '$teleconsultations',
                                label: 'Teleconsultas',
                                icon: Icons.videocam_rounded,
                                color: AppColors.teal,
                              ),
                              StatCard(
                                value: appointments.isLoading
                                    ? '-'
                                    : '$pending',
                                label: 'Pendientes',
                                icon: Icons.pending_actions_rounded,
                                color: AppColors.warning,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SectionHeader(title: 'Acciones'),
                      const SizedBox(height: AppSpacing.md),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = _dashboardColumns(
                            constraints.maxWidth,
                          );
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: columns,
                            mainAxisSpacing: AppSpacing.md,
                            crossAxisSpacing: AppSpacing.md,
                            childAspectRatio: columns == 1 ? 3.6 : 2.5,
                            children: [
                              QuickActionTile(
                                icon: Icons.note_add_rounded,
                                label: 'Nota clínica',
                                color: AppColors.blue,
                                onTap: () =>
                                    _openClinicalNote(context, noteAppointment),
                              ),
                              QuickActionTile(
                                icon: Icons.emergency_outlined,
                                label: 'Casos asignados',
                                color: AppColors.warning,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const ProfessionalEmergencyScreen(),
                                  ),
                                ),
                              ),
                              if (isNurse)
                                QuickActionTile(
                                  icon: Icons.schedule,
                                  label: 'Mis turnos',
                                  color: AppColors.blue,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const WorkShiftsScreen(),
                                    ),
                                  ),
                                ),
                              if (canPrescribe)
                                QuickActionTile(
                                  icon: Icons.receipt_long_rounded,
                                  label: 'Receta',
                                  color: AppColors.teal,
                                  onTap: () =>
                                      context.pushNamed(AppRoutes.prescription),
                                ),
                              QuickActionTile(
                                icon: Icons.video_call_rounded,
                                label: 'Teleconsulta',
                                color: AppColors.tealDark,
                                onTap: () =>
                                    context.pushNamed(AppRoutes.teleconsult),
                              ),
                              QuickActionTile(
                                icon: Icons.support_agent_rounded,
                                label: 'Llamadas de orientación asignadas',
                                color: AppColors.blue,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const SupportCallsScreen(),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SectionHeader(
                        title: 'Agenda de hoy',
                        subtitle: DateFormat('EEEE d MMMM', 'es').format(now),
                        actionLabel: 'Ver',
                        onAction: () => context.go(AppRoutes.doctorAgenda),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (appointments.hasError)
                        AppErrorState(
                          message: appointments.error.toString(),
                          onRetry: () => ref
                              .read(appointmentsControllerProvider.notifier)
                              .refresh(),
                        )
                      else if (appointments.isLoading)
                        const AppLoadingState(message: 'Cargando agenda')
                      else if (today.isEmpty)
                        const EmptyState(
                          icon: Icons.event_available_rounded,
                          title: 'Sin citas para hoy',
                          message: 'Las consultas programadas aparecerán aquí.',
                        )
                      else
                        for (final appointment in today.take(3)) ...[
                          AppointmentCard(
                            appointment: appointment,
                            showPatient: true,
                            onTap: _canCreateNote(appointment)
                                ? () => _openClinicalNote(context, appointment)
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<Appointment> _appointmentsForDay(
    List<Appointment> appointments,
    DateTime day,
  ) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return appointments
        .where(
          (appointment) =>
              !appointment.startAt.toLocal().isBefore(start) &&
              appointment.startAt.toLocal().isBefore(end) &&
              appointment.status != AppointmentStatus.cancelled &&
              appointment.status != AppointmentStatus.noShow,
        )
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  static bool _isPending(Appointment appointment) =>
      appointment.status == AppointmentStatus.scheduled ||
      appointment.status == AppointmentStatus.confirmed ||
      appointment.status == AppointmentStatus.rescheduled;

  static bool _canCreateNote(Appointment appointment) =>
      appointment.status == AppointmentStatus.inProgress ||
      appointment.status == AppointmentStatus.completed;

  static int _dashboardColumns(double width) {
    if (width >= 860) return 3;
    if (width >= 560) return 2;
    return 1;
  }

  static void _openClinicalNote(
    BuildContext context,
    Appointment? appointment,
  ) {
    if (appointment == null) {
      context.go(AppRoutes.doctorPatients);
      return;
    }
    context.pushNamed(
      AppRoutes.clinicalNote,
      queryParameters: {
        'patientId': appointment.patientId,
        'appointmentId': appointment.id,
        'patientName': appointment.patientName,
      },
    );
  }
}
