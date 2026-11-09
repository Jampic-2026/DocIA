import 'package:dio/dio.dart';

import 'auth_dto.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthSessionDto> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/login',
      data: {'email': email.trim().toLowerCase(), 'password': password},
    );
    return AuthSessionDto.fromJson(response.data!);
  }

  Future<AuthSessionDto> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return AuthSessionDto.fromJson(response.data!);
  }

  Future<AuthUserDto> me(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'auth/me',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = response.data!;
    return AuthUserDto.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post<void>('auth/logout', data: {'refreshToken': refreshToken});
  }

  Future<Map<String, dynamic>> requestRegistration(String email) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/registration/request',
      data: {'email': email.trim().toLowerCase()},
    );
    return response.data!;
  }

  Future<void> completeRegistration(Map<String, dynamic> data) async {
    await _dio.post<void>('auth/registration/complete', data: data);
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/password-reset/request',
      data: {'email': email.trim().toLowerCase()},
    );
    return response.data!;
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _dio.post<void>(
      'auth/password-reset/confirm',
      data: {'token': token.trim(), 'newPassword': newPassword},
    );
  }
}
