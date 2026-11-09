import 'google_workspace_status.dart';

abstract interface class IntegrationsRepository {
  Future<GoogleWorkspaceStatus> googleStatus();
  Future<Uri> googleAuthorizationUrl();
  Future<void> disconnectGoogle();
}
