import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';
import '../theme/app_spacing.dart';

class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    super.key,
    required this.children,
    this.maxWidth = AppDimensions.contentMaxWidth,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.spacing = AppSpacing.lg,
  });

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView.separated(
          padding: padding,
          itemCount: children.length,
          separatorBuilder: (_, __) => SizedBox(height: spacing),
          itemBuilder: (_, index) => children[index],
        ),
      ),
    );
  }
}

class AdaptiveTwoColumnPage extends StatelessWidget {
  const AdaptiveTwoColumnPage({
    super.key,
    required this.primary,
    required this.secondary,
    this.maxWidth = AppDimensions.contentMaxWidth,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.spacing = AppSpacing.lg,
    this.primaryFlex = 2,
    this.secondaryFlex = 1,
    this.breakpoint = AppDimensions.expandedBreakpoint,
  });

  final List<Widget> primary;
  final List<Widget> secondary;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final int primaryFlex;
  final int secondaryFlex;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= breakpoint;
        if (!isWide) {
          return AdaptivePage(
            maxWidth: AppDimensions.formMaxWidth + 240,
            padding: padding,
            spacing: spacing,
            children: [...primary, ...secondary],
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: primaryFlex,
                    child: _ColumnStack(spacing: spacing, children: primary),
                  ),
                  SizedBox(width: spacing),
                  Expanded(
                    flex: secondaryFlex,
                    child: _ColumnStack(spacing: spacing, children: secondary),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ColumnStack extends StatelessWidget {
  const _ColumnStack({required this.children, required this.spacing});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) SizedBox(height: spacing),
          children[index],
        ],
      ],
    );
  }
}
