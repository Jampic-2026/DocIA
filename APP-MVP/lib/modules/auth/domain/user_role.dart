enum UserExperience {
  patient,
  professional,
  administration,
  operations,
  unsupported;

  static UserExperience fromRoles(
    Set<String> roles, {
    required String primaryRoleCode,
  }) {
    final orderedRoles = [primaryRoleCode, ...roles];

    for (final role in orderedRoles) {
      switch (role) {
        case 'patient':
        case 'guardian':
          return UserExperience.patient;
        case 'doctor_general':
        case 'doctor_specialist':
        case 'nurse':
          return UserExperience.professional;
        case 'admin':
        case 'human_resources':
        case 'health_partner':
          return UserExperience.administration;
        case 'operator':
        case 'clinical_supervisor':
        case 'delivery_assistant':
          return UserExperience.operations;
      }
    }

    return UserExperience.unsupported;
  }
}
