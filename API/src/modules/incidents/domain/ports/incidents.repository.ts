import { RequestUser } from "../../../../common/types/request-user";
import { Incident } from "../incident";

export const INCIDENTS_REPOSITORY = Symbol("INCIDENTS_REPOSITORY");

export interface IncidentsRepository {
  list(user: RequestUser): Promise<Incident[]>;
  create(
    user: RequestUser,
    input: {
      module: string;
      incidentType: string;
      severity: string;
      description: string;
    },
  ): Promise<Incident>;
  close(user: RequestUser, id: string): Promise<Incident>;
}
