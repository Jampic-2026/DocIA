import 'package:dio/dio.dart';
import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/files_repository.dart';
import '../../domain/stored_file.dart';

class ApiFilesRepository implements FilesRepository {
  ApiFilesRepository(this._client);
  final AuthenticatedApiClient _client;

  @override
  Future<StoredFile> upload({
    required List<int> bytes,
    required String fileName,
    required String category,
  }) async {
    final data = FormData.fromMap({
      'category': category,
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final response = await _client.post<Map<String, dynamic>>(
      'files',
      data: data,
      options: Options(contentType: 'multipart/form-data'),
    );
    final json = response.data!;
    return StoredFile(
      key: json['key'] as String,
      fileName: json['fileName'] as String,
      mimeType: json['mimeType'] as String,
      size: json['size'] as int,
      fileUrl: json['fileUrl'] as String,
    );
  }

  @override
  Future<String> accessUrl(String fileUrl) async {
    final trimmed = fileUrl.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri != null &&
        uri.queryParameters.containsKey('signature') &&
        uri.queryParameters.containsKey('expires')) {
      final clientBaseUri = Uri.tryParse(_client.options.baseUrl);
      if (clientBaseUri != null && clientBaseUri.hasAuthority) {
        return uri
            .replace(
              scheme: clientBaseUri.scheme,
              host: clientBaseUri.host,
              port: clientBaseUri.port,
            )
            .toString();
      }
      return trimmed;
    }

    String key = '';
    if (uri != null && uri.pathSegments.contains('files')) {
      final filesIndex = uri.pathSegments.indexOf('files');
      if (filesIndex >= 0 && filesIndex + 2 < uri.pathSegments.length) {
        key =
            '${uri.pathSegments[filesIndex + 1]}/${uri.pathSegments[filesIndex + 2]}';
      }
    }

    if (key.isEmpty) {
      final clean = trimmed.replaceAll(RegExp(r'^/+'), '');
      final parts = clean.split('/');
      if (parts.length == 2 && !clean.contains('://')) {
        key = clean;
      }
    }

    if (key.isEmpty) {
      return trimmed;
    }

    final response = await _client.post<Map<String, dynamic>>(
      'files/access',
      data: {'key': key},
    );
    final rawSignedUrl = response.data!['url'] as String;

    final clientBaseUri = Uri.tryParse(_client.options.baseUrl);
    final signedUri = Uri.tryParse(rawSignedUrl);
    if (clientBaseUri != null &&
        signedUri != null &&
        clientBaseUri.hasAuthority) {
      return signedUri
          .replace(
            scheme: clientBaseUri.scheme,
            host: clientBaseUri.host,
            port: clientBaseUri.port,
          )
          .toString();
    }
    return rawSignedUrl;
  }
}
