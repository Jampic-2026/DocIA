import 'family_member.dart';

abstract interface class FamilyRepository {
  Future<String> createDependent({
    required String firstName,
    required String lastName,
    String? secondLastName,
    required String birthDate,
    String? documentType,
    String? documentNumber,
    required String relationship,
    required bool confirmResponsibility,
  });
  Future<List<FamilyMember>> list();
  Future<void> authorize(CreateFamilyAuthorizationCommand command);
  Future<void> updateAuthorization(
    String id,
    CreateFamilyAuthorizationCommand command,
  );
  Future<void> revokeAuthorization(String id);
  Future<GuardianLinkCode> createGuardianLinkCode();
  Future<void> redeemGuardianLinkCode({
    required String code,
    required String relationship,
  });
}

class GuardianLinkCode {
  const GuardianLinkCode({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;
}

class CreateFamilyAuthorizationCommand {
  const CreateFamilyAuthorizationCommand({
    required this.email,
    required this.relationship,
    required this.canViewHistory,
    required this.canBookAppointments,
    required this.canHandleEmergencies,
  });
  final String email;
  final String relationship;
  final bool canViewHistory;
  final bool canBookAppointments;
  final bool canHandleEmergencies;
}
