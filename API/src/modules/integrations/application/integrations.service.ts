import { Inject, Injectable, Inject as InjectRepository } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  INTEGRATIONS_REPOSITORY,
  IntegrationsRepository,
} from "../domain/ports/integrations.repository";
import { MEET_PROVIDER, MeetProvider } from "../domain/ports/meet-provider";

@Injectable()
export class IntegrationsService {
  constructor(
    @Inject(MEET_PROVIDER) private readonly meet: MeetProvider,
    @InjectRepository(INTEGRATIONS_REPOSITORY)
    private readonly repository: IntegrationsRepository,
  ) {}

  async googleStatus() {
    return this.meet.status();
  }

  async googleAuthorization(user: RequestUser) {
    const authorizationUrl = await this.meet.createAuthorizationUrl(user.id);
    await this.audit(user, "google_meet_authorization_started");
    return { authorizationUrl };
  }

  async googleCallback(code: string, state: string) {
    await this.meet.completeAuthorization(code, state);
    return {
      connected: true,
      message: "Google Meet quedó conectado. Puedes cerrar esta ventana.",
    };
  }

  async disconnectGoogle(user: RequestUser) {
    await this.meet.disconnect();
    await this.audit(user, "google_meet_disconnected");
    return { connected: false };
  }

  private audit(user: RequestUser, action: string) {
    return this.repository.logIntegrationAction(user, action);
  }
}
