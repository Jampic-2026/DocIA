class GoogleWorkspaceStatus {
  const GoogleWorkspaceStatus({
    required this.connected,
    this.expiresAt,
    this.connectedByName,
    required this.redirectUri,
  });

  final bool connected;
  final DateTime? expiresAt;
  final String? connectedByName;
  final String redirectUri;
}
