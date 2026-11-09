import 'professional_schedule.dart';

abstract interface class ProfessionalScheduleRepository {
  Future<ProfessionalSchedule> getSchedule();
  Future<void> addAvailability({required int weekday, required String startTime, required String endTime, required String modality});
  Future<void> removeAvailability(String id);
  Future<void> addTimeBlock({required DateTime startAt, required DateTime endAt, String? reason});
  Future<void> removeTimeBlock(String id);
}
