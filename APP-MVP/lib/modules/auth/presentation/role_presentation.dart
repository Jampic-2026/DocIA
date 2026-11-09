import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/user_role.dart';

extension UserExperiencePresentation on UserExperience {
  String get displayName => switch (this) {
    UserExperience.patient => 'Paciente',
    UserExperience.professional => 'Profesional de salud',
    UserExperience.administration => 'Administración',
    UserExperience.operations => 'Operaciones',
    UserExperience.unsupported => 'Sin experiencia asignada',
  };

  String get description => switch (this) {
    UserExperience.patient => 'Gestiona tu salud, citas y emergencias',
    UserExperience.professional => 'Atiende pacientes, agenda y recetas',
    UserExperience.administration => 'Administra la operación de la plataforma',
    UserExperience.operations => 'Gestiona solicitudes y atención operativa',
    UserExperience.unsupported =>
      'Tu rol todavía no tiene una experiencia disponible',
  };

  IconData get icon => switch (this) {
    UserExperience.patient => Icons.favorite_rounded,
    UserExperience.professional => Icons.medical_services_rounded,
    UserExperience.administration => Icons.admin_panel_settings_rounded,
    UserExperience.operations => Icons.health_and_safety_rounded,
    UserExperience.unsupported => Icons.lock_outline_rounded,
  };

  Color get color => switch (this) {
    UserExperience.patient => AppColors.teal,
    UserExperience.professional => AppColors.blue,
    UserExperience.administration => AppColors.navy,
    UserExperience.operations => AppColors.danger,
    UserExperience.unsupported => AppColors.warning,
  };
}
