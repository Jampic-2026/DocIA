import { Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import { CreateDependent } from "../domain/create-dependent";
import {
  PATIENTS_REPOSITORY,
  PatientResource,
  PatientsRepository,
} from "../domain/ports/patients.repository";

@Injectable()
export class PatientsService {
  constructor(
    @Inject(PATIENTS_REPOSITORY)
    private readonly patientsRepository: PatientsRepository,
  ) {}

  createDependent(user: RequestUser, input: CreateDependent) {
    return this.patientsRepository.createDependent(user, input);
  }

  async family(user: RequestUser) {
    return { items: await this.patientsRepository.listFamily(user) };
  }

  async forProfessional(user: RequestUser) {
    const patients = await this.patientsRepository.listForProfessional(user);
    return {
      items: patients.map((patient) => ({
        ...patient,
        lastVisitAt: patient.lastVisitAt?.toISOString() ?? null,
      })),
    };
  }

  async createFamilyAuthorization(
    user: RequestUser,
    input: {
      email: string;
      relationship: string;
      canViewHistory: boolean;
      canBookAppointments: boolean;
      canHandleEmergencies: boolean;
    },
  ) {
    await this.patientsRepository.createFamilyAuthorization(user, input);
    return { linked: true };
  }

  async updateFamilyAuthorization(
    user: RequestUser,
    id: string,
    input: {
      relationship?: string;
      canViewHistory: boolean;
      canBookAppointments: boolean;
      canHandleEmergencies: boolean;
    },
  ) {
    await this.patientsRepository.updateFamilyAuthorization(user, id, input);
    return { updated: true };
  }

  async revokeFamilyAuthorization(user: RequestUser, id: string) {
    await this.patientsRepository.revokeFamilyAuthorization(user, id);
    return { revoked: true };
  }

  async createGuardianLinkCode(user: RequestUser) {
    return this.patientsRepository.createGuardianLinkCode(user);
  }

  async redeemGuardianLinkCode(
    user: RequestUser,
    input: { code: string; relationship: string },
  ) {
    await this.patientsRepository.redeemGuardianLinkCode(user, input);
    return { linked: true };
  }
  async resource(user: RequestUser, resource: PatientResource) {
    return { items: await this.patientsRepository.resource(user, resource) };
  }
}
