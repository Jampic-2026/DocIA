import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/human_resources_repository.dart';
import '../../domain/staff_member.dart';

class ApiHumanResourcesRepository implements HumanResourcesRepository {
  ApiHumanResourcesRepository(this._client);
  final AuthenticatedApiClient _client;
  @override
  Future<List<DocumentRequirements>> listRequirements() async {
    final response = await _client.get<Map<String, dynamic>>(
      'human-resources/document-requirements',
    );
    return (response.data!['items'] as List)
        .map(
          (item) => DocumentRequirements(
            item['role_code'] as String,
            (item['document_types'] as List).cast<String>(),
          ),
        )
        .toList();
  }

  @override
  Future<void> configureRequirements(
    String roleCode,
    List<String> documentTypes,
  ) async {
    await _client.put<Map<String, dynamic>>(
      'human-resources/document-requirements/$roleCode',
      data: {'documentTypes': documentTypes},
    );
  }

  @override
  Future<List<VerificationSpecialty>> listSpecialties() async {
    final response = await _client.get<Map<String, dynamic>>(
      'professionals/specialties',
    );
    return (response.data!['items'] as List)
        .where((item) => item['is_active'] == true)
        .map(
          (item) => VerificationSpecialty(
            item['id'] as String,
            item['name'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<List<PersonnelDocument>> listProfessionalDocuments(
    String professionalId,
  ) async {
    final response = await _client.get<Map<String, dynamic>>(
      'human-resources/professionals/$professionalId/documents',
    );
    return (response.data!['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(_document)
        .toList();
  }

  @override
  Future<void> reviewProfessionalDocument({
    required String documentId,
    required String status,
    String? observation,
  }) async {
    await _client.patch<Map<String, dynamic>>(
      'human-resources/professional-documents/$documentId/review',
      data: {'status': status, 'observation': observation},
    );
  }

  PersonnelApplication _application(
    Map<String, dynamic> json,
  ) => PersonnelApplication(
    id: json['id'] as String,
    requestedRoleCode:
        (json['requestedRoleCode'] ?? json['requested_role_code']) as String,
    status: json['status'] as String,
    applicantName: (json['applicantName'] ?? json['applicant_name']) as String?,
    applicantEmail:
        (json['applicantEmail'] ?? json['applicant_email']) as String?,
    licenseNumber: (json['licenseNumber'] ?? json['license_number']) as String?,
    requestedSpecialty:
        (json['requestedSpecialty'] ?? json['requested_specialty']) as String?,
    rejectionReason:
        (json['rejectionReason'] ?? json['rejection_reason']) as String?,
    createdAt: _date(json['createdAt'] ?? json['created_at']),
    reviewedAt: _date(json['reviewedAt'] ?? json['reviewed_at']),
  );
  PersonnelDocument _document(Map<String, dynamic> json) => PersonnelDocument(
    id: json['id'] as String,
    applicationId: (json['applicationId'] ?? json['application_id']) as String?,
    documentType: (json['documentType'] ?? json['document_type']) as String,
    fileUrl: (json['fileUrl'] ?? json['file_url']) as String,
    status: json['status'] as String,
    observation: json['observation'] as String?,
    createdAt: _date(json['createdAt'] ?? json['created_at']),
  );
  DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
  @override
  Future<List<StaffMember>> listStaff() async {
    final response = await _client.get<Map<String, dynamic>>(
      'human-resources/employment-records',
    );
    final items = response.data?['items'];
    if (items is! List) {
      throw const FormatException('El personal no tiene un formato válido.');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(
          (j) => StaffMember(
            academicBackground: j['academicBackground'] as String?,
            certifications: (j['certifications'] as List? ?? const [])
                .cast<String>(),
            professionalId: j['professionalId'] as String,
            fullName: j['fullName'] as String,
            professionalType: j['professionalType'] as String,
            verificationStatus: j['verificationStatus'] as String,
            specialty: j['specialty'] as String?,
            employeeCode: j['employeeCode'] as String?,
            contractType: j['contractType'] as String?,
            employmentStatus: j['employmentStatus'] as String?,
            hiredAt: j['hiredAt'] == null
                ? null
                : DateTime.parse(j['hiredAt'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<List<PersonnelApplication>> listApplications() async {
    final response = await _client.get<Map<String, dynamic>>(
      'human-resources/personnel-applications',
    );
    final items = response.data?['items'];
    if (items is! List) {
      throw const FormatException(
        'Las postulaciones no tienen un formato válido.',
      );
    }
    return items.whereType<Map<String, dynamic>>().map(_application).toList();
  }

  @override
  Future<List<PersonnelDocument>> listDocuments() async {
    final response = await _client.get<Map<String, dynamic>>(
      'human-resources/personnel-documents',
    );
    final items = response.data?['items'];
    if (items is! List) {
      throw const FormatException(
        'Los documentos no tienen un formato válido.',
      );
    }
    return items.whereType<Map<String, dynamic>>().map(_document).toList();
  }

  @override
  Future<PersonnelApplication> submitApplication({
    required String requestedRoleCode,
    required String licenseNumber,
    required String requestedSpecialty,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      'human-resources/personnel-applications',
      data: {
        'requestedRoleCode': requestedRoleCode,
        'licenseNumber': licenseNumber,
        'requestedSpecialty': requestedSpecialty,
      },
    );
    return _application(response.data!);
  }

  @override
  Future<void> addApplicationDocument({
    required String applicationId,
    required String documentType,
    required String fileUrl,
  }) async {
    await _client.post<Map<String, dynamic>>(
      'human-resources/personnel-applications/$applicationId/documents',
      data: {'documentType': documentType, 'fileUrl': fileUrl},
    );
  }

  @override
  Future<void> reviewApplication({
    required String applicationId,
    required String status,
    String? reason,
    String? licenseNumber,
    String? specialtyId,
  }) async {
    await _client.patch<Map<String, dynamic>>(
      'human-resources/personnel-applications/$applicationId/review',
      data: {
        'status': status,
        'reason': reason,
        'licenseNumber': licenseNumber,
        'specialtyId': specialtyId,
      },
    );
  }

  @override
  Future<void> reviewDocument({
    required String documentId,
    required String status,
    String? observation,
  }) async {
    await _client.patch<Map<String, dynamic>>(
      'human-resources/personnel-documents/$documentId/review',
      data: {'status': status, 'observation': observation},
    );
  }

  @override
  Future<void> reviewProfessional({
    required String professionalId,
    required String status,
    String? reason,
    String? roleCode,
    String? specialtyId,
  }) async {
    await _client.patch<Map<String, dynamic>>(
      'human-resources/professionals/$professionalId/verification',
      data: {
        'status': status,
        'reason': reason,
        'roleCode': roleCode,
        'specialtyId': specialtyId,
      },
    );
  }
}
