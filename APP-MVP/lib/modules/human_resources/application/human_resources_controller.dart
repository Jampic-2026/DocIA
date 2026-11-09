import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client_provider.dart';
import '../domain/human_resources_repository.dart';
import '../domain/staff_member.dart';
import '../infrastructure/api/api_human_resources_repository.dart';

final humanResourcesRepositoryProvider = Provider<HumanResourcesRepository>(
  (ref) =>
      ApiHumanResourcesRepository(ref.watch(authenticatedApiClientProvider)),
);
final staffProvider = FutureProvider<List<StaffMember>>(
  (ref) => ref.watch(humanResourcesRepositoryProvider).listStaff(),
);
final personnelApplicationsProvider =
    FutureProvider<List<PersonnelApplication>>(
      (ref) => ref.watch(humanResourcesRepositoryProvider).listApplications(),
    );
final personnelDocumentsProvider = FutureProvider<List<PersonnelDocument>>(
  (ref) => ref.watch(humanResourcesRepositoryProvider).listDocuments(),
);
final documentRequirementsProvider = FutureProvider<List<DocumentRequirements>>(
  (ref) => ref.watch(humanResourcesRepositoryProvider).listRequirements(),
);
final verificationSpecialtiesProvider =
    FutureProvider<List<VerificationSpecialty>>(
      (ref) => ref.watch(humanResourcesRepositoryProvider).listSpecialties(),
    );
final professionalDocumentsProvider =
    FutureProvider.family<List<PersonnelDocument>, String>(
      (ref, id) => ref
          .watch(humanResourcesRepositoryProvider)
          .listProfessionalDocuments(id),
    );
