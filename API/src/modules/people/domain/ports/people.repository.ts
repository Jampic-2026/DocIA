import { RequestUser } from "../../../../common/types/request-user";
import { AccountProfile } from "../account-profile";

export const PEOPLE_REPOSITORY = Symbol("PEOPLE_REPOSITORY");
export type PeopleResource = "persons" | "addresses";

export type UpdateAccountProfile = {
  firstName?: string;
  lastName?: string;
  secondLastName?: string;
  phone?: string;
  municipality?: string;
  zone?: string;
  addressLine?: string;
  reference?: string;
};

export interface PeopleRepository {
  findAccountProfile(user: RequestUser): Promise<AccountProfile | null>;
  updateAccountProfile(
    user: RequestUser,
    input: UpdateAccountProfile,
  ): Promise<void>;
  resource(user: RequestUser, resource: PeopleResource): Promise<unknown[]>;
}
