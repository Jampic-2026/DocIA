import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/integrations_controller.dart';
import '../domain/google_workspace_status.dart';

class GoogleWorkspaceScreen extends ConsumerWidget {
  const GoogleWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(googleWorkspaceStatusProvider)
        .when(
          loading: () =>
              const AppLoadingState(message: 'Consultando Google Workspace'),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(googleWorkspaceStatusProvider),
          ),
          data: (status) => RefreshIndicator(
            onRefresh: () => ref.refresh(googleWorkspaceStatusProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const SectionHeader(
                  title: 'Google Workspace',
                  subtitle:
                      'Cuenta institucional utilizada para crear salas de telemedicina.',
                ),
                const SizedBox(height: AppSpacing.md),
                _ConnectionCard(status: status),
                const SizedBox(height: AppSpacing.lg),
                if (status.connected) ...[
                  FilledButton.icon(
                    onPressed: () => _connect(context, ref),
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Volver a autorizar'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => _disconnect(context, ref),
                    icon: const Icon(Icons.link_off_rounded),
                    label: const Text('Desconectar Google Workspace'),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: () => _connect(context, ref),
                    icon: const Icon(Icons.add_link_rounded),
                    label: const Text('Conectar Google Workspace'),
                  ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'La autorización se realiza en Google. Doc IA guarda los tokens '
                        'cifrados únicamente en la API y nunca en la aplicación.',
                      ),
                      if (status.redirectUri.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'URI de redirección registrada',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SelectableText(status.redirectUri),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
  }

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    try {
      final uri = await ref
          .read(integrationsRepositoryProvider)
          .googleAuthorizationUrl();
      final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!opened) {
        throw Exception('No se pudo abrir la autorización de Google.');
      }
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Completa la autorización'),
          content: const Text(
            'Autoriza la cuenta institucional en Google y luego vuelve a '
            'Doc IA para actualizar el estado.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Ya autoricé la cuenta'),
            ),
          ],
        ),
      );
      ref.invalidate(googleWorkspaceStatusProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desconectar Google Workspace'),
        content: const Text(
          'No se podrán crear nuevas salas hasta volver a autorizar una cuenta.',
        ),
        actions: [
          SizedBox(
            width: 420,
            child: AppDialogActions(
              cancelLabel: 'Cancelar',
              confirmLabel: 'Desconectar',
              onCancel: () => Navigator.pop(dialogContext, false),
              onConfirm: () => Navigator.pop(dialogContext, true),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(integrationsRepositoryProvider).disconnectGoogle();
      ref.invalidate(googleWorkspaceStatusProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.status});

  final GoogleWorkspaceStatus status;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                (status.connected ? AppColors.success : AppColors.warning)
                    .withValues(alpha: 0.12),
            child: Icon(
              status.connected
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_off_rounded,
              color: status.connected ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.connected ? 'Cuenta conectada' : 'Sin conexión',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (status.connectedByName?.trim().isNotEmpty ?? false)
                  Text('Autorizada por ${status.connectedByName}'),
                if (status.expiresAt != null)
                  Text(
                    'Acceso vigente hasta ${DateFormat('dd/MM/yyyy HH:mm').format(status.expiresAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          StatusPill(
            label: status.connected ? 'Conectado' : 'Pendiente',
            color: status.connected ? AppColors.success : AppColors.warning,
            dense: true,
          ),
        ],
      ),
    );
  }
}
