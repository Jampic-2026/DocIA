class ProfessionalProfile {
  const ProfessionalProfile({
    required this.id,
    required this.professionalType,
    required this.verificationStatus,
    required this.publicProfileEnabled,
    required this.specialties,
    required this.documents,
    this.licenseNumber,
    this.bio,
    this.academicBackground,
    this.publicCertifications = const [],
    this.yearsExperience,
    this.pendingSpecialtyId,
  });
  final String? pendingSpecialtyId;
  final String id;
  final String professionalType;
  final String? licenseNumber;
  final String? bio;
  final String? academicBackground;
  final List<String> publicCertifications;
  final int? yearsExperience;
  final String verificationStatus;
  final bool publicProfileEnabled;
  final List<ProfessionalSpecialty> specialties;
  final List<ProfessionalDocument> documents;
}

class ProfessionalSpecialty {
  const ProfessionalSpecialty({
    required this.id,
    required this.name,
    required this.isPrimary,
  });
  final String id;
  final String name;
  final bool isPrimary;
}

class ProfessionalDocument {
  const ProfessionalDocument({
    required this.id,
    required this.documentType,
    required this.fileUrl,
    required this.status,
    required this.createdAt,
    this.observation,
  });
  final String id;
  final String documentType;
  final String fileUrl;
  final String status;
  final DateTime createdAt;
  final String? observation;
}
