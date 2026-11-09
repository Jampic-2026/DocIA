import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jampic/core/network/token_refresh_coordinator.dart';
import 'package:jampic/core/storage/session_storage.dart';

void main() {
  test('comparte una sola renovación entre solicitudes concurrentes', () async {
    final storage = _MemorySessionStorage();
    final refreshStarted = Completer<void>();
    final releaseRefresh = Completer<void>();
    var refreshCount = 0;

    final coordinator = TokenRefreshCoordinator(
      storage: storage,
      refreshSession: () async {
        refreshCount++;
        refreshStarted.complete();
        await releaseRefresh.future;
        await storage.write(
          const StoredSession(
            accessToken: 'new-access-token',
            refreshToken: 'new-refresh-token',
          ),
        );
      },
    );

    final first = coordinator.refresh();
    await refreshStarted.future;
    final second = coordinator.refresh();
    releaseRefresh.complete();

    final sessions = await Future.wait([first, second]);

    expect(refreshCount, 1);
    expect(sessions[0].accessToken, 'new-access-token');
    expect(sessions[1].accessToken, 'new-access-token');
  });
}

class _MemorySessionStorage implements SessionStorage {
  StoredSession? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<StoredSession?> read() async => value;

  @override
  Future<void> write(StoredSession session) async => value = session;
}
