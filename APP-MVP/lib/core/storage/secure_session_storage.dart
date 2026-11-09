import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_storage.dart';

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage(this._storage);

  static const _accessTokenKey = 'jampic_access_token';
  static const _refreshTokenKey = 'jampic_refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    final values = await _storage.readAll();
    final accessToken = values[_accessTokenKey];
    final refreshToken = values[_refreshTokenKey];

    if (accessToken == null || refreshToken == null) {
      return null;
    }

    return StoredSession(accessToken: accessToken, refreshToken: refreshToken);
  }

  @override
  Future<void> write(StoredSession session) async {
    // On first use, the web implementation creates its encryption key lazily.
    // Concurrent writes can create different keys and leave one token unreadable.
    await _storage.write(key: _accessTokenKey, value: session.accessToken);
    await _storage.write(key: _refreshTokenKey, value: session.refreshToken);
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }
}
