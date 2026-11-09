import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/access_denied_screen.dart';
import '../presentation/login_screen.dart';
import '../presentation/registration_screen.dart';
import '../presentation/splash_screen.dart';
import '../presentation/unsupported_experience_screen.dart';
import '../presentation/password_reset_screen.dart';

final List<RouteBase> authRoutes = [
  GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
  GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
  GoRoute(
    path: AppRoutes.registration,
    builder: (_, __) => const RegistrationScreen(),
  ),
  GoRoute(
    path: AppRoutes.completeRegistration,
    builder: (_, state) => RegistrationScreen(
      initialToken: state.uri.queryParameters['token'],
    ),
  ),
  GoRoute(
    path: AppRoutes.passwordReset,
    builder: (_, state) => PasswordResetScreen(
      initialToken: state.uri.queryParameters['token'],
    ),
  ),
  GoRoute(
    path: AppRoutes.unsupportedExperience,
    builder: (_, __) => const UnsupportedExperienceScreen(),
  ),
  GoRoute(
    path: AppRoutes.accessDenied,
    builder: (_, __) => const AccessDeniedScreen(),
  ),
];
