import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/appointment.dart';
import '../domain/appointment_care_actions.dart';
import '../domain/appointments_repository.dart';
import '../infrastructure/api/api_appointments_repository.dart';

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>(
  (ref) => ApiAppointmentsRepository(
    ref.watch(authenticatedApiClientProvider),
  ),
);

class AppointmentsController extends AsyncNotifier<List<Appointment>> {
  @override
  Future<List<Appointment>> build() {
    return ref.read(appointmentsRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      ref.read(appointmentsRepositoryProvider).list,
    );
  }

  Future<Appointment> create(CreateAppointmentCommand command) async {
    final appointment = await ref.read(appointmentsRepositoryProvider).create(command);
    state = AsyncData([...state.valueOrNull ?? const [], appointment]);
    return appointment;
  }

  Future<Appointment> cancel(String appointmentId, {String? reason}) async {
    final updated = await ref
        .read(appointmentsRepositoryProvider)
        .cancel(appointmentId, reason: reason);
    _replace(updated);
    return updated;
  }

  Future<Appointment> reschedule(
    String appointmentId, {
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final updated = await ref
        .read(appointmentsRepositoryProvider)
        .reschedule(appointmentId, startAt: startAt, endAt: endAt);
    _replace(updated);
    return updated;
  }

  void _replace(Appointment updated) {
    state = AsyncData([
      for (final appointment in state.valueOrNull ?? const <Appointment>[])
        if (appointment.id == updated.id) updated else appointment,
    ]);
  }
}

final appointmentsControllerProvider =
    AsyncNotifierProvider<AppointmentsController, List<Appointment>>(
  AppointmentsController.new,
);
final appointmentCareActionsProvider=FutureProvider<AppointmentCareActions>((ref)=>ref.watch(appointmentsRepositoryProvider).careActions());
