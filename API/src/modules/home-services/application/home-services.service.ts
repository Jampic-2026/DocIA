import { Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  HOME_SERVICES_REPOSITORY,
  HomeServicesRepository,
} from "../domain/ports/home-services.repository";
import {
  AssignHomeServiceDto,
  CreateHomeServiceDto,
  CreateHomeServiceRatingDto,
  CreateServiceEvidenceDto,
  CreateServiceLocationDto,
  UpdateHomeServiceStatusDto,
} from "../interfaces/http/dto/home-service.dto";

@Injectable()
export class HomeServicesService {
  constructor(
    @Inject(HOME_SERVICES_REPOSITORY)
    private readonly repository: HomeServicesRepository,
  ) {}
  list(user: RequestUser) {
    return this.repository.list(user).then((items) => ({ items }));
  }
  create(user: RequestUser, input: CreateHomeServiceDto) {
    return this.repository.create(user, input);
  }
  assign(user: RequestUser, id: string, input: AssignHomeServiceDto) {
    return this.repository.assign(user, id, input);
  }
  updateStatus(
    user: RequestUser,
    id: string,
    input: UpdateHomeServiceStatusDto,
  ) {
    return this.repository.updateStatus(
      user,
      id,
      input.status,
      input.reason,
      input.clinicalNotes,
    );
  }
  history(user: RequestUser, id?: string) {
    return this.repository.history(user, id).then((items) => ({ items }));
  }
  locations(user: RequestUser, id?: string) {
    return this.repository.locations(user, id).then((items) => ({ items }));
  }
  addLocation(user: RequestUser, id: string, input: CreateServiceLocationDto) {
    return this.repository.addLocation(user, id, input);
  }
  evidence(user: RequestUser, id?: string) {
    return this.repository.evidence(user, id).then((items) => ({ items }));
  }
  addEvidence(user: RequestUser, id: string, input: CreateServiceEvidenceDto) {
    return this.repository.addEvidence(user, id, input);
  }
  ratings(user: RequestUser, id?: string) {
    return this.repository.ratings(user, id).then((items) => ({ items }));
  }
  rate(user: RequestUser, id: string, input: CreateHomeServiceRatingDto) {
    return this.repository.rate(user, id, input.rating, input.comment);
  }
}
