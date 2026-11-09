import 'professional.dart';

abstract interface class ProfessionalsRepository {
  Future<List<Professional>> listDirectory();
}
