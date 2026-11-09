import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/professional_profile.dart';
import '../../domain/professional_profile_repository.dart';

class ApiProfessionalProfileRepository
    implements ProfessionalProfileRepository {
  ApiProfessionalProfileRepository(this._client);
  final AuthenticatedApiClient _client;
  @override
  Future<ProfessionalProfile> getProfile() async {
    final response = await _client.get<Map<String, dynamic>>(
      'professionals/me',
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException(
        'El perfil profesional no tiene un formato válido.',
      );
    }
    final specialties = data['specialties'];
    final documents = data['documents'];
    return ProfessionalProfile(
      id: data['id'] as String,
      professionalType: data['professionalType'] as String,
      licenseNumber: data['licenseNumber'] as String?,
      bio: data['bio'] as String?,
      academicBackground: data['academicBackground'] as String?,
      publicCertifications: (data['publicCertifications'] as List? ?? [])
          .cast<String>(),
      yearsExperience: data['yearsExperience'] as int?,
      verificationStatus: data['verificationStatus'] as String,
      publicProfileEnabled: data['publicProfileEnabled'] as bool,
      pendingSpecialtyId: data['pendingSpecialtyId'] as String?,
      specialties: specialties is List
          ? specialties
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) => ProfessionalSpecialty(
                    id: item['id'] as String,
                    name: item['name'] as String,
                    isPrimary: item['isPrimary'] as bool,
                  ),
                )
                .toList()
          : const [],
      documents: documents is List
          ? documents
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) => ProfessionalDocument(
                    id: item['id'] as String,
                    documentType: item['documentType'] as String,
                    fileUrl: item['fileUrl'] as String,
                    status: item['status'] as String,
                    observation: item['observation'] as String?,
                    createdAt: DateTime.parse(
                      item['createdAt'] as String,
                    ).toLocal(),
                  ),
                )
                .toList()
          : const [],
    );
  }

  @override
  Future<void> update({
    required String licenseNumber,
    required String bio,
    required int yearsExperience,
    required bool publicProfileEnabled,
    String? specialtyId,
    String? academicBackground,
    List<String>? publicCertifications,
  }) async {
    await _client.patch<Map<String, dynamic>>(
      'professionals/me',
      data: {
        'licenseNumber': licenseNumber,
        'bio': bio,
        if (academicBackground != null)
          'academicBackground': academicBackground,
        if (publicCertifications != null)
          'publicCertifications': publicCertifications,
        'yearsExperience': yearsExperience,
        'publicProfileEnabled': publicProfileEnabled,
        'specialtyId': specialtyId,
      },
    );
  }

  @override
  Future<void> addDocument({
    required String documentType,
    required String fileUrl,
  }) async {
    await _client.post<Map<String, dynamic>>(
      'professionals/me/documents',
      data: {'documentType': documentType, 'fileUrl': fileUrl},
    );
  }
}
