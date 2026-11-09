import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/appointments/application/appointments_controller.dart';
import '../../../modules/appointments/domain/appointment.dart';
import '../../../modules/appointments/domain/appointment_care_actions.dart';
import '../../../modules/appointments/presentation/appointment_presentation.dart';
import '../../../modules/telemedicine/application/telemedicine_controller.dart';
import '../../../modules/telemedicine/domain/telemedicine_room.dart';
import '../../../modules/professionals/application/professionals_controller.dart';
import '../../../modules/professionals/domain/professional.dart';

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  const AppointmentDetailScreen({required this.appointmentId, super.key});

  final String appointmentId;

  @override
  ConsumerState<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState
    extends ConsumerState<AppointmentDetailScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final appointments = ref.watch(appointmentsControllerProvider);
    final appointment = _findAppointment(appointments.valueOrNull);
    if (appointments.isLoading && appointment == null) {
      return const Scaffold(body: AppLoadingState(message: 'Cargando la cita'));
    }
    if (appointments.hasError && appointment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de la cita')),
        body: AppErrorState(
          message: appointments.error.toString(),
          onRetry: () =>
              ref.read(appointmentsControllerProvider.notifier).refresh(),
        ),
      );
    }
    if (appointment == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.event_busy_outlined,
          title: 'Cita no encontrada',
          message: 'La cita ya no está disponible para esta cuenta.',
        ),
      );
    }

    final canModify = _canModify(appointment);
    final careActions = ref.watch(appointmentCareActionsProvider).valueOrNull;
    final alreadyRated =
        careActions?.ratings.any(
          (item) => item.appointmentId == appointment.id,
        ) ??
        false;
    final room = _findRoom(
      ref.watch(telemedicineRoomsProvider).valueOrNull,
      appointment.id,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la cita')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Column(
              children: [
                UserAvatar(name: appointment.professionalName, radius: 38),
                const SizedBox(height: AppSpacing.md),
                Text(
                  appointment.professionalName,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(appointment.specialty),
                const SizedBox(height: AppSpacing.md),
                StatusPill(
                  label: appointment.status.label,
                  color: appointment.status.color,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Fecha',
                  value: DateFormat(
                    "EEEE d 'de' MMMM 'de' y",
                    'es_BO',
                  ).format(appointment.startAt),
                ),
                _DetailRow(
                  icon: Icons.schedule_outlined,
                  label: 'Horario',
                  value:
                      '${DateFormat('HH:mm').format(appointment.startAt)} – '
                      '${DateFormat('HH:mm').format(appointment.endAt)}',
                ),
                _DetailRow(
                  icon: appointment.modality.icon,
                  label: 'Modalidad',
                  value: appointment.modality.label,
                ),
                _DetailRow(
                  icon: Icons.notes_outlined,
                  label: 'Motivo',
                  value: appointment.reason?.trim().isNotEmpty == true
                      ? appointment.reason!
                      : 'No especificado',
                  showDivider: false,
                ),
              ],
            ),
          ),
          if (appointment.modality == AppointmentModality.telemedicine) ...[
            const SizedBox(height: AppSpacing.lg),
            _TelemedicineAction(
              room: room,
              enabled: _canJoin(appointment),
              onJoin: room == null ? null : () => _join(room),
            ),
          ],
          if (canModify) ...[
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: _saving ? null : () => _reschedule(appointment),
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Reprogramar cita'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _cancel(appointment),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
              icon: const Icon(Icons.event_busy_outlined),
              label: const Text('Cancelar cita'),
            ),
          ],
          if (appointment.status == AppointmentStatus.completed) ...[
            const SizedBox(height: AppSpacing.lg),
            if (!alreadyRated)
              OutlinedButton.icon(
                onPressed: () => _rate(appointment),
                icon: const Icon(Icons.star_outline_rounded),
                label: const Text('Calificar atención'),
              ),
            ...?careActions?.followups
                .where((item) => item.sourceAppointmentId == appointment.id)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: _FollowupCard(followup: item),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Appointment? _findAppointment(List<Appointment>? items) {
    for (final appointment in items ?? const <Appointment>[]) {
      if (appointment.id == widget.appointmentId) return appointment;
    }
    return null;
  }

  TelemedicineRoom? _findRoom(
    List<TelemedicineRoom>? rooms,
    String appointmentId,
  ) {
    for (final room in rooms ?? const <TelemedicineRoom>[]) {
      if (room.appointmentId == appointmentId) return room;
    }
    return null;
  }

  bool _canModify(Appointment appointment) =>
      appointment.startAt.isAfter(DateTime.now()) &&
      const {
        AppointmentStatus.scheduled,
        AppointmentStatus.confirmed,
        AppointmentStatus.rescheduled,
      }.contains(appointment.status);

  bool _canJoin(Appointment appointment) => !const {
    AppointmentStatus.cancelled,
    AppointmentStatus.completed,
    AppointmentStatus.noShow,
  }.contains(appointment.status);

  Future<void> _join(TelemedicineRoom room) async {
    try {
      await ref.read(telemedicineRepositoryProvider).registerJoin(room.id);
      final opened = await launchUrl(
        Uri.parse(room.meetingUrl),
        mode: LaunchMode.platformDefault,
      );
      if (!opened) throw Exception('No se pudo abrir Google Meet.');
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _cancel(Appointment appointment) async {
    final reason = TextEditingController();
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: AppTextField(
          controller: reason,
          label: 'Motivo (opcional)',
          maxLines: 3,
        ),
        actions: [
          SizedBox(
            width: 420,
            child: AppDialogActions(
              cancelLabel: 'Volver',
              confirmLabel: 'Confirmar cancelación',
              onCancel: () => Navigator.pop(dialogContext, false),
              onConfirm: () => Navigator.pop(dialogContext, true),
            ),
          ),
        ],
      ),
    );
    final value = reason.text;
    reason.dispose();
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(appointmentsControllerProvider.notifier)
          .cancel(appointment.id, reason: value);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('La cita fue cancelada.')));
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reschedule(Appointment appointment) async {
    final duration = appointment.endAt.difference(appointment.startAt);
    List<Professional> professionals;
    try {
      professionals = await ref.read(professionalDirectoryProvider.future);
    } catch (error) {
      if (mounted) _showError(error);
      return;
    }
    Professional? professional;
    for (final item in professionals) {
      if (item.id == appointment.professionalId) {
        professional = item;
        break;
      }
    }
    if (professional == null || !mounted) {
      if (mounted) {
        _showError('El profesional ya no tiene disponibilidad publicada.');
      }
      return;
    }
    final options = _availableStarts(
      professional.availability,
      appointment.modality,
      duration,
    );
    if (options.isEmpty) {
      _showError('No existen horarios disponibles para reprogramar.');
      return;
    }
    final startAt = await showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Selecciona un nuevo horario',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final option in options)
            ListTile(
              leading: const Icon(
                Icons.event_available_outlined,
                color: AppColors.teal,
              ),
              title: Text(
                DateFormat("EEEE d 'de' MMMM", 'es_BO').format(option),
              ),
              subtitle: Text(DateFormat('HH:mm').format(option)),
              onTap: () => Navigator.pop(sheetContext, option),
            ),
        ],
      ),
    );
    if (startAt == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(appointmentsControllerProvider.notifier)
          .reschedule(
            appointment.id,
            startAt: startAt,
            endAt: startAt.add(duration),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La cita fue reprogramada.')),
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _rate(Appointment appointment) async {
    var rating = 5;
    var publicComment = false;
    final comment = TextEditingController();
    final accepted = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Calificar atención'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    onPressed: () => setState(() => rating = index + 1),
                    icon: Icon(
                      index < rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ),
              AppTextField(
                controller: comment,
                label: 'Comentario (opcional)',
                maxLines: 3,
              ),
              CheckboxListTile(
                value: publicComment,
                title: const Text('Publicar mi comentario de forma anónima'),
                subtitle: const Text(
                  'Evita incluir datos personales o información médica.',
                ),
                onChanged: (value) =>
                    setState(() => publicComment = value ?? false),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: 420,
              child: AppDialogActions(
                cancelLabel: 'Cancelar',
                confirmLabel: 'Enviar',
                onCancel: () => Navigator.pop(dialogContext, false),
                onConfirm: () => Navigator.pop(dialogContext, true),
              ),
            ),
          ],
        ),
      ),
    );
    final value = comment.text.trim();
    comment.dispose();
    if (accepted != true) return;
    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .rate(
            appointment.id,
            rating: rating,
            comment: value,
            publicComment: publicComment,
          );
      ref.invalidate(appointmentCareActionsProvider);
      ref.invalidate(professionalDirectoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gracias por calificar tu atención.')),
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  List<DateTime> _availableStarts(
    List<ProfessionalAvailability> availability,
    AppointmentModality modality,
    Duration duration,
  ) {
    final modalityCode = switch (modality) {
      AppointmentModality.telemedicine => 'telemedicine',
      AppointmentModality.homeVisit => 'home_visit',
      AppointmentModality.inPerson => 'in_person',
    };
    final now = DateTime.now();
    final result = <DateTime>[];
    for (var dayOffset = 0; dayOffset < 30 && result.length < 40; dayOffset++) {
      final day = DateTime(now.year, now.month, now.day + dayOffset);
      final weekday = day.weekday == DateTime.sunday ? 0 : day.weekday;
      for (final window in availability.where(
        (item) => item.weekday == weekday && item.modality == modalityCode,
      )) {
        final startParts = window.startTime.split(':').map(int.parse).toList();
        final endParts = window.endTime.split(':').map(int.parse).toList();
        var cursor = DateTime(
          day.year,
          day.month,
          day.day,
          startParts[0],
          startParts[1],
        );
        final windowEnd = DateTime(
          day.year,
          day.month,
          day.day,
          endParts[0],
          endParts[1],
        );
        while (!cursor.add(duration).isAfter(windowEnd) && result.length < 40) {
          if (cursor.isAfter(now)) result.add(cursor);
          cursor = cursor.add(const Duration(minutes: 30));
        }
      }
    }
    return result;
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

class _FollowupCard extends StatelessWidget {
  const _FollowupCard({required this.followup});
  final AppointmentFollowup followup;
  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.teal.withValues(alpha: 0.08),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.event_repeat_rounded, color: AppColors.teal),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Seguimiento recomendado',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          followup.instructions?.isNotEmpty == true
              ? followup.instructions!
              : 'Agenda un control según la indicación profesional.',
        ),
        if (followup.dueAt != null)
          Text(
            'Fecha sugerida: ${DateFormat('d MMMM y', 'es_BO').format(followup.dueAt!)}',
          ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: AppColors.teal),
          title: Text(label),
          subtitle: Text(value),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

class _TelemedicineAction extends StatelessWidget {
  const _TelemedicineAction({
    required this.room,
    required this.enabled,
    required this.onJoin,
  });

  final TelemedicineRoom? room;
  final bool enabled;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.teal.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Telemedicina',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            room == null
                ? 'El profesional todavía no preparó la sala.'
                : 'La sala de Google Meet está disponible.',
          ),
          if (room != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: enabled ? onJoin : null,
                icon: const Icon(Icons.video_call_rounded),
                label: const Text('Ingresar a Google Meet'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
