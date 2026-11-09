import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/clinical_profile.dart';
import '../../domain/clinical_records_repository.dart';
import '../../domain/vital_sign_record.dart';
import '../../domain/clinical_document.dart';
import '../../domain/professional_patient_record.dart';
import '../../domain/clinical_correction_request.dart';
import '../../domain/clinical_history.dart';

class ApiClinicalRecordsRepository implements ClinicalRecordsRepository {
  ApiClinicalRecordsRepository(this._client);
  final AuthenticatedApiClient _client;

  @override
  Future<Map<String, dynamic>> completion({String? patientId}) async =>
      (await _client.post<Map<String, dynamic>>(
        _patientPath(patientId, 'completion'),
        data: const <String, dynamic>{},
      )).data!;
  @override
  Future<Map<String, dynamic>> completionPolicy() async =>
      (await _client.get<Map<String, dynamic>>(
        'clinical-records/completion-policy',
      )).data!;
  @override
  Future<void> saveCompletionPolicy(Map<String, dynamic> policy) async {
    await _client.put<Map<String, dynamic>>(
      'clinical-records/completion-policy',
      data: policy,
    );
  }

  String _patientPath(String? patientId, String resource) => patientId == null
      ? 'clinical-records/$resource'
      : 'clinical-records/patients/$patientId/$resource';

  @override
  Future<List<ClinicalHistoryEntry>> history({String? patientId}) async {
    final response = await _client.get<Map<String, dynamic>>(
      _patientPath(patientId, 'history'),
    );
    return (response.data!['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => ClinicalHistoryEntry(
            id: row['id'] as String,
            type: row['type'] as String,
            title: row['title'] as String,
            summary: row['summary'] as String,
            recordedAt: DateTime.parse(row['recordedAt'] as String).toLocal(),
            validationStatus: row['validationStatus'] as String,
            authorName: row['authorName'] as String?,
            specialty: row['specialty'] as String?,
          ),
        )
        .toList();
  }

  @override
  Future<ClinicalTrends> trends({String? patientId, int days = 90}) async {
    final response = await _client.get<Map<String, dynamic>>(
      _patientPath(patientId, 'trends'),
      queryParameters: {'days': days},
    );
    return ClinicalTrends(
      points: (response.data!['points'] as List).cast<Map<String, dynamic>>(),
      summary: response.data!['summary'] as Map<String, dynamic>,
    );
  }

  @override
  Future<Map<String, dynamic>> exportRecord({
    String? patientId,
    String format = 'jampic',
    List<String>? categories,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      _patientPath(patientId, 'export'),
      queryParameters: {
        'format': format,
        if (categories != null) 'categories': categories.join(','),
      },
    );
    return response.data!;
  }

  @override
  Future<VitalSignRecord> createProfessionalVitalSign(
    String patientId,
    CreateVitalSignCommand command, {
    String? appointmentId,
    String? emergencyId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      'clinical-records/patients/$patientId/vital-signs',
      data: {
        'appointmentId': appointmentId,
        'emergencyId': emergencyId,
        'systolicPressure': command.systolicPressure,
        'diastolicPressure': command.diastolicPressure,
        'heartRate': command.heartRate,
        'temperatureC': command.temperatureC,
        'oxygenSaturation': command.oxygenSaturation,
        'respiratoryRate': command.respiratoryRate,
        'glucoseMgDl': command.glucoseMgDl,
        'weightKg': command.weightKg,
        'heightCm': command.heightCm,
        'notes': command.notes,
      },
    );
    return _vitalFromJson(response.data!);
  }

  @override
  Future<ClinicalProfile> getProfile({String? patientId}) async {
    final response = await _client.get<Map<String, dynamic>>(
      patientId == null
          ? 'clinical-records/profile'
          : 'clinical-records/patients/$patientId/profile',
    );
    final json = response.data;
    if (json == null) {
      throw const FormatException(
        'El perfil clínico no tiene un formato válido.',
      );
    }
    return _profileFromJson(json);
  }

  ClinicalProfile _profileFromJson(Map<String, dynamic> json) {
    return ClinicalProfile(
      patientId: json['patientId'] as String,
      bloodType: json['bloodType'] as String?,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      insuranceProvider: json['insuranceProvider'] as String?,
      insuranceNumber: json['insuranceNumber'] as String?,
      profileNotes: json['profileNotes'] as String?,
      allergies: _strings(json['allergies']),
      chronicConditions: _strings(json['chronicConditions']),
      currentMedications: _strings(json['currentMedications']),
      medicalHistory: _strings(json['medicalHistory']),
      familyHistory: _strings(json['familyHistory']),
      surgicalHistory: _strings(json['surgicalHistory']),
      emergencyContactName: json['emergencyContactName'] as String?,
      emergencyContactRelationship:
          json['emergencyContactRelationship'] as String?,
      emergencyContactPhone: json['emergencyContactPhone'] as String?,
      emergencyContactEmail: json['emergencyContactEmail'] as String?,
    );
  }

