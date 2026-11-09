import '../storage/session_storage.dart';

class TokenRefreshCoordinator {
  TokenRefreshCoordinator({
    required SessionStorage storage,
    required Future<void> Function() refreshSession,
  })  : _storage = storage,
        _refreshSession = refreshSession;

  final SessionStorage _storage;
  final Future<void> Function() _refreshSession;

  Future<StoredSession>? _refreshOperation;

  Future<StoredSession> refresh() {
    final activeOperation = _refreshOperation;
    if (activeOperation != null) {
      return activeOperation;
    }

    final operation = _performRefresh();
    _refreshOperation = operation;
    return operation.whenComplete(() {
      if (identical(_refreshOperation, operation)) {
        _refreshOperation = null;
      }
    });
  }

  Future<StoredSession> _performRefresh() async {
    await _refreshSession();
    final session = await _storage.read();

    if (session == null) {
      throw const SessionRefreshException(
        'La sesión no pudo renovarse.',
      );
    }

    return session;
  }
}

class SessionRefreshException implements Exception {
  const SessionRefreshException(this.message);

  final String message;

  @override
  String toString() => message;
}
