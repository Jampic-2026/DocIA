import 'package:dio/dio.dart';

import '../storage/session_storage.dart';
import 'api_exception.dart';
import 'token_refresh_coordinator.dart';

class AuthenticatedApiClient {
  AuthenticatedApiClient({
    required Dio dio,
    required SessionStorage storage,
    required TokenRefreshCoordinator refreshCoordinator,
    required Future<void> Function() onSessionExpired,
  })  : _dio = dio,
        _storage = storage,
        _refreshCoordinator = refreshCoordinator,
        _onSessionExpired = onSessionExpired {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  static const _retriedRequestKey = 'jampic_auth_retried';

  final Dio _dio;
  final SessionStorage _storage;
  final TokenRefreshCoordinator _refreshCoordinator;
  final Future<void> Function() _onSessionExpired;

  String get baseUrl => _dio.options.baseUrl;
  BaseOptions get options => _dio.options;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _request(
      () => _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _request(
      () => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _request(
      () => _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _request(
      () => _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _request(
      () => _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final session = await _storage.read();
    if (session == null) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: const ApiException(message: 'No existe una sesión activa.'),
        ),
      );
      return;
    }

    options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final alreadyRetried = request.extra[_retriedRequestKey] == true;

    if (error.response?.statusCode != 401 || alreadyRetried) {
      handler.next(error);
      return;
    }

    try {
      final session = await _refreshCoordinator.refresh();
      request.extra[_retriedRequestKey] = true;
      request.headers['Authorization'] = 'Bearer ${session.accessToken}';
      final response = await _dio.fetch<dynamic>(request);
      handler.resolve(response);
    } catch (_) {
      await _onSessionExpired();
      handler.reject(
        DioException(
          requestOptions: request,
          response: error.response,
          type: DioExceptionType.badResponse,
          error: const ApiException(
            message: 'La sesión expiró. Inicia sesión nuevamente.',
            statusCode: 401,
          ),
        ),
      );
    }
  }

  Future<Response<T>> _request<T>(
    Future<Response<T>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      final apiError = error.error;
      if (apiError is ApiException) {
        throw apiError;
      }
      throw _mapError(error);
    }
  }

  ApiException _mapError(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return ApiException(
          message: message,
          statusCode: error.response?.statusCode,
          code: data['code'] as String?,
        );
      }
      if (message is List) {
        return ApiException(
          message: message.whereType<String>().join('\n'),
          statusCode: error.response?.statusCode,
          code: data['code'] as String?,
        );
      }
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return const ApiException(
        message: 'No se pudo conectar con el servidor.',
      );
    }

    return ApiException(
      message: 'No se pudo completar la solicitud.',
      statusCode: error.response?.statusCode,
    );
  }
}
