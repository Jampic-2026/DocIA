class ClinicalDocument {
  const ClinicalDocument({
    required this.id,
    required this.documentType,
    required this.fileUrl,
    required this.isRestricted,
    required this.source,
    required this.validationStatus,
    required this.createdAt,
    this.fileName,
    this.mimeType,
  });

  final String id;
  final String documentType;
  final String fileUrl;
  final String? fileName;
  final String? mimeType;
  final bool isRestricted;
  final String source;
  final String validationStatus;
  final DateTime createdAt;
}

class CreateClinicalDocumentCommand {
  const CreateClinicalDocumentCommand({
    required this.documentType,
    required this.fileUrl,
    required this.fileName,
    required this.mimeType,
    required this.isRestricted,
  });

  final String documentType;
  final String fileUrl;
  final String fileName;
  final String mimeType;
  final bool isRestricted;
}
