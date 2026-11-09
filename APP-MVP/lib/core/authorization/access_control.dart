class AccessControl {
  const AccessControl({
    required this.roles,
    required this.permissions,
  });

  const AccessControl.anonymous()
      : roles = const {},
        permissions = const {};

  final Set<String> roles;
  final Set<String> permissions;

  bool hasRole(String role) => roles.contains(role);

  bool hasAnyRole(Iterable<String> requiredRoles) {
    return requiredRoles.any(roles.contains);
  }

  bool can(String permission) => permissions.contains(permission);

  bool canAny(Iterable<String> requiredPermissions) {
    return requiredPermissions.any(permissions.contains);
  }

  bool canAll(Iterable<String> requiredPermissions) {
    return requiredPermissions.every(permissions.contains);
  }
}
