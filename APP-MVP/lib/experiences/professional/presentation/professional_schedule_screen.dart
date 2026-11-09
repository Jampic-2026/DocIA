import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/professional_schedule/application/professional_schedule_controller.dart';
import '../../../modules/professional_schedule/domain/professional_schedule.dart';

class ProfessionalScheduleScreen extends ConsumerWidget {
  const ProfessionalScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(professionalScheduleProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar disponibilidad')),
      body: schedule.when(
        loading: () =>
            const AppLoadingState(message: 'Cargando disponibilidad'),
        error: (error, _) => AppErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(professionalScheduleProvider),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SectionHeader(
              title: 'Horario semanal',
              subtitle: 'Define cuándo pueden reservar consultas',
              actionLabel: 'Agregar',
              onAction: () => _addAvailability(context, ref),
            ),
            const SizedBox(height: AppSpacing.md),
            if (data.availability.isEmpty)
              const Text('Todavía no configuraste horarios.')
            else
              for (final slot in data.availability) ...[
                _AvailabilityCard(slot: slot),
                const SizedBox(height: AppSpacing.sm),
              ],
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: 'Bloqueos de agenda',
              subtitle: 'Ausencias, descansos y compromisos',
              actionLabel: 'Agregar',
              onAction: () => _addBlock(context, ref),
            ),
            const SizedBox(height: AppSpacing.md),
            if (data.timeBlocks.isEmpty)
              const Text('No existen bloqueos próximos.')
            else
              for (final block in data.timeBlocks) ...[
                _BlockCard(block: block),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _addAvailability(BuildContext context, WidgetRef ref) async {
    var weekday = 1;
    var modality = 'in_person';
    var start = const TimeOfDay(hour: 8, minute: 0);
    var end = const TimeOfDay(hour: 12, minute: 0);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Agregar horario'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: weekday,
                  decoration: const InputDecoration(labelText: 'Día'),
                  items: List.generate(
                    7,
                    (index) => DropdownMenuItem(
                      value: index,
                      child: Text(_day(index)),
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => weekday = value ?? weekday),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: modality,
                  decoration: const InputDecoration(labelText: 'Modalidad'),
                  items: const [
                    DropdownMenuItem(
                      value: 'in_person',
                      child: Text('Presencial'),
                    ),
                    DropdownMenuItem(
                      value: 'telemedicine',
                      child: Text('Telemedicina'),
                    ),
                    DropdownMenuItem(
                      value: 'home_visit',
                      child: Text('A domicilio'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => modality = value ?? modality),
                ),
                ListTile(
                  title: const Text('Desde'),
                  trailing: Text(start.format(context)),
                  onTap: () async {
                    final value = await showTimePicker(
                      context: context,
                      initialTime: start,
                    );
                    if (value != null) setState(() => start = value);
                  },
                ),
                ListTile(
                  title: const Text('Hasta'),
                  trailing: Text(end.format(context)),
                  onTap: () async {
                    final value = await showTimePicker(
                      context: context,
                      initialTime: end,
                    );
                    if (value != null) setState(() => end = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: 420,
              child: AppDialogActions(
                cancelLabel: 'Cancelar',
                confirmLabel: 'Guardar',
                confirmIcon: Icons.save_outlined,
                onCancel: () => Navigator.pop(dialogContext, false),
                onConfirm: () => Navigator.pop(dialogContext, true),
              ),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    try {
      await ref
          .read(professionalScheduleRepositoryProvider)
          .addAvailability(
            weekday: weekday,
            startTime: _time(start),
            endTime: _time(end),
            modality: modality,
          );
      ref.invalidate(professionalScheduleProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _addBlock(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !context.mounted) return;
    final startTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (startTime == null || !context.mounted) return;
    final endTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (endTime == null || !context.mounted) return;
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Motivo del bloqueo'),
        content: SizedBox(
          width: 420,
          child: AppTextField(
            controller: reason,
            label: 'Motivo',
            hint: 'Ej.: Reunión o descanso',
          ),
        ),
        actions: [
          SizedBox(
            width: 420,
            child: AppDialogActions(
              cancelLabel: 'Cancelar',
              confirmLabel: 'Bloquear',
              confirmIcon: Icons.event_busy_outlined,
              onCancel: () => Navigator.pop(dialogContext, false),
              onConfirm: () => Navigator.pop(dialogContext, true),
            ),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (accepted != true) return;
    try {
      await ref
          .read(professionalScheduleRepositoryProvider)
          .addTimeBlock(
            startAt: DateTime(
              day.year,
              day.month,
              day.day,
              startTime.hour,
              startTime.minute,
            ),
            endAt: DateTime(
              day.year,
              day.month,
              day.day,
              endTime.hour,
              endTime.minute,
            ),
            reason: text,
          );
      ref.invalidate(professionalScheduleProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _AvailabilityCard extends ConsumerWidget {
  const _AvailabilityCard({required this.slot});
  final AvailabilitySlot slot;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppCard(
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.schedule_rounded, color: AppColors.teal),
      title: Text(
        '${_day(slot.weekday)} · ${slot.startTime} a ${slot.endTime}',
      ),
      subtitle: Text(_modality(slot.modality)),
      trailing: IconButton(
        tooltip: 'Eliminar horario',
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: () async {
          try {
            await ref
                .read(professionalScheduleRepositoryProvider)
                .removeAvailability(slot.id);
            ref.invalidate(professionalScheduleProvider);
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(error.toString())));
            }
          }
        },
      ),
    ),
  );
}

class _BlockCard extends ConsumerWidget {
  const _BlockCard({required this.block});
  final ProfessionalTimeBlock block;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppCard(
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_busy_rounded, color: AppColors.warning),
      title: Text(DateFormat('d MMM y · HH:mm').format(block.startAt)),
      subtitle: Text(
        '${DateFormat('HH:mm').format(block.endAt)}${block.reason?.isNotEmpty == true ? ' · ${block.reason}' : ''}',
      ),
      trailing: IconButton(
        tooltip: 'Quitar bloqueo',
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: () async {
          try {
            await ref
                .read(professionalScheduleRepositoryProvider)
                .removeTimeBlock(block.id);
            ref.invalidate(professionalScheduleProvider);
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(error.toString())));
            }
          }
        },
      ),
    ),
  );
}

String _time(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _day(int value) => const [
  'Domingo',
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
][value];
String _modality(String value) => switch (value) {
  'telemedicine' => 'Telemedicina',
  'home_visit' => 'A domicilio',
  _ => 'Presencial',
};
