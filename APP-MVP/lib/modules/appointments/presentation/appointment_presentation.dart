import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/appointment.dart';

extension AppointmentModalityPresentation on AppointmentModality {
  String get label => switch (this) {
        AppointmentModality.inPerson => 'Presencial',
        AppointmentModality.telemedicine => 'Telemedicina',
        AppointmentModality.homeVisit => 'Visita domiciliaria',
      };

  IconData get icon => switch (this) {
        AppointmentModality.inPerson => Icons.medical_services_rounded,
        AppointmentModality.telemedicine => Icons.videocam_rounded,
        AppointmentModality.homeVisit => Icons.home_work_outlined,
      };
}

extension AppointmentStatusPresentation on AppointmentStatus {
  String get label => switch (this) {
        AppointmentStatus.scheduled => 'Programada',
        AppointmentStatus.confirmed => 'Confirmada',
        AppointmentStatus.rescheduled => 'Reprogramada',
        AppointmentStatus.cancelled => 'Cancelada',
        AppointmentStatus.inProgress => 'En curso',
        AppointmentStatus.completed => 'Completada',
        AppointmentStatus.noShow => 'No asistió',
      };

  Color get color => switch (this) {
        AppointmentStatus.scheduled => AppColors.warning,
        AppointmentStatus.confirmed => AppColors.success,
        AppointmentStatus.rescheduled => AppColors.info,
        AppointmentStatus.cancelled => AppColors.danger,
        AppointmentStatus.inProgress => AppColors.teal,
        AppointmentStatus.completed => AppColors.info,
        AppointmentStatus.noShow => AppColors.urgent,
      };
}
