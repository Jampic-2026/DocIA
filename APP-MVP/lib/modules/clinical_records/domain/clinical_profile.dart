class ClinicalProfile {
  const ClinicalProfile({
    required this.patientId,
    required this.allergies,
    required this.chronicConditions,
    required this.currentMedications,
    this.bloodType,
    this.heightCm,
    this.weightKg,
    this.insuranceProvider,
    this.insuranceNumber,
    this.profileNotes,
    this.medicalHistory = const [],
    this.familyHistory = const [],
    this.surgicalHistory = const [],
    this.emergencyContactName,
    this.emergencyContactRelationship,
    this.emergencyContactPhone,
    this.emergencyContactEmail,
  });
  final String patientId;
  final String? bloodType;
  final double? heightCm;
  final double? weightKg;
  final String? insuranceProvider;
  final String? insuranceNumber;
  final String? profileNotes;
  final List<String> allergies;
  final List<String> chronicConditions;
  final List<String> currentMedications;
  final List<String> medicalHistory;
  final List<String> familyHistory;
  final List<String> surgicalHistory;
  final String? emergencyContactName;
  final String? emergencyContactRelationship;
  final String? emergencyContactPhone;
  final String? emergencyContactEmail;
}

class UpdateClinicalProfileCommand {
  const UpdateClinicalProfileCommand({
    this.patientId,
    required this.bloodType,
    required this.heightCm,
    required this.weightKg,
    required this.insuranceProvider,
    required this.insuranceNumber,
    required this.profileNotes,
    required this.allergies,
    required this.chronicConditions,
    required this.currentMedications,
    required this.medicalHistory,
    required this.familyHistory,
    required this.surgicalHistory,
    required this.emergencyContactName,
    required this.emergencyContactRelationship,
    required this.emergencyContactPhone,
    required this.emergencyContactEmail,
  });

  final String bloodType;
  final String? patientId;
  final double? heightCm;
  final double? weightKg;
  final String insuranceProvider;
  final String insuranceNumber;
  final String profileNotes;
  final List<String> allergies;
  final List<String> chronicConditions;
  final List<String> currentMedications;
  final List<String> medicalHistory;
  final List<String> familyHistory;
  final List<String> surgicalHistory;
  final String emergencyContactName;
  final String emergencyContactRelationship;
  final String emergencyContactPhone;
  final String emergencyContactEmail;
}