  @override
  Future<ClinicalProfile> updateProfile(
    UpdateClinicalProfileCommand command,
  ) async {
    final response = await _client.patch<Map<String, dynamic>>(
      command.patientId == null
          ? 'clinical-records/profile'
          : 'clinical-records/patients/${command.patientId}/profile',
      data: {
        'bloodType': command.bloodType,
        'heightCm': command.heightCm,
        'weightKg': command.weightKg,
        'insuranceProvider': command.insuranceProvider,
        'insuranceNumber': command.insuranceNumber,
        'profileNotes': command.profileNotes,
        'allergies': command.allergies,
        'chronicConditions': command.chronicConditions,
        'currentMedications': command.currentMedications,
        'medicalHistory': command.medicalHistory,
        'familyHistory': command.familyHistory,
        'surgicalHistory': command.surgicalHistory,
        'emergencyContactName': command.emergencyContactName,
        'emergencyContactRelationship': command.emergencyContactRelationship,
        'emergencyContactPhone': command.emergencyContactPhone,
        'emergencyContactEmail': command.emergencyContactEmail,
      },
    );
    final json = response.data;
    if (json == null) {
      throw const FormatException(
        'La ficha clínica no tiene un formato válido.',
      );
    }
    return _profileFromJson(json);
  }

  @override
  Future<List<VitalSignRecord>> listVitalSigns() async {
    final response = await _client.get<Map<String, dynamic>>(
      'clinical-records/vital-signs',
    );
    final items = response.data?['items'];
    if (items is! List) {
      throw const FormatException(
        'Los signos vitales no tienen un formato válido.',
      );
    }
    return items.whereType<Map<String, dynamic>>().map(_vitalFromJson).toList();
  }

