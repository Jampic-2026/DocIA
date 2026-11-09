import 'consent_preference.dart';

abstract interface class ConsentsRepository {
  Future<List<ConsentPreference>> list();
  Future<void> accept(String code);
  Future<void> revoke(String code);
}
