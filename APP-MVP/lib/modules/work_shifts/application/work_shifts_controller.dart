import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client_provider.dart';
import '../domain/work_shifts_repository.dart';
import '../infrastructure/api/api_work_shifts_repository.dart';

final workShiftsRepositoryProvider = Provider<WorkShiftsRepository>(
  (ref) => ApiWorkShiftsRepository(ref.watch(authenticatedApiClientProvider)),
);
final workShiftsProvider = FutureProvider.family<List<WorkShift>, DateTime>(
  (ref, month) => ref
      .watch(workShiftsRepositoryProvider)
      .list(from: month, to: DateTime(month.year, month.month + 1)),
);
final availableStaffProvider =
    FutureProvider.family<List<StaffAvailability>, StaffFilter>(
      (ref, filter) =>
          ref.watch(workShiftsRepositoryProvider).availableStaff(filter),
    );
