import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/responsive/adaptive_page.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/appointments/application/appointments_controller.dart';
import '../../../modules/appointments/domain/appointment.dart';
import '../../../modules/auth/application/auth_controller.dart';
import '../../patient/presentation/widgets/appointment_card.dart';

/// Agenda profesional con calendario mensual y citas del día seleccionado.
class DoctorAgendaScreen extends ConsumerStatefulWidget {
  const DoctorAgendaScreen({super.key});

  @override
  ConsumerState<DoctorAgendaScreen> createState() => _DoctorAgendaScreenState();
}

class _DoctorAgendaScreenState extends ConsumerState<DoctorAgendaScreen> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final appointments = ref.watch(appointmentsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi agenda'),
        actions: [
          IconButton(
            tooltip: 'Configurar disponibilidad',
            onPressed: () => context.pushNamed(AppRoutes.professionalSchedule),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: appointments.when(
        loading: () => const AppLoadingState(message: 'Cargando tu agenda'),
        error: (error, _) => AppErrorState(
          message: error.toString(),
          onRetry: () =>
              ref.read(appointmentsControllerProvider.notifier).refresh(),
        ),
        data: (items) {
          final monthAppointments = _appointmentsForMonth(items, _visibleMonth);
          final selectedAppointments = _appointmentsForDay(items, _selectedDay);
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(appointmentsControllerProvider.notifier).refresh(),
            child: AdaptivePage(
              maxWidth: 1180,
              children: [
                _MonthlyCalendar(
                  visibleMonth: _visibleMonth,
                  selectedDay: _selectedDay,
                  appointments: monthAppointments,
                  onPreviousMonth: () => _changeMonth(-1),
                  onNextMonth: () => _changeMonth(1),
                  onDaySelected: _selectDay,
                ),
                SectionHeader(
                  title: 'Citas del día',
                  subtitle: DateFormat(
                    'EEEE d MMMM y',
                    'es',
                  ).format(_selectedDay),
                ),
                if (selectedAppointments.isEmpty)
                  const EmptyState(
                    icon: Icons.event_available_rounded,
                    title: 'Sin citas',
                    message: 'No tienes consultas programadas para este día.',
                  )
                else
                  for (final appointment in selectedAppointments) ...[
                    AppointmentCard(
                      appointment: appointment,
                      showPatient: true,
                      onTap: () => _openClinicalNote(context, appointment),
                      trailing: _AppointmentActions(appointment: appointment),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      final daysInMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + 1,
        0,
      ).day;
      final selectedDay = _selectedDay.day.clamp(1, daysInMonth).toInt();
      _selectedDay = DateTime(
        _visibleMonth.year,
        _visibleMonth.month,
        selectedDay,
      );
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = DateTime(day.year, day.month, day.day);
    });
  }

  static List<Appointment> _appointmentsForMonth(
    List<Appointment> appointments,
    DateTime month,
  ) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return appointments
        .where(
          (appointment) =>
              !appointment.startAt.toLocal().isBefore(start) &&
              appointment.startAt.toLocal().isBefore(end),
        )
        .toList();
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
              appointment.startAt.toLocal().isBefore(end),
        )
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  static void _openClinicalNote(BuildContext context, Appointment appointment) {
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

class _MonthlyCalendar extends StatelessWidget {
  const _MonthlyCalendar({
    required this.visibleMonth,
    required this.selectedDay,
    required this.appointments,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDaySelected,
  });

  final DateTime visibleMonth;
  final DateTime selectedDay;
  final List<Appointment> appointments;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM y', 'es').format(visibleMonth);
    final weeks = _monthCells(visibleMonth);
    final counts = _appointmentCounts(appointments);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  _capitalize(monthLabel),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: const [
              _WeekdayLabel('L'),
              _WeekdayLabel('M'),
              _WeekdayLabel('M'),
              _WeekdayLabel('J'),
              _WeekdayLabel('V'),
              _WeekdayLabel('S'),
              _WeekdayLabel('D'),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final week in weeks)
            Row(
              children: [
                for (final day in week)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: _CalendarDay(
                        day: day,
                        visibleMonth: visibleMonth,
                        selected: _sameDate(day, selectedDay),
                        appointments: counts[_dateKey(day)] ?? 0,
                        onTap: () => onDaySelected(day),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static Map<String, int> _appointmentCounts(List<Appointment> appointments) {
    final counts = <String, int>{};
    for (final appointment in appointments) {
      final local = appointment.startAt.toLocal();
      final key = _dateKey(DateTime(local.year, local.month, local.day));
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  static List<List<DateTime>> _monthCells(DateTime month) {
    final first = DateTime(month.year, month.month);
    final daysBefore = first.weekday - DateTime.monday;
    final gridStart = first.subtract(Duration(days: daysBefore));
    return [
      for (var week = 0; week < 6; week++)
        [
          for (var day = 0; day < 7; day++)
            gridStart.add(Duration(days: (week * 7) + day)),
        ],
    ];
  }

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.visibleMonth,
    required this.selected,
    required this.appointments,
    required this.onTap,
  });

  final DateTime day;
  final DateTime visibleMonth;
  final bool selected;
  final int appointments;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = day.month != visibleMonth.month;
    final today = _sameDate(day, DateTime.now());
    final background = selected
        ? AppColors.teal
        : today
        ? AppColors.teal.withValues(alpha: 0.12)
        : Colors.transparent;
    final foreground = selected
        ? AppColors.white
        : muted
        ? scheme.onSurfaceVariant.withValues(alpha: 0.55)
        : scheme.onSurface;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected
                  ? AppColors.teal
                  : scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  color: foreground,
                  fontWeight: selected || today
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 16,
                child: appointments == 0
                    ? const SizedBox.shrink()
                    : _AppointmentCountBadge(
                        count: appointments,
                        selected: selected,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _AppointmentCountBadge extends StatelessWidget {
  const _AppointmentCountBadge({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.white : AppColors.blue;
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          color: color,
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AppointmentActions extends ConsumerWidget {
  const _AppointmentActions({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTele = appointment.modality == AppointmentModality.telemedicine;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (appointment.endAt.isBefore(DateTime.now()) &&
            [
              AppointmentStatus.scheduled,
              AppointmentStatus.confirmed,
              AppointmentStatus.rescheduled,
            ].contains(appointment.status) &&
            ((ref
                        .watch(authControllerProvider)
                        .user
                        ?.hasRole('doctor_general') ??
                    false) ||
                (ref
                        .watch(authControllerProvider)
                        .user
                        ?.hasRole('doctor_specialist') ??
                    false)))
          IconButton(
            tooltip: 'Registrar inasistencia',
            icon: const Icon(Icons.person_off_outlined),
            onPressed: () => _noShow(context, ref),
          ),
        IconButton(
          tooltip: 'Nota clínica',
          onPressed: () => context.pushNamed(
            AppRoutes.clinicalNote,
            queryParameters: {
              'patientId': appointment.patientId,
              'appointmentId': appointment.id,
              'patientName': appointment.patientName,
            },
          ),
          icon: const Icon(Icons.note_add_rounded),
        ),
        if (isTele)
          IconButton.filled(
            tooltip: 'Iniciar teleconsulta',
            onPressed: () => context.pushNamed(AppRoutes.teleconsult),
            icon: const Icon(Icons.videocam_rounded),
            style: IconButton.styleFrom(backgroundColor: AppColors.teal),
          ),
      ],
    );
  }

  Future<void> _noShow(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    final form = GlobalKey<FormState>();
    final accepted = await showAppDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Registrar inasistencia'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: reason,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Motivo verificable'),
            validator: (value) =>
                (value?.trim().length ?? 0) < 3 ? 'Registra el motivo.' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialog, true);
              }
            },
            child: const Text('Confirmar inasistencia'),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (accepted != true) {
      return;
    }
    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .markNoShow(appointment.id, reason: text);
      await ref.read(appointmentsControllerProvider.notifier).refresh();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}
