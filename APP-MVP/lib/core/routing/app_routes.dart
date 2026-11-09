/// Definición centralizada de las rutas con nombre de la aplicación.
///
/// Mantener los paths y nombres aquí evita "magic strings" dispersos y
/// facilita la navegación con `context.goNamed(...)`.
abstract class AppRoutes {
  AppRoutes._();

  // Globales
  static const String splash = '/';
  static const String login = '/login';
  static const String registration = '/register';
  static const String completeRegistration = '/register/complete';
  static const String passwordReset = '/password-reset';
  static const String unsupportedExperience = '/unsupported-experience';
  static const String accessDenied = '/access-denied';
  static const String notifications = '/notifications';
  static const String incidents = '/incidents';
  static const String benefits = '/benefits';
  static const String payments = '/payments';
  static const String stripePaymentReturn = '/payments/return';
  static const String help = '/help';

  // Paciente (shell + tabs)
  static const String patientHome = '/patient';
  static const String patientAppointments = '/patient/appointments';
  static const String appointmentDetail = 'appointment-detail';
  static const String patientAssistant = '/patient/assistant';
  static const String patientProfile = '/patient/profile';
  static const String patientCoins = '/patient/coins';
  static const String patientNotifications = '/patient/notifications';
  // Paciente (detalle, push sobre el shell)
  static const String clinicalProfile = 'clinical-profile';
  static const String vitalSigns = 'vital-signs';
  static const String clinicalDocuments = 'clinical-documents';
  static const String clinicalCorrections = 'clinical-corrections';
  static const String family = 'family';
  static const String emergency = 'emergency';
  static const String doctorDirectory = 'directory';
  static const String telemedicine = 'telemedicine';
  static const String patientPrescriptions = 'prescriptions';
  static const String catalog = 'catalog';
  static const String coins = 'coins';
  static const String consents = 'consents';
  static const String professionalApplication = 'professional-application';

  // Médico
  static const String doctorHome = '/doctor';
  static const String doctorAgenda = '/doctor/agenda';
  static const String doctorPatients = '/doctor/patients';
  static const String doctorProfile = '/doctor/profile';
  static const String clinicalNote = 'clinical-note';
  static const String professionalPatientRecord = 'patient-record';
  static const String prescription = 'prescription';
  static const String teleconsult = 'teleconsult';
  static const String professionalSchedule = 'availability';
  static const String professionalProfile = 'professional-profile';

  // Administrativo
  static const String adminHome = '/admin';
  static const String adminManagement = '/admin/management';
  static const String adminProfile = '/admin/profile';

  // Operación
  static const String operationsHome = '/operations';
  static const String operationsProfile = '/operations/profile';
}
