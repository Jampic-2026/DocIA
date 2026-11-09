import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/clinical_note.dart';
import '../domain/clinical_notes_repository.dart';
import '../infrastructure/api/api_clinical_notes_repository.dart';

final clinicalNotesRepositoryProvider = Provider<ClinicalNotesRepository>(
  (ref) => ApiClinicalNotesRepository(
    ref.watch(authenticatedApiClientProvider),
  ),
);

class ClinicalNoteSubmissionController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit(CreateClinicalNoteCommand command) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(clinicalNotesRepositoryProvider).create(command),
    );
    if (state.hasError) {
      Error.throwWithStackTrace(
      state.error!,
      state.stackTrace!,
    );
    }
  }

  Future<void> close(CloseConsultationCommand command) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(clinicalNotesRepositoryProvider).closeConsultation(command),
    );
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
  }
}

final clinicalNoteSubmissionProvider =
    AutoDisposeAsyncNotifierProvider<ClinicalNoteSubmissionController, void>(
  ClinicalNoteSubmissionController.new,
);
