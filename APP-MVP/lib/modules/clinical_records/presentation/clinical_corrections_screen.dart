import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../application/clinical_records_controller.dart';
import '../domain/clinical_correction_request.dart';

class ClinicalCorrectionsScreen extends ConsumerWidget {
  const ClinicalCorrectionsScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(authControllerProvider).user?.roles ?? <String>{};
    final canResolve = roles.contains('admin') || roles.contains('clinical_supervisor');
    final content = ref.watch(clinicalCorrectionRequestsProvider).when(
          loading: () => const AppLoadingState(message: 'Cargando solicitudes'),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(clinicalCorrectionRequestsProvider),
          ),
          data: (requests) => requests.isEmpty
              ? const EmptyState(
                  icon: Icons.rule_folder_outlined,
                  title: 'Sin solicitudes de corrección',
                  message: 'Las solicitudes aparecerán aquí.',
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(clinicalCorrectionRequestsProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (_, index) => _CorrectionCard(
                      request: requests[index],
                      canResolve: canResolve,
                    ),
                  ),
                ),
        );
    return embedded
        ? content
        : Scaffold(
            appBar: AppBar(title: const Text('Correcciones clínicas')),
            body: content,
          );
  }
}

class _CorrectionCard extends ConsumerWidget {
  const _CorrectionCard({required this.request, required this.canResolve});
  final ClinicalCorrectionRequest request;
  final bool canResolve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presentation = _statusPresentation(request.status);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(request.recordTitle ?? 'Registro clínico', style: const TextStyle(fontWeight: FontWeight.w700)),
            if (canResolve) Text(request.patientName, style: Theme.of(context).textTheme.bodySmall),
          ])),
          StatusPill(label: presentation.$1, color: presentation.$2, dense: true),
        ]),
        const SizedBox(height: AppSpacing.md),
        Text('Cambio solicitado', style: Theme.of(context).textTheme.labelMedium),
        Text(request.requestedChange),
        const SizedBox(height: AppSpacing.sm),
        Text('Motivo: ${request.reason}', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        Text(DateFormat('dd/MM/yyyy HH:mm').format(request.createdAt), style: Theme.of(context).textTheme.bodySmall),
        if (request.resolution?.isNotEmpty ?? false) ...[
          const Divider(height: AppSpacing.lg),
          Text('Resolución: ${request.resolution}'),
        ],
        if (canResolve && request.status == 'pending') ...[
          const Divider(height: AppSpacing.lg),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => _resolve(context, ref, 'rejected'), child: const Text('Rechazar')),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(onPressed: () => _resolve(context, ref, 'accepted'), child: const Text('Aceptar corrección')),
          ]),
        ],
      ]),
    );
  }

  Future<void> _resolve(BuildContext context, WidgetRef ref, String status) async {
    final controller = TextEditingController();
    final resolution = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(status == 'accepted' ? 'Aceptar corrección' : 'Rechazar corrección'),
        content: AppTextField(controller: controller, label: 'Resolución', maxLines: 3),
        actions: [
          SizedBox(
            width: 420,
            child: AppDialogActions(
              cancelLabel: 'Cancelar',
              confirmLabel: 'Confirmar',
              onCancel: () => Navigator.pop(dialogContext),
              onConfirm: () {
                final value = controller.text.trim();
                if (value.length >= 3) Navigator.pop(dialogContext, value);
              },
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (resolution == null) return;
    try {
      await ref.read(clinicalRecordsRepositoryProvider).resolveCorrectionRequest(
            requestId: request.id,
            status: status,
            resolution: resolution,
          );
      ref.invalidate(clinicalCorrectionRequestsProvider);
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

(String, Color) _statusPresentation(String status) => switch (status) {
      'accepted' => ('Aceptada', AppColors.success),
      'rejected' => ('Rechazada', AppColors.danger),
      _ => ('Pendiente', AppColors.warning),
    };
