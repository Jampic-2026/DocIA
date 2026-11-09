import '../../../core/widgets/app_action_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/authorization/permission_codes.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/app_file_link.dart';
import '../../auth/application/auth_controller.dart';
import '../application/human_resources_controller.dart';

class ProfessionalDocumentsScreen extends ConsumerWidget {
  const ProfessionalDocumentsScreen({super.key, required this.professionalId});
  final String professionalId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canReview =
        ref
            .watch(authControllerProvider)
            .user
            ?.can(PermissionCodes.humanResourcesManage) ??
        false;
    return Scaffold(
      appBar: AppBar(title: const Text('Documentos profesionales')),
      body: ref
          .watch(professionalDocumentsProvider(professionalId))
          .when(
            loading: () =>
                const AppLoadingState(message: 'Cargando documentos'),
            error: (error, _) => AppErrorState(
              message: error.toString(),
              onRetry: () =>
                  ref.invalidate(professionalDocumentsProvider(professionalId)),
            ),
            data: (documents) => ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (ref
                        .watch(staffProvider)
                        .valueOrNull
                        ?.where((item) => item.professionalId == professionalId)
                        .firstOrNull
                    case final professional?) ...[
                  Text(
                    'Formación declarada: ${professional.academicBackground ?? "Sin formación registrada"}',
                  ),
                  for (final certificate in professional.certifications)
                    Text('Certificación declarada: $certificate'),
                ],
                if (documents.isEmpty)
                  const Text(
                    'No hay documentos registrados: la habilitación permanece bloqueada.',
                  ),
                for (final document in documents)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.documentType,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('Estado: ${document.status}'),
                        if (document.observation != null)
                          Text(document.observation!),
                        AppFileLink(fileUrl: document.fileUrl),
                        if (canReview)
                          AppActionRow(
                            children: [
                              OutlinedButton(
                                onPressed: () =>
                                    _review(context, ref, document.id, false),
                                child: const Text(
                                  'Rechazar',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    _review(context, ref, document.id, true),
                                child: const Text(
                                  'Aprobar documento',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    String id,
    bool approved,
  ) async {
    String? reason;
    if (!approved) {
      final controller = TextEditingController();
      reason = await showAppDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Motivo del rechazo'),
          content: AppTextField(
            controller: controller,
            label: 'Observación',
            maxLines: 3,
          ),
          actions: [
            SizedBox(
              width: 420,
              child: AppDialogActions(
                cancelLabel: 'Cancelar',
                confirmLabel: 'Rechazar',
                onCancel: () => Navigator.pop(dialogContext),
                onConfirm: () {
                  if (controller.text.trim().length >= 3) {
                    Navigator.pop(dialogContext, controller.text.trim());
                  }
                },
              ),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null) return;
    }
    try {
      await ref
          .read(humanResourcesRepositoryProvider)
          .reviewProfessionalDocument(
            documentId: id,
            status: approved ? 'approved' : 'rejected',
            observation: reason,
          );
      ref.invalidate(professionalDocumentsProvider(professionalId));
      ref.invalidate(staffProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}
