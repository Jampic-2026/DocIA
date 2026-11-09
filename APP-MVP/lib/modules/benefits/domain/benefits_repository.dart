import 'benefit.dart';

abstract interface class BenefitsRepository {
  Future<List<Benefit>> list();
  Future<List<BenefitUsage>> listUsages();
}
