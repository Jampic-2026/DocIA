import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/clinical_records_controller.dart';
import '../domain/vital_sign_record.dart';

class ProfessionalVitalsScreen extends ConsumerStatefulWidget {
  const ProfessionalVitalsScreen({
    super.key,
    required this.patientId,
    this.appointmentId,
    this.emergencyId,
  });
  final String patientId;
  final String? appointmentId;
  final String? emergencyId;
  @override
  ConsumerState<ProfessionalVitalsScreen> createState() =>
      _ProfessionalVitalsScreenState();
}

class _ProfessionalVitalsScreenState
    extends ConsumerState<ProfessionalVitalsScreen> {
  final form = GlobalKey<FormState>();
  final values = List.generate(6, (_) => TextEditingController());
  bool busy = false;
  @override
  void dispose() {
    for (final value in values) {
      value.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registrar signos vitales')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text(
            'Mediciones de la atención activa. Los valores se incorporarán al historial del paciente.',
          ),
          for (final field in [
            (0, 'Presión sistólica (mmHg)', 40.0, 300.0),
            (1, 'Presión diastólica (mmHg)', 20.0, 200.0),
            (2, 'Frecuencia cardíaca (lpm)', 20.0, 250.0),
            (3, 'Temperatura (°C)', 30.0, 45.0),
            (4, 'Saturación de oxígeno (%)', 40.0, 100.0),
          ])
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: AppTextField(
                controller: values[field.$1],
                label: field.$2,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (text) {
                  final value = double.tryParse(
                    (text ?? '').replaceAll(',', '.'),
                  );
                  return value == null ||
                          value < field.$3 ||
                          value > field.$4 ||
                          (field.$1 < 3 && value != value.roundToDouble())
                      ? 'Ingresa un valor válido entre ${field.$3} y ${field.$4}'
                      : null;
                },
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: values[5],
            label: 'Observaciones',
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: busy ? null : _save,
            child: Text(busy ? 'Guardando…' : 'Registrar'),
          ),
        ],
      ),
    ),
  );
  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    double number(int i) => double.parse(values[i].text.replaceAll(',', '.'));
    if (number(0) <= number(1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La sistólica debe superar la diastólica.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await ref
          .read(clinicalRecordsRepositoryProvider)
          .createProfessionalVitalSign(
            widget.patientId,
            CreateVitalSignCommand(
              systolicPressure: number(0).toInt(),
              diastolicPressure: number(1).toInt(),
              heartRate: number(2).toInt(),
              temperatureC: number(3),
              oxygenSaturation: number(4),
              notes: values[5].text.trim(),
            ),
            appointmentId: widget.appointmentId,
            emergencyId: widget.emergencyId,
          );
      ref.invalidate(professionalPatientRecordProvider(widget.patientId));
      ref.invalidate(vitalSignsProvider);
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
