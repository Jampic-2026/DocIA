import '../../domain/app_user.dart';
import '../../domain/auth_session.dart';

class AuthUserDto {
  const AuthUserDto({
    required this.id,
    required this.sessionId,
    required this.email,
    required this.primaryRoleCode,
    required this.roles,
    required this.permissions,
    this.phone,
  });

  factory AuthUserDto.fromJson(Map<String, dynamic> json) {
    return AuthUserDto(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      primaryRoleCode: json['roleCode'] as String,
      roles: _stringSet(json['roles']),
      permissions: _stringSet(json['permissions']),
    );
  }

  final String id;
  final String sessionId;
  final String email;
  final String? phone;
  final String primaryRoleCode;
  final Set<String> roles;
  final Set<String> permissions;

  AppUser toDomain() {
    return AppUser(
      id: id,
      sessionId: sessionId,
      email: email,
      phone: phone,
      primaryRoleCode: primaryRoleCode,
      roles: {...roles, primaryRoleCode},
      permissions: permissions,
    );
  }
}

class AuthSessionDto {
  const AuthSessionDto({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.user,
  });

  factory AuthSessionDto.fromJson(Map<String, dynamic> json) {
    return AuthSessionDto(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      user: AuthUserDto.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final AuthUserDto user;

  AuthSession toDomain() {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      user: user.toDomain(),
    );
  }
}

Set<String> _stringSet(Object? value) {
  if (value is! List) {
    return {};
  }
  return value.whereType<String>().toSet();
}
