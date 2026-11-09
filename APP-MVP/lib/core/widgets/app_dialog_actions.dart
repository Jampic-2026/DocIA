import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';
import '../theme/app_spacing.dart';

class AppDialogActions extends StatelessWidget {
  const AppDialogActions({
    super.key,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.confirmIcon,
    this.busy = false,
    this.confirmEnabled = true,
    this.busyLabel,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final IconData? confirmIcon;
  final bool busy;
  final bool confirmEnabled;
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    final cancel = SizedBox(
      height: AppDimensions.buttonHeight,
      child: OutlinedButton(
        onPressed: busy ? null : onCancel,
        child: Text(cancelLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
    final confirmChild = Text(
      busy ? busyLabel ?? 'Guardando...' : confirmLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final confirm = SizedBox(
      height: AppDimensions.buttonHeight,
      child: confirmIcon == null
          ? FilledButton(
              onPressed: busy || !confirmEnabled ? null : onConfirm,
              child: confirmChild,
            )
          : FilledButton.icon(
              onPressed: busy || !confirmEnabled ? null : onConfirm,
              icon: Icon(confirmIcon),
              label: confirmChild,
            ),
    );

    return Row(
      children: [
        Expanded(child: cancel),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: confirm),
      ],
    );
  }
}
