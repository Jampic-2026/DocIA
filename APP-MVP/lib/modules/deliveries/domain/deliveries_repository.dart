import 'delivery_summary.dart';

abstract interface class DeliveriesRepository {
  Future<List<DeliverySummary>> list();
}
