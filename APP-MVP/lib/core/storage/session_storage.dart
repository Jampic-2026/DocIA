class StoredSession {
  const StoredSession({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

abstract interface class SessionStorage {
  Future<StoredSession?> read();

  Future<void> write(StoredSession session);

  Future<void> clear();
}
