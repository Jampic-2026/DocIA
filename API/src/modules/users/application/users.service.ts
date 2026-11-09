import { Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  USERS_REPOSITORY,
  UsersRepository,
} from "../domain/ports/users.repository";
@Injectable()
export class UsersService {
  constructor(
    @Inject(USERS_REPOSITORY) private readonly repository: UsersRepository,
  ) {}
  overview(user: RequestUser) {
    return this.repository.overview(user);
  }
  async updateStatus(
    user: RequestUser,
    id: string,
    status: string,
    reason?: string,
  ) {
    await this.repository.updateStatus(user, id, status, reason);
    return { updated: true };
  }
  async updateRoles(user: RequestUser, id: string, roles: string[]) {
    await this.repository.updateRoles(user, id, roles);
    return { updated: true };
  }
}
