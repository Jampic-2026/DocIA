import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/api_config.dart';
import '../../modules/auth/application/auth_controller.dart';
import 'authenticated_api_client.dart';
import 'token_refresh_coordinator.dart';

final tokenRefreshCoordinatorProvider = Provider<TokenRefreshCoordinator>(
  (ref) => TokenRefreshCoordinator(
    storage: ref.watch(sessionStorageProvider),
    refreshSession: () async {
      await ref.read(authRepositoryProvider).refreshSession();
    },
  ),
);

final authenticatedApiClientProvider = Provider<AuthenticatedApiClient>((ref) {
  // Vincula toda la capa autenticada con la identidad activa. Al cerrar sesión
  // o ingresar con otra cuenta se reconstruyen cliente, repositorios y datos
  // derivados, evitando reutilizar respuestas del usuario anterior.
  ref.watch(authControllerProvider.select((state) => state.user?.id));
  final config = ref.watch(apiConfigProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.baseUrl.toString(),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  return AuthenticatedApiClient(
    dio: dio,
    storage: ref.watch(sessionStorageProvider),
    refreshCoordinator: ref.watch(tokenRefreshCoordinatorProvider),
    onSessionExpired: () =>
        ref.read(authControllerProvider.notifier).expireSession(),
  );
});
