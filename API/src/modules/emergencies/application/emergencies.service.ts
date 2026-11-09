import { BadRequestException, Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import { ConsentsService } from "../../consents/application/consents.service";
import { CreateEmergency, EmergencyCare } from "../domain/emergency-policy";
import {
  EMERGENCIES_REPOSITORY,
  EmergenciesRepository,
  EmergencyResource,
} from "../domain/ports/emergencies.repository";

@Injectable()
export class EmergenciesService {
  constructor(
    @Inject(EMERGENCIES_REPOSITORY)
    private readonly repository: EmergenciesRepository,
    private readonly consents: ConsentsService,
  ) {}
  list(user: RequestUser) {
    return this.repository.list(user);
  }
  resource(user: RequestUser, resource: EmergencyResource) {
    return this.repository.resource(user, resource);
  }
  async create(user: RequestUser, input: CreateEmergency) {
    if ((input.latitude == null) !== (input.longitude == null))
      throw new BadRequestException(
        "La ubicación requiere latitud y longitud.",
      );
    if (input.latitude == null && !input.manualAddress?.trim())
      throw new BadRequestException(
        "Indica una ubicación o dirección de referencia.",
      );
    if (input.latitude != null)
      await this.consents.assertAccepted(user, "geolocation");
    return this.repository.create(user, input);
  }
  cancel(user: RequestUser, id: string) {
    return this.repository.cancel(user, id);
  }
  assign(
    user: RequestUser,
    id: string,
    input: { professionalId?: string; operatorId?: string },
  ) {
    return this.repository.assign(user, id, input);
  }
  updateStatus(
    user: RequestUser,
    id: string,
    input: { status: string; notes?: string },
  ) {
    return this.repository.updateStatus(user, id, input);
  }
  decideAssignment(
    user: RequestUser,
    id: string,
    input: { decision: "accepted" | "rejected"; reason?: string },
  ) {
    return this.repository.decideAssignment(user, id, input);
  }
  recordCare(user: RequestUser, id: string, input: EmergencyCare) {
    return this.repository.recordCare(user, id, input);
  }
  async careHistory(user: RequestUser, id: string) {
    return { items: await this.repository.careHistory(user, id) };
  }
}
