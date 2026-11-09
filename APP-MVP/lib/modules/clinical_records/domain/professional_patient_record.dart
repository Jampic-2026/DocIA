import 'clinical_document.dart';
import 'vital_sign_record.dart';

class ClinicalStatement {
  const ClinicalStatement({
    required this.id,
    required this.type,
    required this.category,
    required this.description,
    required this.validationStatus,
    this.detail,
  });

  final String id;
  final String type;
  final String category;
  final String description;
  final String? detail;
  final String validationStatus;
}

class ProfessionalPatientRecord {
  const ProfessionalPatientRecord({
    required this.patientId,
    required this.fullName,
    required this.statements,
    required this.vitalSigns,
    required this.documents,
    this.birthDate,
    this.bloodType,
    this.heightCm,
    this.weightKg,
    this.insuranceProvider,
    this.insuranceNumber,
    this.profileNotes,
    this.emergencyContact,
  });

  final String patientId;
  final String fullName;
  final DateTime? birthDate;
  final String? bloodType;
  final double? heightCm;
  final double? weightKg;
  final String? insuranceProvider;
  final String? insuranceNumber;
  final String? profileNotes;
  final String? emergencyContact;
  final List<ClinicalStatement> statements;
  final List<VitalSignRecord> vitalSigns;
  final List<ClinicalDocument> documents;
}
