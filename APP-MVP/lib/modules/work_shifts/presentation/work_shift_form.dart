import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/work_shifts_controller.dart';
import '../domain/work_shifts_repository.dart';

class WorkShiftForm extends ConsumerStatefulWidget {
  const WorkShiftForm({super.key, this.shift});
  final WorkShift? shift;
  @override
  ConsumerState<WorkShiftForm> createState() => _WorkShiftFormState();
}

class _WorkShiftFormState extends ConsumerState<WorkShiftForm> {
  final form = GlobalKey<FormState>();
  late final location = TextEditingController(text: widget.shift?.location),
      area = TextEditingController(text: widget.shift?.area),
      notes = TextEditingController(text: widget.shift?.notes);
  final reason = TextEditingController();
  String? professionalId;
  late String status = widget.shift?.status ?? 'assigned';
  DateTime? start, end;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    professionalId = widget.shift?.professionalId;
    start = widget.shift?.startAt;
    end = widget.shift?.endAt;
  }

  @override
  void dispose() {
    for (final value in [location, area, notes, reason]) {
      value.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.shift == null ? 'Asignar turno' : 'Modificar turno'),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (widget.shift != null)
            Text(widget.shift!.professionalName)
          else
            ref
                .watch(
                  availableStaffProvider((
                    role: 'nurse',
                    location: null,
                    specialtyId: null,
                    availableOnly: false,
                    serviceType: null,
                  )),
                )
                .when(
                  loading: () => const AppLoadingState(
                    message: 'Consultando enfermería habilitada',
                  ),
                  error: (error, _) => Text(error.toString()),
                  data: (items) => DropdownButtonFormField<String>(
                    initialValue: professionalId,
                    decoration: const InputDecoration(
                      labelText: 'Profesional de enfermería',
                    ),
                    items: items
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => professionalId = value),
                    validator: (value) =>
                        value == null ? 'Selecciona una persona' : null,
                  ),
                ),
          ListTile(
            title: const Text('Inicio'),
            subtitle: Text(
              start == null
                  ? 'Seleccionar fecha y hora'
                  : DateFormat('dd/MM/yyyy HH:mm').format(start!),
            ),
            trailing: const Icon(Icons.calendar_month),
            onTap: () => _pick(true),
          ),
          ListTile(
            title: const Text('Fin'),
            subtitle: Text(
              end == null
                  ? 'Seleccionar fecha y hora'
                  : DateFormat('dd/MM/yyyy HH:mm').format(end!),
            ),
            trailing: const Icon(Icons.calendar_month),
            onTap: () => _pick(false),
          ),
          AppTextField(
            controller: location,
            label: 'Sede',
            validator: (value) =>
                (value?.trim().length ?? 0) < 2 ? 'Indica la sede' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(controller: area, label: 'Área asignada'),
          const SizedBox(height: AppSpacing.md),
          AppTextField(controller: notes, label: 'Observaciones', maxLines: 3),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: const [
              DropdownMenuItem(value: 'assigned', child: Text('Asignado')),
              DropdownMenuItem(value: 'cancelled', child: Text('Cancelado')),
            ],
            onChanged: (value) => setState(() => status = value ?? status),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: reason,
            label: 'Motivo de asignación o cambio',
            validator: (value) =>
                (value?.trim().length ?? 0) < 3 ? 'Indica el motivo' : null,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: busy ? null : _save,
            child: Text(busy ? 'Guardando…' : 'Guardar turno'),
          ),
        ],
      ),
    ),
  );
  Future<void> _pick(bool isStart) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: (isStart ? start : end) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime((isStart ? start : end) ?? now),
    );
    if (time != null && mounted) {
      setState(() {
        final value = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        if (isStart) {
          start = value;
        } else {
          end = value;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    if (start == null ||
        end == null ||
        professionalId == null ||
        !end!.isAfter(start!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona profesional, inicio y fin válidos.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await ref
          .read(workShiftsRepositoryProvider)
          .save(
            id: widget.shift?.id,
            professionalId: professionalId!,
            startAt: start!,
            endAt: end!,
            location: location.text.trim(),
            area: area.text.trim(),
            notes: notes.text.trim(),
            status: status,
            reason: reason.text.trim(),
          );
      ref.invalidate(workShiftsProvider);
      ref.invalidate(availableStaffProvider);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }
}
