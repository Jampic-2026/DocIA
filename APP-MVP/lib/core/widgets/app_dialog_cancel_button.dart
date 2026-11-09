import 'package:flutter/material.dart';

/// Acción secundaria reutilizable para cancelar o cerrar un diálogo.
class AppDialogCancelButton extends StatelessWidget {
  const AppDialogCancelButton({
    super.key,
    required this.onPressed,
    this.label = 'Cancelar',
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(104, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: Text(label),
    );
  }
}
