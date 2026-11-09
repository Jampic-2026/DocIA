enum EmergencyLevel {
  critical('red'),
  urgent('red'),
  moderate('yellow'),
  low('green');

  const EmergencyLevel(this.riskCode);

  final String riskCode;
}