  @override
  Future<VitalSignRecord> createVitalSign(
    CreateVitalSignCommand command,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      'clinical-records/vital-signs',
      data: {
        'systolicPressure': command.systolicPressure,
        'diastolicPressure': command.diastolicPressure,
        'heartRate': command.heartRate,
        'temperatureC': command.temperatureC,
        'oxygenSaturation': command.oxygenSaturation,
        'respiratoryRate': command.respiratoryRate,
        'glucoseMgDl': command.glucoseMgDl,
        'weightKg': command.weightKg,
        'heightCm': command.heightCm,
        'notes': command.notes,
      }..removeWhere((_, value) => value == null),
    );
    final json = response.data;
    if (json == null) {
      throw const FormatException('El signo vital no tiene un formato válido.');
    }
    return _vitalFromJson(json);
  }

  @override
  Future<List<ClinicalDocument>> listDocuments() async {
    final response = await _client.get<Map<String, dynamic>>(
      'clinical-records/clinical-documents',
    );
    final items = response.data?['items'];
    if (items is! List) {
      throw const FormatException(
        'Los documentos no tienen un formato válido.',
      );
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(_documentFromJson)
        .toList();
  }

  @override
  Future<ClinicalDocument> createDocument(
    CreateClinicalDocumentCommand command,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      'clinical-records/clinical-documents',
      data: {
        'documentType': command.documentType,
        'fileUrl': command.fileUrl,
        'fileName': command.fileName,
        'mimeType': command.mimeType,
        'isRestricted': command.isRestricted,
      },
    );
    final json = response.data;
    if (json == null) {
      throw const FormatException('El documento no tiene un formato válido.');
    }
    return _documentFromJson(json);
  }

  VitalSignRecord _vitalFromJson(Map<String, dynamic> json) => VitalSignRecord(
    id: json['id'] as String,
    source: json['source'] as String,
    systolicPressure: json['systolicPressure'] as int?,
    diastolicPressure: json['diastolicPressure'] as int?,
    heartRate: json['heartRate'] as int?,
    temperatureC: (json['temperatureC'] as num?)?.toDouble(),
    oxygenSaturation: (json['oxygenSaturation'] as num?)?.toDouble(),
    respiratoryRate: json['respiratoryRate'] as int?,
    glucoseMgDl: (json['glucoseMgDl'] as num?)?.toDouble(),
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    heightCm: (json['heightCm'] as num?)?.toDouble(),
    notes: json['notes'] as String?,
    recordedAt: DateTime.parse(json['recordedAt'] as String).toLocal(),
  );

  ClinicalDocument _documentFromJson(Map<String, dynamic> json) =>
      ClinicalDocument(
        id: json['id'] as String,
        documentType: json['documentType'] as String,
        fileUrl: json['fileUrl'] as String,
        fileName: json['fileName'] as String?,
        mimeType: json['mimeType'] as String?,
        isRestricted: json['isRestricted'] as bool? ?? false,
        source: json['source'] as String,
        validationStatus: json['validationStatus'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );

  @override
  Future<ProfessionalPatientRecord> getProfessionalPatientRecord(
    String patientId,
  ) async {
    final response = await _client.get<Map<String, dynamic>>(
      'clinical-records/patients/$patientId/record',
    );
    final json = response.data;
    if (json == null) {
      throw const FormatException('El expediente no tiene un formato válido.');
    }
    return _professionalRecordFromJson(json);
  }

  @override
  Future<ProfessionalPatientRecord> validateStatement({
    required String patientId,
    required String type,
    required String statementId,
    required String status,
    String? notes,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      'clinical-records/patients/$patientId/statements/$type/$statementId/validation',
      data: {'status': status, 'notes': notes},
    );
    final json = response.data;
    if (json == null) {
      throw const FormatException('El expediente no tiene un formato válido.');
    }
    return _professionalRecordFromJson(json);
  }

  @override
  Future<ProfessionalPatientRecord> validateDocument({
    required String patientId,
    required String documentId,
    required String status,
    String? notes,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      'clinical-records/patients/$patientId/documents/$documentId/validation',
      data: {'status': status, 'notes': notes},
    );
    final json = response.data;
    if (json == null) {
      throw const FormatException('El expediente no tiene un formato válido.');
    }
    return _professionalRecordFromJson(json);
  }

  ProfessionalPatientRecord _professionalRecordFromJson(
    Map<String, dynamic> json,
  ) {
    final statements = json['statements'];
    final vitals = json['vitalSigns'];
    final documents = json['documents'];
    return ProfessionalPatientRecord(
      patientId: json['patientId'] as String,
      fullName: json['fullName'] as String,
      birthDate: json['birthDate'] == null
          ? null
          : DateTime.parse(json['birthDate'] as String),
      bloodType: json['bloodType'] as String?,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      insuranceProvider: json['insuranceProvider'] as String?,
      insuranceNumber: json['insuranceNumber'] as String?,
      profileNotes: json['profileNotes'] as String?,
      emergencyContact: json['emergencyContact'] as String?,
      statements: statements is List
          ? statements
                .whereType<Map<String, dynamic>>()
                .map((item) {
                  return ClinicalStatement(
                    id: item['id'] as String,
                    type: item['type'] as String,
                    category: item['category'] as String,
                    description: item['description'] as String,
                    detail: item['detail'] as String?,
                    validationStatus: item['validationStatus'] as String,
                  );
                })
                .toList(growable: false)
          : const [],
      vitalSigns: vitals is List
          ? vitals
                .whereType<Map<String, dynamic>>()
                .map(_vitalFromJson)
                .toList(growable: false)
          : const [],
      documents: documents is List
          ? documents
                .whereType<Map<String, dynamic>>()
                .map(_documentFromJson)
                .toList(growable: false)
          : const [],
    );
  }

  @override
  Future<List<ClinicalCorrectionRequest>> listCorrectionRequests() async {
    final response = await _client.get<Map<String, dynamic>>(
      'clinical-records/clinical-correction-requests',
    );
    final items = response.data?['items'];
    if (items is! List) {
      throw const FormatException(
        'Las solicitudes no tienen un formato válido.',
      );
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(_correctionFromJson)
        .toList(growable: false);
  }

  @override
  Future<ClinicalCorrectionRequest> createCorrectionRequest({
    required String clinicalRecordId,
    required String requestedChange,
    required String reason,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      'clinical-records/clinical-correction-requests',
      data: {
        'clinicalRecordId': clinicalRecordId,
        'requestedChange': requestedChange,
        'reason': reason,
      },
    );
    final json = response.data;
    if (json == null) {
      throw const FormatException('La solicitud no tiene un formato válido.');
    }
    return _correctionFromJson(json);
  }

  @override
  Future<void> resolveCorrectionRequest({
    required String requestId,
    required String status,
    required String resolution,
  }) async {
    await _client.patch<Map<String, dynamic>>(
      'clinical-records/clinical-correction-requests/$requestId/resolve',
      data: {'status': status, 'resolution': resolution},
    );
  }

  ClinicalCorrectionRequest _correctionFromJson(Map<String, dynamic> json) {
    return ClinicalCorrectionRequest(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      patientName: json['patientName'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      recordTitle: json['recordTitle'] as String?,
      requestedChange: json['requestedChange'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String,
      resolution: json['resolution'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      resolvedAt: json['resolvedAt'] == null
          ? null
          : DateTime.parse(json['resolvedAt'] as String).toLocal(),
    );
  }
}

List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];
