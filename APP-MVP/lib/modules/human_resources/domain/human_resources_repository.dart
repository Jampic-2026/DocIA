import 'staff_member.dart';

abstract interface class HumanResourcesRepository {
  Future<List<DocumentRequirements>> listRequirements();
  Future<void> configureRequirements(
    String roleCode,
    List<String> documentTypes,
  );
  Future<List<VerificationSpecialty>> listSpecialties();
  Future<List<PersonnelDocument>> listProfessionalDocuments(
    String professionalId,
  );
  Future<void> reviewProfessionalDocument({
    required String documentId,
    required String status,
    String? observation,
  });
  Future<List<StaffMember>> listStaff();
  Future<List<PersonnelApplication>> listApplications();
  Future<List<PersonnelDocument>> listDocuments();
  Future<PersonnelApplication> submitApplication({
    required String requestedRoleCode,
    required String licenseNumber,
    required String requestedSpecialty,
  });
  Future<void> addApplicationDocument({
    required String applicationId,
    required String documentType,
    required String fileUrl,
  });
  Future<void> reviewApplication({
    required String applicationId,
    required String status,
    String? reason,
    String? licenseNumber,
    String? specialtyId,
  });
  Future<void> reviewDocument({
    required String documentId,
    required String status,
    String? observation,
  });
  Future<void> reviewProfessional({
    required String professionalId,
    required String status,
    String? reason,
    String? roleCode,
    String? specialtyId,
  });
}

class DocumentRequirements {
  const DocumentRequirements(this.roleCode, this.documentTypes);
  final String roleCode;
  final List<String> documentTypes;
}

class VerificationSpecialty {
  const VerificationSpecialty(this.id, this.name);
  final String id;
  final String name;
}

class PersonnelApplication {
  const PersonnelApplication({
    required this.id,
    required this.requestedRoleCode,
    required this.status,
    this.applicantName,
    this.applicantEmail,
    this.licenseNumber,
    this.requestedSpecialty,
    this.rejectionReason,
    this.createdAt,
    this.reviewedAt,
  });

  final String id;
  final String requestedRoleCode;
  final String status;
  final String? applicantName;
  final String? applicantEmail;
  final String? licenseNumber;
  final String? requestedSpecialty;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
}

class PersonnelDocument {
  const PersonnelDocument({
    required this.id,
    required this.documentType,
    required this.fileUrl,
    required this.status,
    this.applicationId,
    this.observation,
    this.createdAt,
  });

  final String id;
  final String? applicationId;
  final String documentType;
  final String fileUrl;
  final String status;
  final String? observation;
  final DateTime? createdAt;
}
