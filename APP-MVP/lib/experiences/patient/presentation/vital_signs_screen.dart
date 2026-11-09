import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/adaptive_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/clinical_records/application/clinical_records_controller.dart';
import '../../../modules/clinical_records/domain/vital_sign_record.dart';
import '../../../modules/clinical_records/presentation/widgets/clinical_record_cards.dart';

class VitalSignsScreen extends ConsumerWidget {
  const VitalSignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signos vitales')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: const _VitalSignForm(),
            ),
          ),
        ),
        icon: const Icon(Icons.add_chart_rounded),
        label: const Text('Registrar'),
      ),
      body: ref.watch(vitalSignsProvider).when(
            loading: () => const AppLoadingState(message: 'Cargando signos vitales'),
            error: (error, _) => AppErrorState(
              message: error.toString(),
              onRetry: () => ref.invalidate(vitalSignsProvider),
            ),
            data: (records) => records.isEmpty
                ? const EmptyState(
                    icon: Icons.monitor_heart_outlined,
                    title: 'Sin mediciones registradas',
                    message: 'Tus mediciones aparecerán aquí.',
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.refresh(vitalSignsProvider.future),
                    child: AdaptivePage(
                      maxWidth: 920,
                      children: [
                        for (final record in records)
                          VitalSignRecordCard(
                            record: record,
                            badgeLabel: 'Paciente',
                          ),
                      ],
                    ),
                  ),
          ),
    );
  }
}

class _VitalSignForm extends ConsumerStatefulWidget {
  const _VitalSignForm();
  @override
  ConsumerState<_VitalSignForm> createState() => _VitalSignFormState();
}

class _VitalSignFormState extends ConsumerState<_VitalSignForm> {
  final _formKey = GlobalKey<FormState>();
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _heartRate = TextEditingController();
  final _temperature = TextEditingController();
  final _oxygen = TextEditingController();
  final _respiratory = TextEditingController();
  final _glucose = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_systolic, _diastolic, _heartRate, _temperature, _oxygen, _respiratory, _glucose, _weight, _height, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final command = CreateVitalSignCommand(
      systolicPressure: int.tryParse(_systolic.text),
      diastolicPressure: int.tryParse(_diastolic.text),
      heartRate: int.tryParse(_heartRate.text),
      temperatureC: _decimal(_temperature.text),
      oxygenSaturation: _decimal(_oxygen.text),
      respiratoryRate: int.tryParse(_respiratory.text),
      glucoseMgDl: _decimal(_glucose.text),
      weightKg: _decimal(_weight.text),
      heightCm: _decimal(_height.text),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    setState(() => _saving = true);
    try {
      await ref.read(clinicalRecordsRepositoryProvider).createVitalSign(command);
      ref.invalidate(vitalSignsProvider);
      ref.invalidate(clinicalProfileProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: ListView(shrinkWrap: true, children: [
            const Text('Registrar medición', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.lg),
            _pair(_systolic, 'Presión sistólica', _diastolic, 'Presión diastólica'),
            _pair(_heartRate, 'Frecuencia cardíaca', _temperature, 'Temperatura °C'),
            _pair(_oxygen, 'Saturación %', _respiratory, 'Frecuencia respiratoria'),
            _pair(_glucose, 'Glucosa mg/dL', _weight, 'Peso kg'),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _numberField(_height, 'Estatura cm'),
            ),
            AppTextField(controller: _notes, label: 'Observaciones', maxLines: 3),
            const SizedBox(height: AppSpacing.lg),
            _VitalSignActions(
              saving: _saving,
              onCancel: () => Navigator.pop(context),
              onSave: _save,
            ),
          ]),
        ),
      );

  Widget _pair(TextEditingController left, String leftLabel, TextEditingController right, String rightLabel) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(children: [
          Expanded(child: _numberField(left, leftLabel)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _numberField(right, rightLabel)),
        ]),
      );

  Widget _numberField(TextEditingController controller, String label) => AppTextField(
        controller: controller,
        label: label,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) => value != null && value.trim().isNotEmpty && _decimal(value) == null ? 'Número inválido' : null,
      );
}

class _VitalSignActions extends StatelessWidget {
  const _VitalSignActions({
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return AppDialogActions(
      cancelLabel: 'Cancelar',
      confirmLabel: 'Guardar medición',
      busy: saving,
      busyLabel: 'Guardando...',
      confirmIcon: Icons.save_outlined,
      onCancel: onCancel,
      onConfirm: onSave,
    );
  }
}

double? _decimal(String value) => double.tryParse(value.trim().replaceAll(',', '.'));
