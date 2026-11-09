import 'professional_profile.dart';

abstract interface class ProfessionalProfileRepository {
  Future<ProfessionalProfile> getProfile();
  Future<void> update({
    required String licenseNumber,
    required String bio,
    required int yearsExperience,
    required bool publicProfileEnabled,
    String? specialtyId,
    String? academicBackground,
    List<String>? publicCertifications,
  });
  Future<void> addDocument({
    required String documentType,
    required String fileUrl,
  });
}
