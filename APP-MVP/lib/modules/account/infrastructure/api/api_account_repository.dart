import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/account_profile.dart';
import '../../domain/account_repository.dart';

class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository(this._client);
  final AuthenticatedApiClient _client;

  @override
  Future<AccountProfile> getProfile() async {
    final response = await _client.get<Map<String, dynamic>>('people/me');
    return _map(response.data);
  }

  @override
  Future<AccountProfile> updateProfile({
    required String firstName,
    required String lastName,
    String? secondLastName,
    String? phone,
    String? municipality,
    String? zone,
    String? addressLine,
    String? reference,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      'people/me',
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'secondLastName': secondLastName ?? '',
        'phone': phone ?? '',
        'municipality': municipality ?? '',
        'zone': zone ?? '',
        'addressLine': addressLine ?? '',
        'reference': reference ?? '',
      },
    );
    return _map(response.data);
  }

  AccountProfile _map(Map<String, dynamic>? json) {
    if (json == null) {
      throw const FormatException('El perfil de cuenta no tiene un formato válido.');
    }
    final address = json['address'];
    return AccountProfile(
      personId: json['personId'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      secondLastName: json['secondLastName'] as String?,
      documentType: json['documentType'] as String?,
      documentNumber: json['documentNumber'] as String?,
      birthDate: json['birthDate'] == null
          ? null
          : DateTime.parse(json['birthDate'] as String),
      nationality: json['nationality'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String,
      photoUrl: json['photoUrl'] as String?,
      address: address is Map<String, dynamic>
          ? AccountAddress(
              municipality: address['municipality'] as String?,
              zone: address['zone'] as String?,
              addressLine: address['addressLine'] as String?,
              reference: address['reference'] as String?,
            )
          : null,
    );
  }
}
