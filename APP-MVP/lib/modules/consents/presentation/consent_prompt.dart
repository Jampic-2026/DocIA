import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/widgets.dart';
import '../application/consents_controller.dart';

Future<bool> ensureConsentAccepted({
  required BuildContext context,
  required WidgetRef ref,
  required String code,
  required String serviceName,
}) async {
  final repository = ref.read(consentsRepositoryProvider);
  final consents = await repository.list();
  final consent = consents.where((item) => item.code == code).firstOrNull;

  if (consent == null) {
    throw StateError('No se encontró el consentimiento requerido.');
  }
  if (consent.isAccepted) return true;
  if (!context.mounted) return false;

  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Permitir $serviceName'),
      content: Text(
        '${consent.description ?? consent.name}\n\n'
        'Para continuar debes aceptar “${consent.name}”, '
        'versión ${consent.version}. Puedes retirar esta autorización '
        'después desde Mi cuenta.',
      ),
      actions: [
        SizedBox(
          width: 420,
          child: AppDialogActions(
            cancelLabel: 'Ahora no',
            confirmLabel: 'Aceptar y continuar',
            onCancel: () => Navigator.pop(dialogContext, false),
            onConfirm: () => Navigator.pop(dialogContext, true),
          ),
        ),
      ],
    ),
  );

  if (accepted != true) return false;
  await repository.accept(code);
  ref.invalidate(consentsControllerProvider);
  return true;
}
