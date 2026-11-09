import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../modules/files/application/files_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Widget unificado para renderizar imágenes locales (Uint8List) o remotas firmadas (fileUrl)
/// con soporte para miniaturas, estados de carga, fallbacks y apertura en pantalla completa.
class AppSignedImage extends ConsumerWidget {
  const AppSignedImage({
    super.key,
    this.fileUrl,
    this.bytes,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackColor,
    this.enablePreview = false,
    this.previewTitle = 'Vista previa de imagen',
  });

  final String? fileUrl;
  final Uint8List? bytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final bool enablePreview;
  final String previewTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(AppRadius.sm);
    final effectiveWidth = width ?? 96.0;
    final effectiveHeight = height ?? 96.0;
    final hasLocal = bytes != null && bytes!.isNotEmpty;
    final hasRemote = fileUrl != null && fileUrl!.trim().isNotEmpty;
    final canOpen = enablePreview && (hasLocal || hasRemote);

    Widget content;
    if (hasLocal) {
      content = Image.memory(
        bytes!,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        errorBuilder: (_, __, ___) => _errorPlaceholder(context, effectiveWidth, effectiveHeight),
      );
    } else if (hasRemote) {
      final signedUrlAsync = ref.watch(signedFileUrlProvider(fileUrl!));
      content = signedUrlAsync.when(
        data: (signedUrl) {
          if (signedUrl.isEmpty) return _fallbackPlaceholder(context, effectiveWidth, effectiveHeight);
          return Image.network(
            signedUrl,
            width: effectiveWidth,
            height: effectiveHeight,
            fit: fit,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              final expected = loadingProgress.expectedTotalBytes;
              final loaded = loadingProgress.cumulativeBytesLoaded;
              final progress = expected != null && expected > 0 ? loaded / expected : null;
              return SizedBox(
                width: effectiveWidth,
                height: effectiveHeight,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: progress,
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (_, error, __) {
              return _errorPlaceholder(context, effectiveWidth, effectiveHeight);
            },
          );
        },
        loading: () => SizedBox(
          width: effectiveWidth,
          height: effectiveHeight,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, __) => _errorPlaceholder(context, effectiveWidth, effectiveHeight),
      );
    } else {
      content = _fallbackPlaceholder(context, effectiveWidth, effectiveHeight);
    }

    final decorated = ClipRRect(
      borderRadius: effectiveRadius,
      child: SizedBox(
        width: effectiveWidth,
        height: effectiveHeight,
        child: content,
      ),
    );

    if (!canOpen) return decorated;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: effectiveRadius,
        onTap: () => showImagePreviewDialog(
          context,
          fileUrl: fileUrl,
          bytes: bytes,
          title: previewTitle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            decorated,
            Positioned(
              right: 4,
              bottom: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.zoom_out_map_rounded,
                    color: AppColors.white,
                    size: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackPlaceholder(BuildContext context, double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Center(
        child: Icon(
          fallbackIcon,
          size: (w * 0.4).clamp(18.0, 48.0),
          color: fallbackColor ?? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _errorPlaceholder(BuildContext context, double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: (w * 0.4).clamp(18.0, 48.0),
          color: AppColors.danger.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

/// Muestra un modal interactivo para visualizar la imagen en alta resolución con zoom y paneo.
Future<void> showImagePreviewDialog(
  BuildContext context, {
  String? fileUrl,
  Uint8List? bytes,
  required String title,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 640,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Container(
                color: AppColors.black.withValues(alpha: 0.04),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final canvasWidth = constraints.maxWidth > 0 ? constraints.maxWidth : 600.0;
                    final canvasHeight = constraints.maxHeight > 0 ? constraints.maxHeight : 460.0;
                    return InteractiveViewer(
                      clipBehavior: Clip.hardEdge,
                      minScale: 0.8,
                      maxScale: 5.0,
                      boundaryMargin: const EdgeInsets.all(32),
                      child: SizedBox(
                        width: canvasWidth,
                        height: canvasHeight,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: _PreviewImageContent(
                              fileUrl: fileUrl,
                              bytes: bytes,
                              width: canvasWidth - 32,
                              height: canvasHeight - 32,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.max,
                children: [
                  if (fileUrl != null && fileUrl.trim().isNotEmpty) ...[
                    Consumer(
                      builder: (context, ref, _) {
                        return TextButton.icon(
                          onPressed: () async {
                            try {
                              final signedUrl = await ref.read(filesRepositoryProvider).accessUrl(fileUrl);
                              final uri = Uri.tryParse(signedUrl);
                              if (uri != null) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Abrir original'),
                        );
                      },
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  SizedBox(
                    width: 140,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PreviewImageContent extends ConsumerWidget {
  const _PreviewImageContent({
    this.fileUrl,
    this.bytes,
    required this.width,
    required this.height,
  });

  final String? fileUrl;
  final Uint8List? bytes;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bytes != null && bytes!.isNotEmpty) {
      return Image.memory(
        bytes!,
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _errorIcon(),
      );
    }

    if (fileUrl != null && fileUrl!.trim().isNotEmpty) {
      return FutureBuilder<String>(
        future: ref.read(filesRepositoryProvider).accessUrl(fileUrl!),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _errorIcon();
          }
          if (!snapshot.hasData) {
            return SizedBox(
              width: width,
              height: height,
              child: const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            );
          }
          final signedUrl = snapshot.data!;
          if (signedUrl.isEmpty) {
            return _emptyIcon();
          }
          return Image.network(
            signedUrl,
            width: width,
            height: height,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              final expected = loadingProgress.expectedTotalBytes;
              final loaded = loadingProgress.cumulativeBytesLoaded;
              final progress = expected != null && expected > 0 ? loaded / expected : null;
              return SizedBox(
                width: width,
                height: height,
                child: Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 3, value: progress),
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => _errorIcon(),
          );
        },
      );
    }

    return _emptyIcon();
  }

  Widget _errorIcon() => SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: AppColors.danger,
          ),
        ),
      );

  Widget _emptyIcon() => SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 64,
            color: AppColors.textSecondaryLight,
          ),
        ),
      );
}
