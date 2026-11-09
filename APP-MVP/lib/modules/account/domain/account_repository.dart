import 'account_profile.dart';

abstract interface class AccountRepository {
  Future<AccountProfile> getProfile();
  Future<AccountProfile> updateProfile({
    required String firstName,
    required String lastName,
    String? secondLastName,
    String? phone,
    String? municipality,
    String? zone,
    String? addressLine,
    String? reference,
  });
}
