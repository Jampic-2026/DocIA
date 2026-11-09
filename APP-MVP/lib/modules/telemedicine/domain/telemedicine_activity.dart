class TelemedicineActivity {
  const TelemedicineActivity({
    required this.participants,
    required this.events,
    required this.files,
  });
  final List<TelemedicineParticipant> participants;
  final List<TelemedicineEvent> events;
  final List<TelemedicineSharedFile> files;
}

class TelemedicineParticipant {
  const TelemedicineParticipant({
    required this.userId,
    required this.name,
    required this.connectionFailures,
    this.joinedAt,
    this.leftAt,
  });
  final String userId, name;
  final int connectionFailures;
  final DateTime? joinedAt, leftAt;
}

class TelemedicineEvent {
  const TelemedicineEvent({
    required this.id,
    required this.eventType,
    required this.createdAt,
  });
  final String id, eventType;
  final DateTime createdAt;
}

class TelemedicineSharedFile {
  const TelemedicineSharedFile({
    required this.id,
    required this.clinicalDocumentId,
    required this.documentType,
    required this.fileUrl,
    this.fileName,
  });
  final String id, clinicalDocumentId, documentType, fileUrl;
  final String? fileName;
}
