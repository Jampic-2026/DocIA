class StaffMember {
  const StaffMember({
    this.academicBackground,
    this.certifications = const [],
    required this.professionalId,
    required this.fullName,
    required this.professionalType,
    required this.verificationStatus,
    this.specialty,
    this.employeeCode,
    this.contractType,
    this.employmentStatus,
    this.hiredAt,
  });
  final String? academicBackground;
  final List<String> certifications;
  final String professionalId, fullName, professionalType, verificationStatus;
  final String? specialty, employeeCode, contractType, employmentStatus;
  final DateTime? hiredAt;
}
