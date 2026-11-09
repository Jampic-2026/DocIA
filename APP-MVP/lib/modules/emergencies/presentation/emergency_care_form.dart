import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/emergencies_controller.dart';
import '../domain/emergencies_repository.dart';

class EmergencyCareForm extends ConsumerStatefulWidget {
  const EmergencyCareForm({
    super.key,
    required this.emergencyId,
    required this.isNurse,
  });
  final String emergencyId;
  final bool isNurse;
  @override
  ConsumerState<EmergencyCareForm> createState() => _EmergencyCareFormState();
}

class _EmergencyCareFormState extends ConsumerState<EmergencyCareForm> {
  final form = GlobalKey<FormState>();
  final notes = TextEditingController(),
      symptoms = TextEditingController(),
      assessment = TextEditingController(),
      procedures = TextEditingController(),
      destination = TextEditingController();
  late String type = widget.isNurse
      ? 'nursing_assessment'
      : 'medical_assessment';
  bool busy = false;
  @override
  void dispose() {
    for (final field in [
      notes,
      symptoms,
      assessment,
      procedures,
      destination,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registrar atención')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Tipo de registro'),
            items: [
              if (widget.isNurse)
                const DropdownMenuItem(
                  value: 'nursing_assessment',
                  child: Text('Valoración de enfermería'),
                ),
              if (!widget.isNurse)
                const DropdownMenuItem(
                  value: 'medical_assessment',
                  child: Text('Valoración médica'),
                ),
              const DropdownMenuItem(
                value: 'intervention',
                child: Text('Intervención'),
              ),
              const DropdownMenuItem(
                value: 'referral',
                child: Text('Derivación'),
              ),
              const DropdownMenuItem(
                value: 'closure',
                child: Text('Cierre de atención'),
              ),
            ],
            onChanged: (value) => setState(() => type = value ?? type),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: symptoms,
            label: 'Síntomas observados o reportados',
            hint: 'Separa los síntomas con comas; deja vacío si no corresponde',
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: assessment,
            label: 'Hallazgos y valoración',
            maxLines: 4,
            validator: _required,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: procedures,
            label: 'Procedimientos realizados',
            maxLines: 3,
          ),
          if (type == 'referral') ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: destination,
              label: 'Destino de la derivación',
              validator: _required,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: notes,
            label: 'Observaciones y seguimiento',
            maxLines: 4,
            validator: _required,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: busy ? null : _save,
            child: Text(busy ? 'Guardando…' : 'Registrar atención'),
          ),
        ],
      ),
    ),
  );
  String? _required(String? value) =>
      (value?.trim().length ?? 0) < 3 ? 'Completa este campo' : null;
  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await ref
          .read(emergenciesRepositoryProvider)
          .recordCare(
            widget.emergencyId,
            EmergencyCareCommand(
              careType: type,
              notes: notes.text.trim(),
              symptoms: symptoms.text
                  .split(',')
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toList(),
              assessment: assessment.text.trim(),
              procedures: procedures.text.trim(),
              referralDestination: type == 'referral'
                  ? destination.text.trim()
                  : null,
            ),
          );
      ref.invalidate(emergencyCareProvider(widget.emergencyId));
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
