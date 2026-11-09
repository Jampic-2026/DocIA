import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/widgets.dart';
import '../application/human_resources_controller.dart';
import 'document_requirements_screen.dart';

Future<String?> selectPersonnelDocumentType(
  BuildContext context,
  WidgetRef ref, {
  String? roleCode,
}) async {
  final controller = TextEditingController();
  try {
    final requirements = await ref.read(documentRequirementsProvider.future);
    if (!context.mounted) return null;
    final relevant = requirements
        .where((rule) => roleCode == null || rule.roleCode == roleCode)
        .toList();
    return await showAppDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tipo de documento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (relevant.isEmpty)
                const Text(
                  'La lista obligatoria aún no está definida. Puedes adjuntar documentos, pero la aprobación permanecerá bloqueada.',
                ),
              for (final rule in relevant) ...[
                Text(personnelRoleLabels[rule.roleCode] ?? rule.roleCode),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final type in rule.documentTypes)
                      ActionChip(
                        label: Text(type),
                        onPressed: () => controller.text = type,
                      ),
                  ],
                ),
              ],
              AppTextField(
                controller: controller,
                label: 'Documento',
                hint: 'Selecciona un requisito o indica un documento adicional',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length >= 2) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Elegir archivo'),
          ),
        ],
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron consultar los requisitos: $error'),
        ),
      );
    }
    return null;
  } finally {
    controller.dispose();
  }
}
