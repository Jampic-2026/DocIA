import { Inject, Injectable, NotFoundException } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  PEOPLE_REPOSITORY,
  PeopleResource,
  PeopleRepository,
} from "../domain/ports/people.repository";
import { UpdateAccountProfileDto } from "../interfaces/http/dto/update-account-profile.dto";

@Injectable()
export class PeopleService {
  constructor(
    @Inject(PEOPLE_REPOSITORY)
    private readonly peopleRepository: PeopleRepository,
  ) {}

  async accountProfile(user: RequestUser) {
    const profile = await this.peopleRepository.findAccountProfile(user);
    if (!profile) {
      throw new NotFoundException(
        "No existe un perfil personal para esta cuenta.",
      );
    }
    return {
      ...profile,
      birthDate: profile.birthDate?.toISOString().slice(0, 10) ?? null,
    };
  }

  async updateAccountProfile(
    user: RequestUser,
    input: UpdateAccountProfileDto,
  ) {
    await this.peopleRepository.updateAccountProfile(user, input);
    return this.accountProfile(user);
  }
  async resource(user: RequestUser, resource: PeopleResource) {
    return { items: await this.peopleRepository.resource(user, resource) };
  }
}
