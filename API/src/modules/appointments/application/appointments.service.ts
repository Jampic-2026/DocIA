import { Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  APPOINTMENTS_REPOSITORY,
  AppointmentResource,
  AppointmentsRepository,
} from "../domain/ports/appointments.repository";
import { NotificationsService } from "../../notifications/application/notifications.service";

@Injectable()
export class AppointmentsService {
  async markNoShow(user: RequestUser, id: string, reason: string) {
    const appointment = await this.appointmentsRepository.markNoShow(
      user,
      id,
      reason,
    );
    await this.notifyParticipants(user, id, {
      eventCode: "appointments",
      title: "Inasistencia registrada",
      body: "Se registró inasistencia a una cita. Consulta el detalle de tu agenda.",
      relatedEntityType: "appointment",
      relatedEntityId: id,
    });
    return this.serialize(appointment);
  }
  constructor(
    @Inject(APPOINTMENTS_REPOSITORY)
    private readonly appointmentsRepository: AppointmentsRepository,
    private readonly notifications: NotificationsService,
  ) {}

  async listForUser(user: RequestUser) {
    const appointments = await this.appointmentsRepository.listForUser(user);

    return {
      items: appointments.map((appointment) => ({
        id: appointment.id,
        patientId: appointment.patientId,
        patientName: appointment.patientName,
        professionalId: appointment.professionalId,
        professionalName: appointment.professionalName,
        specialty: appointment.specialty,
        modality: appointment.modality,
        status: appointment.status,
        startAt: appointment.startAt.toISOString(),
        endAt: appointment.endAt.toISOString(),
        reason: appointment.reason,
      })),
    };
  }
  async create(
    user: RequestUser,
    input: {
      professionalId: string;
      serviceId?: string;
      patientId?: string;
      specialtyId: string;
      modality: "telemedicine" | "home_visit" | "in_person";
      startAt: string;
      endAt: string;
      reason?: string;
    },
  ) {
    const appointment = await this.appointmentsRepository.create(user, {
      ...input,
      startAt: new Date(input.startAt),
      endAt: new Date(input.endAt),
    });
    await this.notifyParticipants(user, appointment.id, {
      eventCode: "appointments",
      title: "Cita reservada",
      body: `La cita entre ${appointment.patientName} y ${appointment.professionalName} fue programada para ${appointment.startAt.toLocaleString("es-BO", { timeZone: "America/La_Paz" })}.`,
      relatedEntityType: "appointment",
      relatedEntityId: appointment.id,
    });
    return {
      ...appointment,
      startAt: appointment.startAt.toISOString(),
      endAt: appointment.endAt.toISOString(),
    };
  }

  async cancel(user: RequestUser, appointmentId: string, reason?: string) {
    const appointment = await this.appointmentsRepository.cancel(
      user,
      appointmentId,
      reason,
    );
    await this.notifyParticipants(user, appointment.id, {
      eventCode: "appointments",
      title: "Cita cancelada",
      body: `La cita entre ${appointment.patientName} y ${appointment.professionalName} fue cancelada.`,
      relatedEntityType: "appointment",
      relatedEntityId: appointment.id,
    });
    return this.serialize(appointment);
  }

  async reschedule(
    user: RequestUser,
    appointmentId: string,
    input: { startAt: string; endAt: string },
  ) {
    const appointment = await this.appointmentsRepository.reschedule(
      user,
      appointmentId,
      new Date(input.startAt),
      new Date(input.endAt),
    );
    await this.notifyParticipants(user, appointment.id, {
      eventCode: "appointments",
      title: "Cita reprogramada",
      body: `La cita entre ${appointment.patientName} y ${appointment.professionalName} cambió al ${appointment.startAt.toLocaleString("es-BO", { timeZone: "America/La_Paz" })}.`,
      relatedEntityType: "appointment",
      relatedEntityId: appointment.id,
    });
    return this.serialize(appointment);
  }

  async careActions(user: RequestUser) {
    return this.appointmentsRepository.listCareActions(user);
  }

  async rate(
    user: RequestUser,
    appointmentId: string,
    input: { rating: number; comment?: string; publicComment?: boolean },
  ) {
    await this.appointmentsRepository.rate(
      user,
      appointmentId,
      input.rating,
      input.comment,
      input.publicComment,
    );
    return { rated: true };
  }

  async createReferral(
    user: RequestUser,
    input: {
      patientId: string;
      specialtyId: string;
      reason: string;
      priority: string;
      referralType: string;
      validUntil?: string;
    },
  ) {
    const id = await this.appointmentsRepository.createReferral(user, {
      ...input,
      validUntil: input.validUntil ? new Date(input.validUntil) : undefined,
    });
    await this.notifications.notifyPatient(user, input.patientId, {
      eventCode: "appointments",
      title: "Nueva derivación médica",
      body: "Tu profesional registró una derivación para continuar tu atención.",
      relatedEntityType: "referral",
      relatedEntityId: id,
    });
    return { id };
  }

  async resource(user: RequestUser, resource: AppointmentResource) {
    return {
      items: await this.appointmentsRepository.resource(user, resource),
    };
  }

  private serialize(
    appointment: Awaited<ReturnType<AppointmentsRepository["cancel"]>>,
  ) {
    return {
      ...appointment,
      startAt: appointment.startAt.toISOString(),
      endAt: appointment.endAt.toISOString(),
    };
  }

  private async notifyParticipants(
    user: RequestUser,
    appointmentId: string,
    notification: {
      eventCode: string;
      title: string;
      body: string;
      relatedEntityType?: string;
      relatedEntityId?: string;
    },
  ) {
    const participants = await this.appointmentsRepository.participantUserIds(
      user,
      appointmentId,
    );
    const recipients = new Set(
      [
        participants.patientUserId,
        participants.professionalUserId,
        ...(participants.alertUserIds ?? []),
      ].filter((id): id is string => Boolean(id)),
    );
    await Promise.all(
      [...recipients].map((targetUserId) =>
        this.notifications.notifyUser(user, targetUserId, notification),
      ),
    );
  }
}
