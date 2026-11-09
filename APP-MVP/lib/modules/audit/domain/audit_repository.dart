import 'audit_event.dart';

abstract interface class AuditRepository {
  Future<List<AuditEvent>> listEvents();
}
