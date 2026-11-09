import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/clinical_profile.dart';
import '../domain/clinical_records_repository.dart';
import '../domain/vital_sign_record.dart';
import '../domain/clinical_document.dart';
import '../domain/professional_patient_record.dart';
import '../domain/clinical_correction_request.dart';
import '../domain/clinical_history.dart';
import '../infrastructure/api/api_clinical_records_repository.dart';

final profileCompletionProvider =
    FutureProvider.family<Map<String, dynamic>, String?>(
      (ref, id) => ref
          .watch(clinicalRecordsRepositoryProvider)
          .completion(patientId: id),
    );
final completionPolicyProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(clinicalRecordsRepositoryProvider).completionPolicy(),
);

final clinicalHistoryProvider =
    FutureProvider.family<List<ClinicalHistoryEntry>, String?>(
      (ref, id) =>
          ref.watch(clinicalRecordsRepositoryProvider).history(patientId: id),
    );
final clinicalTrendsProvider =
    FutureProvider.family<ClinicalTrends, ({String? patientId, int days})>(
      (ref, query) => ref
          .watch(clinicalRecordsRepositoryProvider)
          .trends(patientId: query.patientId, days: query.days),
    );

final clinicalRecordsRepositoryProvider = Provider<ClinicalRecordsRepository>(
  (ref) =>
      ApiClinicalRecordsRepository(ref.watch(authenticatedApiClientProvider)),
);

final clinicalProfileProvider = FutureProvider<ClinicalProfile>(
  (ref) => ref.watch(clinicalRecordsRepositoryProvider).getProfile(),
);
final patientClinicalProfileProvider =
    FutureProvider.family<ClinicalProfile, String>(
      (ref, id) => ref
          .watch(clinicalRecordsRepositoryProvider)
          .getProfile(patientId: id),
    );

final vitalSignsProvider = FutureProvider<List<VitalSignRecord>>(
  (ref) => ref.watch(clinicalRecordsRepositoryProvider).listVitalSigns(),
);

final clinicalDocumentsProvider = FutureProvider<List<ClinicalDocument>>(
  (ref) => ref.watch(clinicalRecordsRepositoryProvider).listDocuments(),
);

final professionalPatientRecordProvider =
    FutureProvider.family<ProfessionalPatientRecord, String>(
      (ref, patientId) => ref
          .watch(clinicalRecordsRepositoryProvider)
          .getProfessionalPatientRecord(patientId),
    );

final clinicalCorrectionRequestsProvider =
    FutureProvider<List<ClinicalCorrectionRequest>>(
      (ref) =>
          ref.watch(clinicalRecordsRepositoryProvider).listCorrectionRequests(),
    );
