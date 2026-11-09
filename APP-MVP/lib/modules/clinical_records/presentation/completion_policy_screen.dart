import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/widgets.dart';
import '../application/clinical_records_controller.dart';

const completionFieldLabels = <String, String>{
  'bloodType': 'Grupo sanguíneo',
  'heightCm': 'Estatura',
  'weightKg': 'Peso',
  'insuranceProvider': 'Seguro',
  'emergencyContact': 'Contacto de emergencia',
  'allergies': 'Alergias declaradas',
  'medicalHistory': 'Antecedentes patológicos',
  'familyHistory': 'Antecedentes familiares',
  'surgicalHistory': 'Antecedentes quirúrgicos',
  'chronicConditions': 'Condiciones crónicas',
  'currentMedications': 'Medicación',
  'validatedAllergies': 'Alergias validadas',
  'validatedAntecedents': 'Antecedentes validados',
  'professionalVitals': 'Signos registrados por profesional',
};

class CompletionPolicyScreen extends ConsumerWidget {
  const CompletionPolicyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(completionPolicyProvider)
      .when(
        loading: () =>
            const AppLoadingState(message: 'Cargando reglas de perfil'),
        error: (error, _) => AppErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(completionPolicyProvider),
        ),
        data: (policy) =>
            _PolicyForm(key: ValueKey(policy.toString()), policy: policy),
      );
}

class _PolicyForm extends ConsumerStatefulWidget {
  const _PolicyForm({super.key, required this.policy});
  final Map<String, dynamic> policy;
  @override
  ConsumerState<_PolicyForm> createState() => _PolicyFormState();
}

class _PolicyFormState extends ConsumerState<_PolicyForm> {
  late Set<String> _fields;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _fields = (widget.policy['rules'] as List)
        .map((row) => row['field'] as String)
        .toSet();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Reglas de completitud',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const Text(
        'Cada campo seleccionado tiene el mismo peso. Las validaciones y los signos profesionales corresponden al personal de salud. Una lista vacía deja el porcentaje sin definir.',
      ),
      for (final field in completionFieldLabels.entries)
        CheckboxListTile(
          value: _fields.contains(field.key),
          title: Text(field.value),
          onChanged: _saving
              ? null
              : (selected) => setState(() {
                  if (selected == true) {
                    _fields.add(field.key);
                  } else {
                    _fields.remove(field.key);
                  }
                }),
        ),
      const Text(
        'La recompensa permanece desactivada. Su beneficio, campaña, umbral y vigencia deben definirse antes de habilitarla.',
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(
          _saving ? 'Guardando…' : 'Guardar reglas; recompensa desactivada',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(clinicalRecordsRepositoryProvider).saveCompletionPolicy({
        ...widget.policy,
        'rewardEnabled': false,
        'rules': [
          for (final field in _fields)
            {
              'field': field,
              'label': completionFieldLabels[field],
              'actor':
                  field.startsWith('validated') || field == 'professionalVitals'
                  ? 'professional'
                  : 'patient',
            },
        ],
      });
      ref.invalidate(completionPolicyProvider);
      ref.invalidate(profileCompletionProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reglas guardadas. Recompensa desactivada.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
