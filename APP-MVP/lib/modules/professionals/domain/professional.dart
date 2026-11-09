class Professional {
  const Professional({
    this.bookableSlots = const [],
    this.requiresReferral = false,
    this.publicDetails = const {},
    required this.id,
    required this.fullName,
    required this.specialtyId,
    required this.specialty,
    required this.yearsExperience,
    required this.averageRating,
    required this.ratingCount,
    required this.availability,
  });

  final List<ProfessionalSlot> bookableSlots;
  final bool requiresReferral;
  final Map<String, dynamic> publicDetails;
  bool get isSpecialist => publicDetails['isSpecialist'] == true;
  final String id;
  final String fullName;
  final String specialtyId;
  final String specialty;
  final int yearsExperience;
  final double averageRating;
  final int ratingCount;
  final List<ProfessionalAvailability> availability;
}

class ProfessionalAvailability {
  const ProfessionalAvailability({
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.modality,
  });

  final int weekday;
  final String startTime;
  final String endTime;
  final String modality;
}

class ProfessionalSlot {
  const ProfessionalSlot({
    required this.startAt,
    required this.endAt,
    required this.modality,
  });
  final DateTime startAt, endAt;
  final String modality;
  DateTime get localStart => startAt.toUtc().subtract(const Duration(hours: 4));
  String get timeLabel =>
      '${localStart.hour.toString().padLeft(2, '0')}:${localStart.minute.toString().padLeft(2, '0')}';
}
