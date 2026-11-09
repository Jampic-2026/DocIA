import 'professional_patient.dart';

abstract interface class ProfessionalPatientsRepository {
  Future<List<ProfessionalPatient>> list();
}
