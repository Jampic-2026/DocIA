import 'user_role.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.sessionId,
    required this.email,
    required this.primaryRoleCode,
    required this.roles,
    required this.permissions,
    this.phone,
    this.fullName,
    this.specialty,
    this.documentId,
  });

  final String id;
  final String sessionId;
  final String email;
  final String? phone;
  final String primaryRoleCode;
  final Set<String> roles;
  final Set<String> permissions;

  // Datos opcionales hasta integrar el perfil de cuenta.
  final String? fullName;
  final String? specialty;
  final String? documentId;

  UserExperience get experience =>
      UserExperience.fromRoles(roles, primaryRoleCode: primaryRoleCode);

  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return email.split('@').first;
  }

  String get firstName => displayName.split(' ').first;

  bool hasRole(String role) => roles.contains(role);

  bool can(String permission) => permissions.contains(permission);
}
