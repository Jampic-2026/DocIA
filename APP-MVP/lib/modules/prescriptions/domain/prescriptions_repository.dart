import 'prescription.dart';

abstract interface class PrescriptionsRepository {
  Future<List<Prescription>> list();
  Future<void> createDraft(CreatePrescriptionCommand command);
  Future<Map<String, dynamic>> safetyReview(String id);
  Future<void> issue(
    String id,
    DateTime expiresAt, {
    String? allergyFingerprint,
    String? allergyReviewReason,
  });
}

class CreatePrescriptionCommand {
  const CreatePrescriptionCommand({
    required this.patientId,
    required this.appointmentId,
    required this.medicationName,
    required this.dose,
    required this.frequency,
    required this.duration,
    required this.instructions,
  });
  final String patientId;
  final String appointmentId;
  final String medicationName;
  final String dose;
  final String frequency;
  final String duration;
  final String instructions;
}
