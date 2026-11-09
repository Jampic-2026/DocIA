import 'package:flutter_test/flutter_test.dart';
import 'package:jampic/modules/appointments/domain/appointment.dart';
import 'package:jampic/modules/appointments/infrastructure/api/appointment_dto.dart';

void main() {
  test('convierte el contrato HTTP de una cita al dominio', () {
    final appointment = AppointmentDto.fromJson({
      'id': 'appointment-id',
      'patientId': 'patient-id',
      'patientName': 'Paciente Prueba',
      'professionalId': 'professional-id',
      'professionalName': 'Profesional Prueba',
      'specialty': 'Medicina General',
      'startAt': '2026-07-23T14:00:00.000Z',
      'endAt': '2026-07-23T14:30:00.000Z',
      'modality': 'telemedicine',
      'status': 'confirmed',
      'reason': 'Control',
    }).toDomain();

    expect(appointment.modality, AppointmentModality.telemedicine);
    expect(appointment.status, AppointmentStatus.confirmed);
    expect(appointment.patientName, 'Paciente Prueba');
    expect(appointment.professionalName, 'Profesional Prueba');
  });
}
