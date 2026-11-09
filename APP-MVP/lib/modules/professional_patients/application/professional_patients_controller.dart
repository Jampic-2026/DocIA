import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/professional_patient.dart';
import '../domain/professional_patients_repository.dart';
import '../infrastructure/api/api_professional_patients_repository.dart';

final professionalPatientsRepositoryProvider =
    Provider<ProfessionalPatientsRepository>(
  (ref) => ApiProfessionalPatientsRepository(
    ref.watch(authenticatedApiClientProvider),
  ),
);

final professionalPatientsProvider =
    FutureProvider<List<ProfessionalPatient>>(
  (ref) => ref.watch(professionalPatientsRepositoryProvider).list(),
);
