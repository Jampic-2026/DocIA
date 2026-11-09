import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/widgets.dart';
import '../application/family_controller.dart';

class CreateDependentScreen extends ConsumerStatefulWidget {
  const CreateDependentScreen({super.key});
  @override
  ConsumerState<CreateDependentScreen> createState() =>
      _CreateDependentScreenState();
}

class _CreateDependentScreenState extends ConsumerState<CreateDependentScreen> {
  final form = GlobalKey<FormState>();
  final first = TextEditingController(),
      last = TextEditingController(),
      second = TextEditingController(),
      relationship = TextEditingController(),
      document = TextEditingController(),
      documentType = TextEditingController();
  DateTime? birth;
  bool confirmed = false, busy = false;
  @override
  void dispose() {
    for (final value in [
      first,
      last,
      second,
      relationship,
      document,
      documentType,
    ]) {
      value.dispose();
    }
    super.dispose();
  }

  String? requiredName(String? value) =>
      (value?.trim().length ?? 0) < 2 ? 'Completa este campo' : null;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registrar menor a cargo')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text(
            'Tu cuenta debe tener una fecha de nacimiento que acredite mayoría de edad. El menor quedará vinculado a tu cuenta de tutor.',
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final width =
                  constraints.maxWidth >= AppDimensions.compactBreakpoint
                  ? (constraints.maxWidth - AppSpacing.lg) / 2
                  : constraints.maxWidth;
              final fields = <Widget>[
                AppTextField(
                  controller: first,
                  label: 'Nombres',
                  validator: requiredName,
                ),
                AppTextField(
                  controller: last,
                  label: 'Primer apellido',
                  validator: requiredName,
                ),
                AppTextField(
                  controller: second,
                  label: 'Segundo apellido (opcional)',
                ),
                ListTile(
                  title: const Text('Fecha de nacimiento'),
                  subtitle: Text(
                    birth == null
                        ? 'Seleccionar fecha'
                        : DateFormat('dd/MM/yyyy').format(birth!),
                  ),
                  onTap: () async {
                    final now = DateTime.now();
                    final value = await showDatePicker(
                      context: context,
                      initialDate:
                          birth ?? DateTime(now.year - 1, now.month, now.day),
                      firstDate: DateTime(
                        now.year - 18,
                        now.month,
                        now.day + 1,
                      ),
                      lastDate: now,
                    );
                    if (value != null && mounted) {
                      setState(() => birth = value);
                    }
                  },
                ),
                AppTextField(
                  controller: documentType,
                  label: 'Tipo de documento (opcional)',
                ),
                AppTextField(
                  controller: document,
                  label: 'Número de documento (opcional)',
                ),
                AppTextField(
                  controller: relationship,
                  label: 'Relación con el menor',
                  validator: requiredName,
                ),
              ];
              return Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                children: [
                  for (final field in fields)
                    SizedBox(width: width, child: field),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          CheckboxListTile(
            value: confirmed,
            onChanged: (value) => setState(() => confirmed = value ?? false),
            title: const Text(
              'Declaro que soy responsable legal de este menor y que estoy autorizado para gestionar su atención.',
            ),
          ),
          FilledButton(
            onPressed: busy || !confirmed ? null : _save,
            child: Text(busy ? 'Registrando…' : 'Registrar menor'),
          ),
        ],
      ),
    ),
  );
  Future<void> _save() async {
    if (!form.currentState!.validate() || birth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa los datos y la fecha de nacimiento.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await ref
          .read(familyRepositoryProvider)
          .createDependent(
            firstName: first.text.trim(),
            lastName: last.text.trim(),
            secondLastName: second.text.trim(),
            birthDate: DateFormat('yyyy-MM-dd').format(birth!),
            documentType: documentType.text.trim(),
            documentNumber: document.text.trim(),
            relationship: relationship.text.trim(),
            confirmResponsibility: confirmed,
          );
      ref.invalidate(familyProvider);
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
