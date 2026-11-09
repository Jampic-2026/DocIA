import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/human_resources_controller.dart';
import 'document_requirements_screen.dart';

class VerificationSelection {
  const VerificationSelection(this.roleCode, this.specialtyId);
  final String roleCode;
  final String? specialtyId;
}

Future<VerificationSelection?> selectVerification(
  BuildContext context, {
  String? fixedRole,
  String? professionalType,
}) => showDialog<VerificationSelection>(
  context: context,
  builder: (_) => _VerificationDialog(
    fixedRole: fixedRole,
    professionalType: professionalType,
  ),
);

class _VerificationDialog extends ConsumerStatefulWidget {
  const _VerificationDialog({this.fixedRole, this.professionalType});
  final String? fixedRole;
  final String? professionalType;
  @override
  ConsumerState<_VerificationDialog> createState() =>
      _VerificationDialogState();
}

class _VerificationDialogState extends ConsumerState<_VerificationDialog> {
  String? role;
  String? specialty;
  @override
  void initState() {
    super.initState();
    role = widget.fixedRole;
  }

  @override
  Widget build(BuildContext context) {
    const types = {
      'doctor_general': 'doctor',
      'doctor_specialist': 'doctor',
      'nurse': 'nurse',
      'operator': 'operator',
      'clinical_supervisor': 'clinical_supervisor',
      'delivery_assistant': 'delivery',
      'human_resources': 'admin',
    };
    final rules = ref.watch(documentRequirementsProvider);
    final specialties = ref.watch(verificationSpecialtiesProvider);
    final documents =
        rules.value
            ?.where((rule) => rule.roleCode == role)
            .firstOrNull
            ?.documentTypes ??
        const <String>[];
    final isDoctor = role == 'doctor_general' || role == 'doctor_specialist';
    return AlertDialog(
      title: const Text('Habilitar profesional'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: personnelRoleLabels.entries
                    .where(
                      (entry) =>
                          (widget.fixedRole == null ||
                              entry.key == widget.fixedRole) &&
                          (widget.professionalType == null ||
                              types[entry.key] == widget.professionalType),
                    )
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: widget.fixedRole != null
                    ? null
                    : (value) => setState(() {
                        role = value;
                        specialty = null;
                      }),
              ),
              const SizedBox(height: AppSpacing.md),
              rules.when(
                data: (_) => Text(
                  documents.isEmpty
                      ? 'Requisitos sin definir: configura el rol antes de aprobar.'
                      : 'Documentos obligatorios: ${documents.join(', ')}',
                ),
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text(error.toString()),
              ),
              if (isDoctor)
                specialties.when(
                  data: (items) => DropdownButtonFormField<String>(
                    initialValue: specialty,
                    decoration: const InputDecoration(
                      labelText: 'Especialidad validada',
                    ),
                    items: items
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => specialty = value),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (error, _) => Text(error.toString()),
                ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'La aprobación comprobará los documentos y su vigencia. No aprueba documentos pendientes automáticamente.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed:
              role != null &&
                  documents.isNotEmpty &&
                  (!isDoctor || specialty != null)
              ? () => Navigator.pop(
                  context,
                  VerificationSelection(role!, specialty),
                )
              : null,
          child: const Text('Aprobar'),
        ),
      ],
    );
  }
}
