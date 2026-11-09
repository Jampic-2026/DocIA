import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../modules/auth/application/auth_controller.dart';
import 'access_control.dart';

final accessControlProvider = Provider<AccessControl>((ref) {
  final user = ref.watch(authControllerProvider.select((state) => state.user));

  if (user == null) {
    return const AccessControl.anonymous();
  }

  return AccessControl(
    roles: user.roles,
    permissions: user.permissions,
  );
});
