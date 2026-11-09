enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment fromValue(String value) {
    return AppEnvironment.values.firstWhere(
      (environment) => environment.name == value.trim().toLowerCase(),
      orElse: () => throw StateError(
        'APP_ENV debe ser development, staging o production.',
      ),
    );
  }
}
