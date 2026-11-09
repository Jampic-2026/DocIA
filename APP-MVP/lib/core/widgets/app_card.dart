import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Tarjeta base de la aplicación con padding, borde y soporte de tap opcional.
///
/// Centraliza el estilo de "card" para mantener consistencia visual.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.border,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: color ?? scheme.surface,
      borderRadius: AppRadius.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: border ?? Border.all(color: scheme.outline),
          ),
          child: child,
        ),
      ),
    );
  }
}
