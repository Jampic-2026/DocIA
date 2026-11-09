import 'app_user.dart';

abstract interface class AuthRepository {
  Future<AppUser> login({required String email, required String password});

  Future<AppUser?> restoreSession();

  Future<AppUser> refreshSession();

  Future<void> logout();

  Future<RegistrationRequest> requestRegistration(String email);

  Future<void> completeRegistration(RegistrationData registration);

  Future<PasswordResetRequest> requestPasswordReset(String email);

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });
}

class RegistrationRequest {
  const RegistrationRequest({required this.message, this.developmentToken});

  final String message;
  final String? developmentToken;
}

class RegistrationData {
  const RegistrationData({
    required this.token,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.acceptRequiredConsents,
    this.secondLastName,
    this.phone,
    this.documentType,
    this.documentNumber,
    this.municipality,
    this.zone,
    this.addressLine,
    this.guardianEmail,
    this.guardianRelationship,
  });

  final String token;
  final String password;
  final String firstName;
  final String lastName;
  final DateTime birthDate;
  final bool acceptRequiredConsents;
  final String? secondLastName;
  final String? phone;
  final String? documentType;
  final String? documentNumber;
  final String? municipality;
  final String? zone;
  final String? addressLine;
  final String? guardianEmail;
  final String? guardianRelationship;
}

class PasswordResetRequest {
  const PasswordResetRequest({required this.message, this.developmentToken});

  final String message;
  final String? developmentToken;
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
