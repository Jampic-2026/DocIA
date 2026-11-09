import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/professional_patient.dart';
import '../../domain/professional_patients_repository.dart';

class ApiProfessionalPatientsRepository
    implements ProfessionalPatientsRepository {
  ApiProfessionalPatientsRepository(this._client);

  final AuthenticatedApiClient _client;

  @override
  Future<List<ProfessionalPatient>> list() async {
    final response =
        await _client.get<Map<String, dynamic>>('patients/patients');
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .map((item) => ProfessionalPatient.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }
}
