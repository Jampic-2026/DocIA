import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../authorization/route_access_policy.dart';
import '../../experiences/administration/routing/administration_routes.dart';
import '../../experiences/patient/routing/patient_routes.dart';
import '../../experiences/professional/routing/professional_routes.dart';
import '../../modules/auth/application/auth_controller.dart';
import '../../modules/auth/domain/user_role.dart';
import '../../modules/auth/routing/auth_routes.dart';
import '../../modules/incidents/presentation/incidents_screen.dart';
import '../../modules/notifications/presentation/notifications_screen.dart';
import '../../modules/benefits/presentation/benefits_screen.dart';
import '../../modules/payments/presentation/payments_screen.dart';
import '../../modules/payments/presentation/stripe_payment_return_screen.dart';
import '../../modules/help/presentation/help_screen.dart';
import '../../experiences/operations/routing/operations_routes.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      if (auth.status == AuthStatus.restoring) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (!auth.isAuthenticated) {
        final isPublic =
            location == AppRoutes.login ||
            location == AppRoutes.registration ||
            location == AppRoutes.completeRegistration ||
            location == AppRoutes.passwordReset;
        return isPublic ? null : AppRoutes.login;
      }

      if (location == AppRoutes.splash || location == AppRoutes.login) {
        return _homeLocationFor(auth.user!.experience);
      }

      if (auth.user!.experience == UserExperience.unsupported &&
          location != AppRoutes.unsupportedExperience) {
        return AppRoutes.unsupportedExperience;
      }

      if (location == AppRoutes.unsupportedExperience &&
          auth.user!.experience != UserExperience.unsupported) {
        return _homeLocationFor(auth.user!.experience);
      }

      if (location != AppRoutes.accessDenied) {
        final requiredPermissions = RouteAccessPolicy.requiredAnyPermission(
          location,
        );
        if (requiredPermissions != null &&
            !requiredPermissions.any(auth.user!.can)) {
          return AppRoutes.accessDenied;
        }
      }

      return null;
    },
    routes: [
      ...authRoutes,
      GoRoute(
        path: AppRoutes.notifications,
        name: AppRoutes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.incidents,
        name: AppRoutes.incidents,
        builder: (_, __) => const IncidentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.benefits,
        name: AppRoutes.benefits,
        builder: (_, __) => const BenefitsScreen(),
      ),
      GoRoute(
        path: AppRoutes.payments,
        name: AppRoutes.payments,
        builder: (_, state) {
          final stripeStatus = state.uri.queryParameters['stripe_status'];
          if (stripeStatus != null) {
            return StripePaymentReturnScreen(
              status: stripeStatus,
              sessionId: state.uri.queryParameters['session_id'],
            );
          }
          return const PaymentsScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.stripePaymentReturn,
        name: AppRoutes.stripePaymentReturn,
        builder: (_, state) => StripePaymentReturnScreen(
          status: state.uri.queryParameters['stripe_status'],
          sessionId: state.uri.queryParameters['session_id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.help,
        name: AppRoutes.help,
        builder: (_, __) => const HelpScreen(),
      ),
      operationsRoutes(),
      patientRoutes(_rootNavigatorKey),
      professionalRoutes(_rootNavigatorKey),
      administrationRoutes(),
    ],
  );
});

String _homeLocationFor(UserExperience experience) => switch (experience) {
  UserExperience.patient => AppRoutes.patientHome,
  UserExperience.professional => AppRoutes.doctorHome,
  UserExperience.administration => AppRoutes.adminHome,
  UserExperience.operations => AppRoutes.operationsHome,
  UserExperience.unsupported => AppRoutes.unsupportedExperience,
};

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}
