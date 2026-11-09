import { Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  DELIVERIES_REPOSITORY,
  DeliveriesRepository,
} from "../domain/ports/deliveries.repository";
import {
  AssignDeliveryDto,
  CreateDeliveryDto,
  CreateDeliveryEvidenceDto,
  UpdateDeliveryStatusDto,
} from "../interfaces/http/dto/delivery.dto";
@Injectable()
export class DeliveriesService {
  constructor(
    @Inject(DELIVERIES_REPOSITORY) private readonly repo: DeliveriesRepository,
  ) {}
  list(u: RequestUser) {
    return this.repo.list(u).then((items) => ({ items }));
  }
  create(u: RequestUser, i: CreateDeliveryDto) {
    return this.repo.create(u, i);
  }
  assign(u: RequestUser, id: string, i: AssignDeliveryDto) {
    return this.repo.assign(u, id, i.professionalId);
  }
  status(u: RequestUser, id: string, i: UpdateDeliveryStatusDto) {
    return this.repo.updateStatus(u, id, i.status, i.reason);
  }
  history(u: RequestUser, id?: string) {
    return this.repo.history(u, id).then((items) => ({ items }));
  }
  evidence(u: RequestUser, id?: string) {
    return this.repo.evidence(u, id).then((items) => ({ items }));
  }
  addEvidence(u: RequestUser, id: string, i: CreateDeliveryEvidenceDto) {
    return this.repo.addEvidence(u, id, i);
  }
}
