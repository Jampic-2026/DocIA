import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/appointments/application/appointments_controller.dart';
import '../../../modules/appointments/domain/appointment.dart';
import '../../../modules/auth/application/auth_controller.dart';
import '../../../modules/human_resources/application/human_resources_controller.dart';
import '../../../modules/human_resources/domain/staff_member.dart';
import '../../../modules/partners/application/partners_controller.dart';
import '../../../modules/partners/domain/partner_summary.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final staff = ref.watch(staffProvider);
    final partners = ref.watch(partnersProvider);
    final appointments = ref.watch(appointmentsControllerProvider);
    final staffItems = staff.valueOrNull ?? const <StaffMember>[];
    final partnerItems = partners.valueOrNull ?? const <PartnerSummary>[];
    final appointmentItems = appointments.valueOrNull ?? const <Appointment>[];
    final now = DateTime.now();
    final monthAppointments = appointmentItems
        .where(
          (appointment) =>
              appointment.startAt.toLocal().year == now.year &&
              appointment.startAt.toLocal().month == now.month &&
              appointment.status != AppointmentStatus.cancelled &&
              appointment.status != AppointmentStatus.noShow,
        )
        .length;
    final verifiedProfessionals = staffItems
        .where((member) => member.verificationStatus == 'approved')
        .length;
    final pendingProfessionals = staffItems.length - verifiedProfessionals;
    final activePartners = partnerItems
        .where((partner) => partner.isActive)
        .length;
    final isLoading =
        staff.isLoading || partners.isLoading || appointments.isLoading;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(staffProvider);
          ref.invalidate(partnersProvider);
          await ref.read(appointmentsControllerProvider.notifier).refresh();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(
              subtitle: 'Panel administrativo',
              title: user?.firstName ?? 'Admin',
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.navyDark, AppColors.navyLight],
              ),
              trailing: GestureDetector(
                onTap: () => context.go(AppRoutes.adminProfile),
                child: UserAvatar(name: user?.displayName ?? 'A', radius: 22),
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
                  const SectionHeader(title: 'Resumen general'),
                  const SizedBox(height: AppSpacing.md),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          mainAxisExtent: 158,
                          mainAxisSpacing: AppSpacing.md,
                          crossAxisSpacing: AppSpacing.md,
                        ),
                    itemCount: 4,
                    itemBuilder: (context, index) => [
                      StatCard(
                        value: isLoading ? '—' : '${staffItems.length}',
                        label: 'Personal registrado',
                        icon: Icons.people_alt_rounded,
                        color: AppColors.blue,
                      ),
                      StatCard(
                        value: isLoading ? '—' : '$monthAppointments',
                        label: 'Consultas (mes)',
                        icon: Icons.event_note_rounded,
                        color: AppColors.teal,
                      ),
                      StatCard(
                        value: isLoading ? '—' : '$activePartners',
                        label: 'Empresas activas',
                        icon: Icons.business_rounded,
                        color: AppColors.navy,
                      ),
                      StatCard(
                        value: isLoading ? '—' : '$verifiedProfessionals',
                        label: 'Profesionales validados',
                        icon: Icons.medical_services_rounded,
                        color: AppColors.tealDark,
                      ),
                    ][index],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(
                    title: 'Actividad semanal',
                    subtitle: 'Consultas por día',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    child: appointments.hasError
                        ? _InlineError(
                            message: appointments.error.toString(),
                            onRetry: () => ref
                                .read(appointmentsControllerProvider.notifier)
                                .refresh(),
                          )
                        : appointments.isLoading
                        ? const SizedBox(
                            height: 140,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _WeeklyAppointmentsChart(
                            appointments: appointmentItems,
                            today: now,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Gestión',
                    actionLabel: 'Ver',
                    onAction: () => context.go(AppRoutes.adminManagement),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ActionRow(
                    icon: Icons.verified_user_rounded,
                    color: AppColors.teal,
                    title: 'Validación de profesionales',
                    subtitle: staff.hasError
                        ? 'No se pudo cargar el personal'
                        : staff.isLoading
                        ? 'Consultando solicitudes'
                        : '$pendingProfessionals pendientes',
                    onTap: () => context.go(AppRoutes.adminManagement),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ActionRow(
                    icon: Icons.business_rounded,
                    color: AppColors.blue,
                    title: 'Empresas médicas asociadas',
                    subtitle: partners.hasError
                        ? 'No se pudieron cargar las empresas'
                        : partners.isLoading
                        ? 'Consultando empresas'
                        : '$activePartners empresas activas',
                    onTap: () => context.go(AppRoutes.adminManagement),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ActionRow(
                    icon: Icons.fact_check_rounded,
                    color: AppColors.navy,
                    title: 'Auditoría de operaciones',
                    subtitle: 'Consultar eventos registrados',
                    onTap: () =>
                        context.go('${AppRoutes.adminManagement}?tab=audit'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ActionRow(
                    icon: Icons.emergency_rounded,
                    color: AppColors.danger,
                    title: 'Operación de emergencias',
                    subtitle: 'Revisar solicitudes activas y asignaciones',
                    onTap: () => context.go(
                      '${AppRoutes.adminManagement}?tab=emergencies',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
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
}

class _WeeklyAppointmentsChart extends StatelessWidget {
  const _WeeklyAppointmentsChart({
    required this.appointments,
    required this.today,
  });

  final List<Appointment> appointments;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final end = DateTime(today.year, today.month, today.day);
    final days = List.generate(
      7,
      (index) => end.subtract(Duration(days: 6 - index)),
    );
    final values = days.map((day) {
      return appointments.where((appointment) {
        final date = appointment.startAt.toLocal();
        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day &&
            appointment.status != AppointmentStatus.cancelled &&
            appointment.status != AppointmentStatus.noShow;
      }).length;
    }).toList();
    final maximum = values.fold<int>(
      0,
      (current, value) => value > current ? value : current,
    );

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < days.length; index++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${values[index]}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: maximum == 0
                        ? 4
                        : 100 * (values[index] / maximum).clamp(0.04, 1),
                    decoration: BoxDecoration(
                      gradient: AppColors.tealGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat(
                      'E',
                      'es',
                    ).format(days[index]).substring(0, 1).toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
