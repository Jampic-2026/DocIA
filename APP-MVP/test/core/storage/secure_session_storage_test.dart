import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jampic/core/storage/secure_session_storage.dart';
import 'package:jampic/core/storage/session_storage.dart';

// Models the web provider's lazy key creation: competing first writes can
// persist different encryption keys, making an otherwise saved token unreadable.
class _LazyKeyStorage extends FlutterSecureStorage {
  int? _persistedKey;
  int _nextKey = 0;
  final values = <String, (int, String)>{};

  Future<int> _encryptionKey() async {
    final existing = _persistedKey;
    if (existing != null) return existing;
    final generated = ++_nextKey;
    await Future<void>.delayed(Duration.zero);
    _persistedKey = generated;
    return generated;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values[key] = (await _encryptionKey(), value!);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (values.values.any((entry) => entry.$1 != _persistedKey)) {
      throw StateError('A token cannot be decrypted with the persisted key.');
    }
    return values.map((key, value) => MapEntry(key, value.$2));
  }
}

void main() {
  test(
    'the first stored session can be read with the existing token keys',
    () async {
      final provider = _LazyKeyStorage();
      final storage = SecureSessionStorage(provider);
      await storage.write(
        const StoredSession(
          accessToken: 'synthetic-access',
          refreshToken: 'synthetic-refresh',
        ),
      );
      final session = await storage.read();
      expect(session?.accessToken, 'synthetic-access');
      expect(session?.refreshToken, 'synthetic-refresh');
      expect(
        provider.values.keys,
        unorderedEquals(['jampic_access_token', 'jampic_refresh_token']),
      );
    },
  );

  test(
    'refresh replaces both tokens while preserving readable storage',
    () async {
      final storage = SecureSessionStorage(_LazyKeyStorage());
      await storage.write(
        const StoredSession(
          accessToken: 'synthetic-old-access',
          refreshToken: 'synthetic-old-refresh',
        ),
      );
      await storage.write(
        const StoredSession(
          accessToken: 'synthetic-new-access',
          refreshToken: 'synthetic-new-refresh',
        ),
      );
      final session = await storage.read();
      expect(session?.accessToken, 'synthetic-new-access');
      expect(session?.refreshToken, 'synthetic-new-refresh');
    },
  );
}
