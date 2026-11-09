import 'package:dio/dio.dart';

import '../../../../core/storage/session_storage.dart';
import '../../domain/app_user.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_session.dart';
import 'auth_api.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({required AuthApi api, required SessionStorage storage})
    : _api = api,
      _storage = storage;

  final AuthApi _api;
  final SessionStorage _storage;

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final session = (await _api.login(
        email: email,
        password: password,
      )).toDomain();
      await _persist(session);
      return session.user;
    } on DioException catch (error) {
      throw AuthException(_messageFrom(error));
    } on FormatException {
      throw const AuthException(
        'La respuesta del servidor no tiene el formato esperado.',
      );
    }
  }

  @override
  Future<AppUser?> restoreSession() async {
    final stored = await _storage.read();
    if (stored == null) {
      return null;
    }

    try {
      // Renovar al restaurar actualiza roles y permisos que pudieron cambiar
      // desde la última ejecución de la aplicación.
      return refreshSession();
    } catch (_) {
      await _storage.clear();
      rethrow;
    }
  }

  @override
  Future<AppUser> refreshSession() async {
    final stored = await _storage.read();
    if (stored == null) {
      throw const AuthException('No existe una sesión para renovar.');
    }

    try {
      final session = (await _api.refresh(stored.refreshToken)).toDomain();
      await _persist(session);
      return session.user;
    } on DioException catch (error) {
      await _storage.clear();
      throw AuthException(_messageFrom(error));
    }
  }

  @override
  Future<void> logout() async {
    final stored = await _storage.read();
    try {
      if (stored != null) {
        await _api.logout(stored.refreshToken);
      }
    } finally {
      await _storage.clear();
    }
  }

  @override
  Future<RegistrationRequest> requestRegistration(String email) async {
    try {
      final response = await _api.requestRegistration(email);
      return RegistrationRequest(
        message: response['message'] as String,
        developmentToken: response['developmentToken'] as String?,
      );
    } on DioException catch (error) {
      throw AuthException(_messageFrom(error));
    }
  }

  @override
  Future<void> completeRegistration(RegistrationData registration) async {
    String? optional(String? value) {
      final normalized = value?.trim();
      return normalized == null || normalized.isEmpty ? null : normalized;
    }

    try {
      await _api.completeRegistration({
        'token': registration.token.trim(),
        'password': registration.password,
        'firstName': registration.firstName.trim(),
        'lastName': registration.lastName.trim(),
        'secondLastName': optional(registration.secondLastName),
        'phone': optional(registration.phone),
        'birthDate': registration.birthDate.toIso8601String().split('T').first,
        'documentType': optional(registration.documentType),
        'documentNumber': optional(registration.documentNumber),
        'municipality': optional(registration.municipality),
        'zone': optional(registration.zone),
        'addressLine': optional(registration.addressLine),
        'acceptRequiredConsents': registration.acceptRequiredConsents,
        'guardianEmail': optional(registration.guardianEmail)?.toLowerCase(),
        'guardianRelationship': optional(registration.guardianRelationship),
      });
    } on DioException catch (error) {
      throw AuthException(_messageFrom(error));
    }
  }

  @override
  Future<PasswordResetRequest> requestPasswordReset(String email) async {
    try {
      final response = await _api.requestPasswordReset(email);
      return PasswordResetRequest(
        message: response['message'] as String,
        developmentToken: response['developmentToken'] as String?,
      );
    } on DioException catch (error) {
      throw AuthException(_messageFrom(error));
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _api.resetPassword(token: token, newPassword: newPassword);
    } on DioException catch (error) {
      throw AuthException(_messageFrom(error));
    }
  }

  Future<void> _persist(AuthSession session) {
    return _storage.write(
      StoredSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      ),
    );
  }

  String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
      if (message is List) {
        return message.whereType<String>().join('\n');
      }
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'No se pudo conectar con el servidor.';
    }

    return 'No se pudo completar la autenticación.';
  }
}
