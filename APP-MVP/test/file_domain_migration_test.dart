import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jampic/core/network/authenticated_api_client.dart';
import 'package:jampic/modules/files/infrastructure/api/api_files_repository.dart';

class _FileClient extends Fake implements AuthenticatedApiClient {
  _FileClient(this.currentBaseUrl);
  final String currentBaseUrl;
  final requests = <RequestOptions>[];

  @override
  BaseOptions get options => BaseOptions(baseUrl: currentBaseUrl);

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final request = RequestOptions(path: path, data: data);
    requests.add(request);
    return Response<T>(
      requestOptions: request,
      data:
          <String, dynamic>{
                'url':
                    'http://localhost:3000/api/v1/files/documents/id.pdf?signature=synthetic&expires=2000000000',
              }
              as T,
    );
  }
}

void main() {
  test(
    'stored URLs from a previous domain request access through the configured API',
    () async {
      final client = _FileClient('https://api.example.com/api/v1/');
      final result = Uri.parse(
        await ApiFilesRepository(client).accessUrl(
          'https://previous-api.example.com/api/v1/files/documents/id.pdf',
        ),
      );
      expect(client.requests.single.path, 'files/access');
      expect(client.requests.single.data, {'key': 'documents/id.pdf'});
      expect(result.origin, 'https://api.example.com');
      expect(result.queryParameters['signature'], 'synthetic');
      expect(result.hasPort, isFalse);
    },
  );

  test(
    'already signed URLs use the new API origin without retaining the old port',
    () async {
      final client = _FileClient('https://api.example.com/api/v1/');
      final result = Uri.parse(
        await ApiFilesRepository(client).accessUrl(
          'http://previous-api.example.com:3000/api/v1/files/documents/id.pdf?signature=synthetic&expires=2000000000',
        ),
      );
      expect(client.requests, isEmpty);
      expect(result.origin, 'https://api.example.com');
      expect(result.path, '/api/v1/files/documents/id.pdf');
      expect(result.queryParameters['expires'], '2000000000');
      expect(result.hasPort, isFalse);
    },
  );

  test(
    'explicit development ports follow the configured API rather than the old URL',
    () async {
      final client = _FileClient('http://localhost:3100/api/v1/');
      final result = Uri.parse(
        await ApiFilesRepository(client).accessUrl(
          'http://previous-api.example.com:3000/api/v1/files/documents/id.pdf?signature=synthetic&expires=2000000000',
        ),
      );
      expect(result.origin, 'http://localhost:3100');
    },
  );
}
