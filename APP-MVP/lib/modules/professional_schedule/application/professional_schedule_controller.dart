import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client_provider.dart';
import '../domain/professional_schedule.dart';
import '../domain/professional_schedule_repository.dart';
import '../infrastructure/api/api_professional_schedule_repository.dart';

final professionalScheduleRepositoryProvider = Provider<ProfessionalScheduleRepository>((ref) =>
  ApiProfessionalScheduleRepository(ref.watch(authenticatedApiClientProvider)));
final professionalScheduleProvider = FutureProvider<ProfessionalSchedule>((ref) =>
  ref.watch(professionalScheduleRepositoryProvider).getSchedule());
