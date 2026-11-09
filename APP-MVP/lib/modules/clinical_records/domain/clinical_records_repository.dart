import 'clinical_profile.dart';
import 'vital_sign_record.dart';
import 'clinical_document.dart';
import 'professional_patient_record.dart';
import 'clinical_correction_request.dart';
import 'clinical_history.dart';

abstract interface class ClinicalRecordsRepository {
  Future<Map<String, dynamic>> completion({String? patientId});
  Future<Map<String, dynamic>> completionPolicy();
  Future<void> saveCompletionPolicy(Map<String, dynamic> policy);
  Future<List<ClinicalHistoryEntry>> history({String? patientId});
  Future<ClinicalTrends> trends({String? patientId, int days = 90});
  Future<Map<String, dynamic>> exportRecord({
    String? patientId,
    String format = 'jampic',
    List<String>? categories,
  });
  Future<VitalSignRecord> createProfessionalVitalSign(
    String patientId,
    CreateVitalSignCommand command, {
    String? appointmentId,
    String? emergencyId,
  });
  Future<ClinicalProfile> getProfile({String? patientId});
  Future<ClinicalProfile> updateProfile(UpdateClinicalProfileCommand command);
  Future<List<VitalSignRecord>> listVitalSigns();
  Future<VitalSignRecord> createVitalSign(CreateVitalSignCommand command);
  Future<List<ClinicalDocument>> listDocuments();
  Future<ClinicalDocument> createDocument(
    CreateClinicalDocumentCommand command,
  );
  Future<ProfessionalPatientRecord> getProfessionalPatientRecord(
    String patientId,
  );
  Future<ProfessionalPatientRecord> validateStatement({
    required String patientId,
    required String type,
    required String statementId,
    required String status,
    String? notes,
  });
  Future<ProfessionalPatientRecord> validateDocument({
    required String patientId,
    required String documentId,
    required String status,
    String? notes,
  });
  Future<List<ClinicalCorrectionRequest>> listCorrectionRequests();
  Future<ClinicalCorrectionRequest> createCorrectionRequest({
    required String clinicalRecordId,
    required String requestedChange,
    required String reason,
  });
  Future<void> resolveCorrectionRequest({
    required String requestId,
    required String status,
    required String resolution,
  });
}
