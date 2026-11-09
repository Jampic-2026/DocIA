class CreateClinicalNoteCommand {
  const CreateClinicalNoteCommand({
    required this.appointmentId,
    required this.patientId,
    required this.subjective,
    required this.objective,
    required this.assessment,
    required this.plan,
  });

  final String appointmentId;
  final String patientId;
  final String subjective;
  final String objective;
  final String assessment;
  final String plan;

  Map<String, dynamic> toJson() => {
        'appointmentId': appointmentId,
        'patientId': patientId,
        'subjective': subjective,
        'objective': objective,
        'assessment': assessment,
        'plan': plan,
      };
}

class CloseConsultationCommand extends CreateClinicalNoteCommand {
  const CloseConsultationCommand({
    required super.appointmentId,
    required super.patientId,
    required super.subjective,
    required super.objective,
    required super.assessment,
    required super.plan,
    required this.diagnosis,
    required this.diagnosisType,
    required this.treatment,
    required this.treatmentInstructions,
    required this.followupInstructions,
    this.followupDueAt,
  });

  final String diagnosis;
  final String diagnosisType;
  final String treatment;
  final String treatmentInstructions;
  final DateTime? followupDueAt;
  final String followupInstructions;

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'diagnosis': diagnosis,
        'diagnosisType': diagnosisType,
        'treatment': treatment,
        'treatmentInstructions': treatmentInstructions,
        'followupDueAt': followupDueAt?.toUtc().toIso8601String(),
        'followupInstructions': followupInstructions,
      };
}
