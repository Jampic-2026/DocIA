import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/human_resources_controller.dart';

const personnelRoleLabels = {
  'doctor_general': 'Medicina general',
  'doctor_specialist': 'Medicina especializada',
  'nurse': 'Enfermería',
  'operator': 'Operación',
  'clinical_supervisor': 'Supervisión clínica',
  'delivery_assistant': 'Entregas',
  'human_resources': 'Recursos humanos',
};

class DocumentRequirementsScreen extends ConsumerWidget {
  const DocumentRequirementsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(documentRequirementsProvider)
      .when(
        loading: () => const AppLoadingState(message: 'Cargando requisitos'),
        error: (error, _) => AppErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(documentRequirementsProvider),
        ),
        data: (rules) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text(
              'Define los tipos de documentos obligatorios de cada rol. Sin una lista definida no se pueden aprobar incorporaciones. Los cambios se aplican a las siguientes decisiones de habilitación.',
            ),
            for (final role in personnelRoleLabels.entries)
              ListTile(
                title: Text(role.value),
                subtitle: Text(
                  rules
                          .where((rule) => rule.roleCode == role.key)
                          .map((rule) => rule.documentTypes.join(', '))
                          .firstOrNull ??
                      'Sin definir: aprobación bloqueada',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  final existing = rules
                      .where((rule) => rule.roleCode == role.key)
                      .firstOrNull;
                  final controller = TextEditingController(
                    text: existing?.documentTypes.join('\n'),
                  );
                  final result = await showAppDialog<List<String>>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(role.value),
                      content: SizedBox(
                        width: 480,
                        child: AppTextField(
                          controller: controller,
                          label: 'Un tipo de documento por línea',
                          maxLines: 8,
                        ),
                      ),
                      actions: [
                        SizedBox(
                          width: 420,
                          child: AppDialogActions(
                            cancelLabel: 'Cancelar',
                            confirmLabel: 'Guardar',
                            onCancel: () => Navigator.pop(dialogContext),
                            onConfirm: () {
                              final types = controller.text
                                  .split('\n')
                                  .map((type) => type.trim())
                                  .where((type) => type.isNotEmpty)
                                  .toList();
                              if (types.isNotEmpty &&
                                  types.length <= 30 &&
                                  types.toSet().length == types.length &&
                                  types.every(
                                    (type) =>
                                        type.length >= 2 && type.length <= 80,
                                  )) {
                                Navigator.pop(dialogContext, types);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                  controller.dispose();
                  if (result == null) return;
                  try {
                    await ref
                        .read(humanResourcesRepositoryProvider)
                        .configureRequirements(role.key, result);
                    ref.invalidate(documentRequirementsProvider);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error.toString())));
                    }
                  }
                },
              ),
          ],
        ),
      );
}
