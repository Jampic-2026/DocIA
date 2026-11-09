import 'appointment.dart';
import 'appointment_care_actions.dart';

abstract interface class AppointmentsRepository {
  Future<void> markNoShow(String appointmentId, {required String reason});
  Future<List<Appointment>> list();
  Future<Appointment> create(CreateAppointmentCommand command);
  Future<Appointment> cancel(String appointmentId, {String? reason});
  Future<Appointment> reschedule(
    String appointmentId, {
    required DateTime startAt,
    required DateTime endAt,
  });
  Future<AppointmentCareActions> careActions();
  Future<void> rate(
    String appointmentId, {
    required int rating,
    String? comment,
    bool publicComment = false,
  });
  Future<void> createReferral({
    required String patientId,
    required String specialtyId,
    required String reason,
    required String priority,
    required String referralType,
    DateTime? validUntil,
  });
}

class CreateAppointmentCommand {
  const CreateAppointmentCommand({
    this.patientId,
    this.serviceId,
    required this.professionalId,
    required this.specialtyId,
    required this.modality,
    required this.startAt,
    required this.endAt,
    this.reason,
  });
  final String professionalId;
  final String? patientId;
  final String? serviceId;
  final String specialtyId;
  final AppointmentModality modality;
  final DateTime startAt;
  final DateTime endAt;
  final String? reason;
}
