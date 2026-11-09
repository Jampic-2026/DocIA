import { Controller, Get } from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { PeopleService } from "../../application/people.service";
import { Body, Patch } from "@nestjs/common";
import { UpdateAccountProfileDto } from "./dto/update-account-profile.dto";

@Controller("people")
export class PeopleController {
  constructor(private readonly peopleService: PeopleService) {}

  @Get("me")
  me(@CurrentUser() user: RequestUser) {
    return this.peopleService.accountProfile(user);
  }

  @Patch("me")
  updateMe(
    @CurrentUser() user: RequestUser,
    @Body() input: UpdateAccountProfileDto,
  ) {
    return this.peopleService.updateAccountProfile(user, input);
  }

  @Permissions(PermissionCodes.peopleRead)
  @Get("persons")
  persons(@CurrentUser() user: RequestUser) {
    return this.peopleService.resource(user, "persons");
  }

  @Permissions(PermissionCodes.peopleRead)
  @Get("addresses")
  addresses(@CurrentUser() user: RequestUser) {
    return this.peopleService.resource(user, "addresses");
  }
}
