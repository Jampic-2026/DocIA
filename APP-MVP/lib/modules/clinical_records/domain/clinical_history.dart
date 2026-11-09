class ClinicalHistoryEntry {
  const ClinicalHistoryEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.recordedAt,
    required this.validationStatus,
    this.authorName,
    this.specialty,
  });
  final String id, type, title, summary, validationStatus;
  final String? authorName, specialty;
  final DateTime recordedAt;
}

class ClinicalTrends {
  const ClinicalTrends({required this.points, required this.summary});
  final List<Map<String, dynamic>> points;
  final Map<String, dynamic> summary;
}
