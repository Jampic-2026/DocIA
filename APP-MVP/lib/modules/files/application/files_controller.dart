import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client_provider.dart';
import '../domain/files_repository.dart';
import '../infrastructure/api/api_files_repository.dart';

final filesRepositoryProvider = Provider<FilesRepository>(
  (ref) => ApiFilesRepository(ref.watch(authenticatedApiClientProvider)),
);

final signedFileUrlProvider =
    FutureProvider.family<String, String>((ref, fileUrl) async {
  if (fileUrl.trim().isEmpty) return '';
  return ref.watch(filesRepositoryProvider).accessUrl(fileUrl);
});

