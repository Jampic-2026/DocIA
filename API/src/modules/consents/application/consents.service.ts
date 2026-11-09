import { ForbiddenException, Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  CONSENTS_REPOSITORY,
  ConsentsRepository,
} from "../domain/ports/consents.repository";

@Injectable()
export class ConsentsService {
  constructor(
    @Inject(CONSENTS_REPOSITORY)
    private readonly repository: ConsentsRepository,
  ) {}

  async list(user: RequestUser) {
    return { items: await this.repository.listForUser(user) };
  }

  accept(
    user: RequestUser,
    code: string,
    metadata: { ipAddress?: string; userAgent?: string },
  ) {
    return this.repository.accept(user, code, metadata);
  }

  revoke(user: RequestUser, code: string) {
    return this.repository.revoke(user, code);
  }

  async assertAccepted(user: RequestUser, code: string) {
    if (!(await this.repository.isAccepted(user, code))) {
      throw new ForbiddenException({
        message:
          "Debes aceptar el consentimiento antes de utilizar este servicio.",
        code: "CONSENT_REQUIRED",
        consentCode: code,
      });
    }
  }
}
