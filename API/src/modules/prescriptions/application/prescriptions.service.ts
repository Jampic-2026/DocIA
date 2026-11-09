import { Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  PRESCRIPTIONS_REPOSITORY,
  PrescriptionsRepository,
} from "../domain/ports/prescriptions.repository";
import { NotificationsService } from "../../notifications/application/notifications.service";

@Injectable()
export class PrescriptionsService {
  constructor(
    @Inject(PRESCRIPTIONS_REPOSITORY)
    private readonly repository: PrescriptionsRepository,
    private readonly notifications: NotificationsService,
  ) {}

  async listForUser(user: RequestUser) {
    const items = await this.repository.listForUser(user);
    return {
      items: items.map((prescription) => ({
        ...prescription,
        issuedAt: prescription.issuedAt?.toISOString() ?? null,
        expiresAt: prescription.expiresAt?.toISOString() ?? null,
        createdAt: prescription.createdAt.toISOString(),
      })),
    };
  }

  async itemsForUser(user: RequestUser) {
    const prescriptions = await this.repository.listForUser(user);
    return {
      items: prescriptions.flatMap((prescription) =>
        prescription.items.map((item) => ({
          ...item,
          prescriptionId: prescription.id,
        })),
      ),
    };
  }

  async createDraft(
    user: RequestUser,
    input: {
      patientId: string;
      appointmentId: string;
      items: Array<{
        medicationName: string;
        dose?: string;
        frequency?: string;
        duration?: string;
        instructions?: string;
      }>;
    },
  ) {
    const prescription = await this.repository.createDraft(user, input);
    return {
      ...prescription,
      issuedAt: null,
      expiresAt: null,
      createdAt: prescription.createdAt.toISOString(),
    };
  }

  safetyReview(user: RequestUser, id: string) {
    return this.repository.safetyReview(user, id);
  }
  async issue(
    user: RequestUser,
    id: string,
    expiresAtValue: string,
    review?: { fingerprint?: string; reason?: string },
  ) {
    const prescription = await this.repository.issue(
      user,
      id,
      new Date(expiresAtValue),
      review,
    );
    await this.notifications.notifyPatient(user, prescription.patientId, {
      eventCode: "prescriptions",
      title: "Receta médica emitida",
      body: "Tu receta fue emitida y firmada en Doc IA.",
      relatedEntityType: "prescription",
      relatedEntityId: prescription.id,
    });
    return {
      ...prescription,
      issuedAt: prescription.issuedAt?.toISOString() ?? null,
      expiresAt: prescription.expiresAt?.toISOString() ?? null,
      createdAt: prescription.createdAt.toISOString(),
    };
  }
}
