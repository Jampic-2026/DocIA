class WorkShift {
  const WorkShift({
    required this.id,
    required this.professionalId,
    required this.professionalName,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.location,
    this.area,
    this.notes,
  });
  final String id, professionalId, professionalName, status, location;
  final DateTime startAt, endAt;
  final String? area, notes;
  bool get isCurrent =>
      status == 'assigned' &&
      !startAt.isAfter(DateTime.now()) &&
      endAt.isAfter(DateTime.now());
}

class StaffAvailability {
  const StaffAvailability({
    required this.id,
    required this.name,
    required this.role,
    required this.availableNow,
    this.location,
    this.area,
    this.specialty,
    this.specialtyId,
  });
  final String id, name, role;
  final bool availableNow;
  final String? location, area, specialty, specialtyId;
}

typedef StaffFilter = ({
  String? role,
  String? location,
  String? specialtyId,
  bool availableOnly,
  String? serviceType,
});

abstract interface class WorkShiftsRepository {
  Future<List<WorkShift>> list({required DateTime from, required DateTime to});
  Future<List<StaffAvailability>> availableStaff(StaffFilter filter);
  Future<void> save({
    String? id,
    required String professionalId,
    required DateTime startAt,
    required DateTime endAt,
    required String location,
    String? area,
    String? notes,
    required String status,
    required String reason,
  });
}
