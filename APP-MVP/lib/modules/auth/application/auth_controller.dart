import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../app/config/api_config.dart';
import '../../../core/storage/secure_session_storage.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../infrastructure/api/api_auth_repository.dart';
import '../infrastructure/api/auth_api.dart';
import '../../notifications/application/push_notifications_service.dart';

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => SecureSessionStorage(const FlutterSecureStorage()),
);

final authApiProvider = Provider<AuthApi>((ref) {
  final config = ref.watch(apiConfigProvider);
  return AuthApi(
    Dio(
      BaseOptions(
        baseUrl: config.baseUrl.toString(),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    ),
  );
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(
    api: ref.watch(authApiProvider),
    storage: ref.watch(sessionStorageProvider),
  ),
);

enum AuthStatus {
  restoring,
  unauthenticated,
  authenticating,
  authenticated,
  failure,
}

class AuthState {
  const AuthState({required this.status, this.user, this.errorMessage});

  const AuthState.restoring() : this(status: AuthStatus.restoring);

  final AuthStatus status;
  final AppUser? user;
  final String? errorMessage;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  bool get isLoading =>
      status == AuthStatus.restoring || status == AuthStatus.authenticating;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(restoreSession);
    return const AuthState.restoring();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> restoreSession() async {
    state = const AuthState.restoring();
    try {
      final user = await _repository.restoreSession();
      state = user == null
          ? const AuthState(status: AuthStatus.unauthenticated)
          : AuthState(status: AuthStatus.authenticated, user: user);
    } on AuthException catch (error) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: error.message,
      );
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String email, String password) async {
    state = const AuthState(status: AuthStatus.authenticating);
    try {
      final user = await _repository.login(email: email, password: password);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } on AuthException catch (error) {
      state = AuthState(
        status: AuthStatus.failure,
        errorMessage: error.message,
      );
      return false;
    } catch (_) {
      state = const AuthState(
        status: AuthStatus.failure,
        errorMessage: 'Ocurrió un error inesperado. Vuelve a intentarlo.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await ref.read(pushNotificationsServiceProvider).endSession();
      await _repository.logout();
    } finally {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> expireSession() async {
    await ref
        .read(pushNotificationsServiceProvider)
        .endSession(unregisterFromServer: false);
    await ref.read(sessionStorageProvider).clear();
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage: 'La sesión expiró. Inicia sesión nuevamente.',
    );
  }

  void clearError() {
    state = AuthState(
      status: state.isAuthenticated
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
      user: state.user,
    );
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
