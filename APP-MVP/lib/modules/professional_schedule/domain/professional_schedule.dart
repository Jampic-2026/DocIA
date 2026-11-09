class AvailabilitySlot {
  const AvailabilitySlot({required this.id, required this.weekday, required this.startTime, required this.endTime, required this.modality});
  final String id;
  final int weekday;
  final String startTime;
  final String endTime;
  final String modality;
}

class ProfessionalTimeBlock {
  const ProfessionalTimeBlock({required this.id, required this.startAt, required this.endAt, this.reason});
  final String id;
  final DateTime startAt;
  final DateTime endAt;
  final String? reason;
}

class ProfessionalSchedule {
  const ProfessionalSchedule({required this.availability, required this.timeBlocks});
  final List<AvailabilitySlot> availability;
  final List<ProfessionalTimeBlock> timeBlocks;
}
