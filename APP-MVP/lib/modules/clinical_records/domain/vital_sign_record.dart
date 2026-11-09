class VitalSignRecord {
  const VitalSignRecord({
    required this.id,
    required this.source,
    required this.recordedAt,
    this.systolicPressure,
    this.diastolicPressure,
    this.heartRate,
    this.temperatureC,
    this.oxygenSaturation,
    this.respiratoryRate,
    this.glucoseMgDl,
    this.weightKg,
    this.heightCm,
    this.notes,
  });

  final String id;
  final String source;
  final int? systolicPressure;
  final int? diastolicPressure;
  final int? heartRate;
  final double? temperatureC;
  final double? oxygenSaturation;
  final int? respiratoryRate;
  final double? glucoseMgDl;
  final double? weightKg;
  final double? heightCm;
  final String? notes;
  final DateTime recordedAt;
}

class CreateVitalSignCommand {
  const CreateVitalSignCommand({
    this.systolicPressure,
    this.diastolicPressure,
    this.heartRate,
    this.temperatureC,
    this.oxygenSaturation,
    this.respiratoryRate,
    this.glucoseMgDl,
    this.weightKg,
    this.heightCm,
    this.notes,
  });

  final int? systolicPressure;
  final int? diastolicPressure;
  final int? heartRate;
  final double? temperatureC;
  final double? oxygenSaturation;
  final int? respiratoryRate;
  final double? glucoseMgDl;
  final double? weightKg;
  final double? heightCm;
  final String? notes;
}
