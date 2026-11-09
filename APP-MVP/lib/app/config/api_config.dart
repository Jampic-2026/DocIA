import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'build_config.dart';

class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
  });

  final Uri baseUrl;
}

final apiConfigProvider = Provider<ApiConfig>(
  (ref) => ApiConfig(
    baseUrl: Uri.parse(BuildConfig.apiBaseUrl),
  ),
);
