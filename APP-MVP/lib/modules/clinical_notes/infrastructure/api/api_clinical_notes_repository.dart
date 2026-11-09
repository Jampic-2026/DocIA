import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/clinical_note.dart';
import '../../domain/clinical_notes_repository.dart';

class ApiClinicalNotesRepository implements ClinicalNotesRepository {
  ApiClinicalNotesRepository(this._client);

  final AuthenticatedApiClient _client;

  @override
  Future<void> create(CreateClinicalNoteCommand command) async {
    await _client.post<Map<String, dynamic>>(
      'clinical-records/clinical-notes',
      data: command.toJson(),
    );
  }

  @override
  Future<void> closeConsultation(CloseConsultationCommand command) async {
    await _client.post<Map<String, dynamic>>(
      'clinical-records/consultations/close',
      data: command.toJson(),
    );
  }
}
