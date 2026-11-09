import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client_provider.dart';
import '../domain/professional_profile.dart';
import '../domain/professional_profile_repository.dart';
import '../infrastructure/api/api_professional_profile_repository.dart';

final professionalProfileRepositoryProvider =
    Provider<ProfessionalProfileRepository>(
      (ref) => ApiProfessionalProfileRepository(
        ref.watch(authenticatedApiClientProvider),
      ),
    );
final professionalProfileProvider = FutureProvider<ProfessionalProfile>(
  (ref) => ref.watch(professionalProfileRepositoryProvider).getProfile(),
);
