import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/consents_controller.dart';
import '../domain/consent_preference.dart';

class ConsentsScreen extends ConsumerWidget {
  const ConsentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consents = ref.watch(consentsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y consentimientos')),
      body: consents.when(
        loading: () =>
            const AppLoadingState(message: 'Cargando tus preferencias'),
        error: (error, _) => AppErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(consentsControllerProvider),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(consentsControllerProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Preferencias de privacidad',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Los términos y la política de privacidad se aceptan al crear '
                'la cuenta. Las autorizaciones opcionales de tu usuario pueden '
                'administrarse desde esta sección.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              ...items.map(
                (consent) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _ConsentCard(
                    consent: consent,
                    disabled: consents.isRefreshing || consent.isRequired,
                    onChanged: (value) =>
                        _confirmChange(context, ref, consent, value),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmChange(
    BuildContext context,
    WidgetRef ref,
    ConsentPreference consent,
    bool accepted,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          accepted ? 'Aceptar consentimiento' : 'Retirar consentimiento',
        ),
        content: Text(
          accepted
              ? 'Confirmas que leíste y aceptas “${consent.name}”, versión ${consent.version}.'
              : 'Al retirar “${consent.name}”, los servicios relacionados podrían dejar de estar disponibles.',
        ),
        actions: [
          SizedBox(
            width: 420,
            child: AppDialogActions(
              cancelLabel: 'Cancelar',
              confirmLabel: accepted ? 'Aceptar' : 'Retirar',
              onCancel: () => Navigator.pop(dialogContext, false),
              onConfirm: () => Navigator.pop(dialogContext, true),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref
        .read(consentsControllerProvider.notifier)
        .setAccepted(consent, accepted);
    if (!context.mounted) return;
    final result = ref.read(consentsControllerProvider);
    result.whenOrNull(
      error: (error, _) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString()))),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.consent,
    required this.disabled,
    required this.onChanged,
  });

  final ConsentPreference consent;
  final bool disabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  consent.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch.adaptive(
                value: consent.isAccepted,
                activeThumbColor: AppColors.teal,
                onChanged: disabled ? null : onChanged,
              ),
            ],
          ),
          if (consent.description case final description?
              when description.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(description),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              StatusPill(
                label: consent.isAccepted ? 'Aceptado' : 'No aceptado',
                color: consent.isAccepted
                    ? AppColors.success
                    : AppColors.warning,
                dense: true,
              ),
              if (consent.isRequired)
                const StatusPill(
                  label: 'Obligatorio',
                  color: AppColors.info,
                  dense: true,
                ),
              Text(
                'Versión ${consent.version}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (consent.acceptedAt case final acceptedAt?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Aceptado el ${_formatDate(acceptedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}
