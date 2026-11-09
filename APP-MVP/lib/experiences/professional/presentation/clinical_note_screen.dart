import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/clinical_notes/application/clinical_notes_controller.dart';
import '../../../modules/clinical_notes/domain/clinical_note.dart';
import '../../../modules/professional_patients/application/professional_patients_controller.dart';

class ClinicalNoteScreen extends ConsumerStatefulWidget {
  const ClinicalNoteScreen({
    required this.patientId,
    required this.appointmentId,
    required this.patientName,
    this.age,
    super.key,
  });

  final String patientId;
  final String appointmentId;
  final String patientName;
  final int? age;

  @override
  ConsumerState<ClinicalNoteScreen> createState() => _ClinicalNoteScreenState();
}

class _ClinicalNoteScreenState extends ConsumerState<ClinicalNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjective = TextEditingController();
  final _objective = TextEditingController();
  final _assessment = TextEditingController();
  final _plan = TextEditingController();
  final _diagnosis = TextEditingController();
  final _treatment = TextEditingController();
  final _treatmentInstructions = TextEditingController();
  final _followupInstructions = TextEditingController();
  String _diagnosisType = 'presumptive';
  DateTime? _followupDueAt;

  @override
  void dispose() {
    _subjective.dispose();
    _objective.dispose();
    _assessment.dispose();
    _plan.dispose();
    _diagnosis.dispose();
    _treatment.dispose();
    _treatmentInstructions.dispose();
    _followupInstructions.dispose();
    super.dispose();
  }

  Future<void> _closeConsultation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_diagnosis.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registra el diagnóstico para finalizar.')),
      );
      return;
    }
    try {
      await ref.read(clinicalNoteSubmissionProvider.notifier).close(
            CloseConsultationCommand(
              appointmentId: widget.appointmentId,
              patientId: widget.patientId,
              subjective: _subjective.text,
              objective: _objective.text,
              assessment: _assessment.text,
              plan: _plan.text,
              diagnosis: _diagnosis.text,
              diagnosisType: _diagnosisType,
              treatment: _treatment.text,
              treatmentInstructions: _treatmentInstructions.text,
              followupDueAt: _followupDueAt,
              followupInstructions: _followupInstructions.text,
            ),
          );
      ref.invalidate(professionalPatientsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consulta finalizada y expediente actualizado.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(clinicalNoteSubmissionProvider.notifier).submit(
            CreateClinicalNoteCommand(
              appointmentId: widget.appointmentId,
              patientId: widget.patientId,
              subjective: _subjective.text,
              objective: _objective.text,
              assessment: _assessment.text,
              plan: _plan.text,
            ),
          );
      ref.invalidate(professionalPatientsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nota clínica guardada.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.patientId.isEmpty || widget.appointmentId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Nueva nota clínica')),
        body: EmptyState(
          icon: Icons.event_busy_rounded,
          title: 'Selecciona una consulta',
          message:
              'Abre la nota clínica desde un paciente con una consulta asignada.',
        ),
      );
    }
    final submission = ref.watch(clinicalNoteSubmissionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva nota clínica')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppCard(
              child: Row(
                children: [
                  UserAvatar(name: widget.patientName),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.patientName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          widget.age == null
                              ? 'Consulta seleccionada'
                              : '${widget.age} años · Consulta seleccionada',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Field(
              controller: _subjective,
              label: 'Subjetivo (S)',
              hint: 'Síntomas y motivo de consulta referidos por el paciente',
              requiredField: true,
            ),
            _Field(
              controller: _objective,
              label: 'Objetivo (O)',
              hint: 'Signos vitales, examen físico y hallazgos',
            ),
            _Field(
              controller: _assessment,
              label: 'Análisis (A)',
              hint: 'Diagnóstico o impresión clínica',
              requiredField: true,
            ),
            _Field(
              controller: _plan,
              label: 'Plan (P)',
              hint: 'Tratamiento, indicaciones y seguimiento',
            ),
            const SectionHeader(title: 'Cierre de consulta'),
            const SizedBox(height: AppSpacing.md),
            _Field(controller: _diagnosis, label: 'Diagnóstico', hint: 'Diagnóstico principal de la atención'),
            DropdownButtonFormField<String>(
              initialValue: _diagnosisType,
              decoration: const InputDecoration(labelText: 'Tipo de diagnóstico'),
              items: const [
                DropdownMenuItem(value: 'presumptive', child: Text('Presuntivo')),
                DropdownMenuItem(value: 'definitive', child: Text('Definitivo')),
                DropdownMenuItem(value: 'differential', child: Text('Diferencial')),
              ],
              onChanged: (value) => setState(() => _diagnosisType = value ?? 'presumptive'),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Field(controller: _treatment, label: 'Tratamiento', hint: 'Tratamiento recomendado'),
            _Field(controller: _treatmentInstructions, label: 'Indicaciones', hint: 'Forma de aplicación y cuidados'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_repeat_outlined),
              title: const Text('Fecha sugerida de seguimiento'),
              subtitle: Text(_followupDueAt == null ? 'Sin fecha definida' : '${_followupDueAt!.day.toString().padLeft(2, '0')}/${_followupDueAt!.month.toString().padLeft(2, '0')}/${_followupDueAt!.year}'),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: () async {
                final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (date != null) setState(() => _followupDueAt = date);
              },
            ),
            _Field(controller: _followupInstructions, label: 'Seguimiento', hint: 'Indicaciones para el control posterior'),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: submission.isLoading ? null : _save,
              icon: submission.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                submission.isLoading ? 'Guardando...' : 'Guardar nota',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: submission.isLoading ? null : _closeConsultation,
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Finalizar consulta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.requiredField = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppTextField(
        controller: controller,
        label: label,
        hint: hint,
        maxLines: 3,
        validator: requiredField
            ? (value) => value == null || value.trim().isEmpty
                ? 'Campo requerido'
                : null
            : null,
      ),
    );
  }
}
