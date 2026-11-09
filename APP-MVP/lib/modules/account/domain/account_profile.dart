class AccountProfile {
  const AccountProfile({
    required this.personId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.secondLastName,
    this.documentType,
    this.documentNumber,
    this.birthDate,
    this.nationality,
    this.phone,
    this.photoUrl,
    this.address,
  });

  final String personId;
  final String firstName;
  final String lastName;
  final String email;
  final String? secondLastName;
  final String? documentType;
  final String? documentNumber;
  final DateTime? birthDate;
  final String? nationality;
  final String? phone;
  final String? photoUrl;
  final AccountAddress? address;

  String get fullName => [
        firstName,
        lastName,
        if (secondLastName?.trim().isNotEmpty ?? false) secondLastName!,
      ].join(' ');
}

class AccountAddress {
  const AccountAddress({
    this.municipality,
    this.zone,
    this.addressLine,
    this.reference,
  });
  final String? municipality;
  final String? zone;
  final String? addressLine;
  final String? reference;
}
