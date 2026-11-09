import { Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  INCIDENTS_REPOSITORY,
  IncidentsRepository,
} from "../domain/ports/incidents.repository";
import { CreateIncidentDto } from "../interfaces/http/dto/create-incident.dto";
import { NotificationsService } from "../../notifications/application/notifications.service";

@Injectable()
export class IncidentsService {
  constructor(
    @Inject(INCIDENTS_REPOSITORY)
    private readonly repository: IncidentsRepository,
    private readonly notifications: NotificationsService,
  ) {}

  async list(user: RequestUser) {
    return { items: await this.repository.list(user) };
  }

  async create(user: RequestUser, input: CreateIncidentDto) {
    const incident = await this.repository.create(user, input);
    await this.notifications.notifyUser(user, user.id, {
      eventCode: "incidents",
      title: "Solicitud registrada",
      body: "Recibimos tu incidente o reclamo y ya está disponible para seguimiento.",
      relatedEntityType: "incident",
      relatedEntityId: incident.id,
    });
    return incident;
  }

  async close(user: RequestUser, id: string) {
    const incident = await this.repository.close(user, id);
    await this.notifications.notifyUser(user, user.id, {
      eventCode: "incidents",
      title: "Solicitud cerrada",
      body: "Tu incidente o reclamo fue cerrado.",
      relatedEntityType: "incident",
      relatedEntityId: incident.id,
    });
    return incident;
  }
}
