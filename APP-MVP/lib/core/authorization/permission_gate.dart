import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'access_control_provider.dart';

class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final String permission;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(
      accessControlProvider.select(
        (access) => access.can(permission),
      ),
    );

    return allowed ? child : fallback;
  }
}

class AnyPermissionGate extends ConsumerWidget {
  const AnyPermissionGate({
    super.key,
    required this.permissions,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final Set<String> permissions;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(
      accessControlProvider.select(
        (access) => access.canAny(permissions),
      ),
    );

    return allowed ? child : fallback;
  }
}
