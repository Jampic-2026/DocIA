import 'app_environment.dart';

abstract final class BuildConfig {
  static const String _environmentValue = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1/',
  );

  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static AppEnvironment get environment =>
      AppEnvironment.fromValue(_environmentValue);

  static bool get isDevelopment => environment == AppEnvironment.development;

  static void validate() {
    final uri = Uri.tryParse(apiBaseUrl);
    final validScheme = uri?.scheme == 'http' || uri?.scheme == 'https';

    if (uri == null || !uri.hasAuthority || !validScheme) {
      throw StateError('API_BASE_URL debe ser una URL HTTP o HTTPS válida.');
    }

    if (environment == AppEnvironment.production && uri.scheme != 'https') {
      throw StateError('API_BASE_URL debe usar HTTPS en producción.');
    }

    if (!apiBaseUrl.endsWith('/')) {
      throw StateError('API_BASE_URL debe terminar con /.');
    }

    if (stripePublishableKey.isNotEmpty &&
        !stripePublishableKey.startsWith('pk_')) {
      throw StateError('STRIPE_PUBLISHABLE_KEY debe iniciar con pk_.');
    }

    if (environment == AppEnvironment.production &&
        stripePublishableKey.isNotEmpty &&
        !stripePublishableKey.startsWith('pk_live_')) {
      throw StateError(
        'STRIPE_PUBLISHABLE_KEY debe ser una clave live en producción.',
      );
    }
  }
}
