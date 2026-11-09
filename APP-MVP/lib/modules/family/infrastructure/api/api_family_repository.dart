import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/family_member.dart';
import '../../domain/family_repository.dart';

class ApiFamilyRepository implements FamilyRepository {
  ApiFamilyRepository(this._client);
  final AuthenticatedApiClient _client;

  @override
  Future<String> createDependent({
    required String firstName,
    required String lastName,
    String? secondLastName,
    required String birthDate,
    String? documentType,
    String? documentNumber,
    required String relationship,
    required bool confirmResponsibility,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      'patients/dependents',
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'secondLastName': secondLastName,
        'birthDate': birthDate,
        'documentType': documentType,
        'documentNumber': documentNumber,
        'relationship': relationship,
        'confirmResponsibility': confirmResponsibility,
      },
    );
    return response.data!['patientId'] as String;
  }

  @override
  Future<List<FamilyMember>> list() async {
    final response = await _client.get<Map<String, dynamic>>('patients/family');
    final items = response.data?['items'];
    if (items is! List) {
      throw const FormatException(
        'La lista familiar no tiene un formato válido.',
      );
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map((json) {
          return FamilyMember(
            id: json['id'] as String,
            patientId: json['patientId'] as String?,
            linkKind: json['linkKind'] as String? ?? 'outgoing',
            fullName: json['fullName'] as String,
            relationship: json['relationship'] as String,
            age: json['age'] as int?,
            isDependent: json['isDependent'] as bool,
            status: json['status'] as String,
            canViewHistory: json['canViewHistory'] as bool,
            canBookAppointments: json['canBookAppointments'] as bool,
            canHandleEmergencies: json['canHandleEmergencies'] as bool,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> authorize(CreateFamilyAuthorizationCommand command) async {
    await _client.post<Map<String, dynamic>>(
      'patients/family-authorizations',
      data: {
        'email': command.email,
        'relationship': command.relationship,
        'canViewHistory': command.canViewHistory,
        'canBookAppointments': command.canBookAppointments,
        'canHandleEmergencies': command.canHandleEmergencies,
      },
    );
  }

  @override
  Future<void> updateAuthorization(
    String id,
    CreateFamilyAuthorizationCommand command,
  ) async {
    await _client.patch<Map<String, dynamic>>(
      'patients/family-authorizations/$id',
      data: {
        'relationship': command.relationship,
        'canViewHistory': command.canViewHistory,
        'canBookAppointments': command.canBookAppointments,
        'canHandleEmergencies': command.canHandleEmergencies,
      },
    );
  }

  @override
  Future<void> revokeAuthorization(String id) async {
    await _client.delete<Map<String, dynamic>>(
      'patients/family-authorizations/$id',
    );
  }

  @override
  Future<GuardianLinkCode> createGuardianLinkCode() async {
    final response = await _client.post<Map<String, dynamic>>(
      'patients/guardian-link-codes',
      data: const <String, dynamic>{},
    );
    final data = response.data;
    if (data == null ||
        data['code'] is! String ||
        data['expiresAt'] is! String) {
      throw const FormatException(
        'No se pudo generar el código de vinculación.',
      );
    }
    return GuardianLinkCode(
      code: data['code'] as String,
      expiresAt: DateTime.parse(data['expiresAt'] as String),
    );
  }

  @override
  Future<void> redeemGuardianLinkCode({
    required String code,
    required String relationship,
  }) async {
    await _client.post<Map<String, dynamic>>(
      'patients/patient-guardians/redeem',
      data: {'code': code, 'relationship': relationship},
    );
  }
}
