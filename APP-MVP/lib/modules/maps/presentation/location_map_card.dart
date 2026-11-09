import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/location_preview.dart';

class LocationMapCard extends StatelessWidget {
  const LocationMapCard({
    super.key,
    required this.preview,
    required this.loading,
    required this.onLocate,
    this.message,
  });

  final LocationPreview? preview;
  final bool loading;
  final VoidCallback onLocate;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (preview?.imageBytes != null)
              Image.memory(preview!.imageBytes!, fit: BoxFit.cover)
            else
              ColoredBox(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.emergencySurfaceDark
                    : AppColors.emergencySurfaceLight,
                child: Center(
                  child: Icon(
                    preview == null
                        ? Icons.location_searching_rounded
                        : Icons.location_on_rounded,
                    color: AppColors.danger,
                    size: 44,
                  ),
                ),
              ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  onTap: loading ? null : onLocate,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      children: [
                        if (loading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(
                            Icons.my_location_rounded,
                            size: 18,
                            color: AppColors.teal,
                          ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            message ??
                                preview?.address ??
                                'Toca para obtener tu ubicación',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
