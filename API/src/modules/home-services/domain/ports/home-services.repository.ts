import { RequestUser } from "../../../../common/types/request-user";
import { HomeService } from "../home-service";

export const HOME_SERVICES_REPOSITORY = Symbol("HOME_SERVICES_REPOSITORY");

export interface HomeServicesRepository {
  list(user: RequestUser): Promise<HomeService[]>;
  create(
    user: RequestUser,
    input: { serviceId: string; addressId: string; requestedFor?: string },
  ): Promise<HomeService>;
  assign(
    user: RequestUser,
    id: string,
    input: { professionalId?: string; partnerId?: string },
  ): Promise<HomeService>;
  updateStatus(
    user: RequestUser,
    id: string,
    status: string,
    reason?: string,
    clinicalNotes?: string,
  ): Promise<HomeService>;
  history(user: RequestUser, serviceId?: string): Promise<unknown[]>;
  locations(user: RequestUser, serviceId?: string): Promise<unknown[]>;
  addLocation(
    user: RequestUser,
    id: string,
    input: { latitude: number; longitude: number; accuracyM?: number },
  ): Promise<unknown>;
  evidence(user: RequestUser, serviceId?: string): Promise<unknown[]>;
  addEvidence(
    user: RequestUser,
    id: string,
    input: { evidenceType: string; fileUrl: string; notes?: string },
  ): Promise<unknown>;
  ratings(user: RequestUser, serviceId?: string): Promise<unknown[]>;
  rate(
    user: RequestUser,
    id: string,
    rating: number,
    comment?: string,
  ): Promise<unknown>;
}
