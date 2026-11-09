import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';
import '../theme/app_spacing.dart';

/// Equal-width actions in the same horizontal row as existing form actions.
class AppActionRow extends StatelessWidget {
  const AppActionRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var index = 0; index < children.length; index++) ...[
        if (index > 0) const SizedBox(width: AppSpacing.md),
        Expanded(
          child: SizedBox(
            height: AppDimensions.buttonHeight,
            child: Tooltip(
              message:
                  children[index] is ButtonStyleButton &&
                      (children[index] as ButtonStyleButton).child is Text
                  ? ((children[index] as ButtonStyleButton).child as Text)
                            .data ??
                        ''
                  : '',
              child: children[index],
            ),
          ),
        ),
      ],
    ],
  );
}
