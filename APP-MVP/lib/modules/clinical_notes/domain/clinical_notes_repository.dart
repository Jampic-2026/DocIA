import 'clinical_note.dart';

abstract interface class ClinicalNotesRepository {
  Future<void> create(CreateClinicalNoteCommand command);
  Future<void> closeConsultation(CloseConsultationCommand command);
}
