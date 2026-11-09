import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/consent_preference.dart';
import '../domain/consents_repository.dart';
import '../infrastructure/api/api_consents_repository.dart';

final consentsRepositoryProvider = Provider<ConsentsRepository>(
  (ref) => ApiConsentsRepository(ref.watch(authenticatedApiClientProvider)),
);

class ConsentsController extends AsyncNotifier<List<ConsentPreference>> {
  @override
  Future<List<ConsentPreference>> build() {
    return ref.read(consentsRepositoryProvider).list();
  }

  Future<void> setAccepted(ConsentPreference consent, bool accepted) async {
    if (consent.isRequired && !accepted) {
      throw StateError(
        'Los términos y consentimientos obligatorios no se pueden retirar.',
      );
    }
    final previous = state;
    state = const AsyncLoading<List<ConsentPreference>>().copyWithPrevious(
      previous,
    );
    state = await AsyncValue.guard(() async {
      final repository = ref.read(consentsRepositoryProvider);
      if (accepted) {
        await repository.accept(consent.code);
      } else {
        await repository.revoke(consent.code);
      }
      return repository.list();
    });
  }
}

final consentsControllerProvider =
    AsyncNotifierProvider<ConsentsController, List<ConsentPreference>>(
      ConsentsController.new,
    );
