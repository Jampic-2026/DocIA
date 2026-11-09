import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client_provider.dart';
import '../domain/guidance_repository.dart';
import '../infrastructure/api_guidance_repository.dart';

final guidanceRepositoryProvider = Provider<GuidanceRepository>(
  (ref) => ApiGuidanceRepository(ref.watch(authenticatedApiClientProvider)),
);
final supportCallsProvider = FutureProvider<List<SupportCall>>(
  (ref) => ref.watch(guidanceRepositoryProvider).calls(),
);
final riskPolicyProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(guidanceRepositoryProvider).policy(),
);
