import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../modules/files/application/files_controller.dart';

/// Requests a fresh, authorized access URL only when the user opens the file.
class AppFileLink extends ConsumerWidget {
  const AppFileLink({
    super.key,
    required this.fileUrl,
    this.label = 'Abrir documento',
  });
  final String fileUrl;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton.icon(
    icon: const Icon(Icons.open_in_new),
    label: Text(label),
    onPressed: () async {
      try {
        final url = await ref.read(filesRepositoryProvider).accessUrl(fileUrl);
        final uri = Uri.tryParse(url);
        if (uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw StateError('No se pudo abrir el documento.');
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    },
  );
}
