import { Body, Controller, Get, Param, Patch, Post } from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { IncidentsService } from "../../application/incidents.service";
import { CreateIncidentDto } from "./dto/create-incident.dto";

@Permissions(PermissionCodes.incidentsRead)
@Controller("incidents")
export class IncidentsController {
  constructor(private readonly service: IncidentsService) {}

  @Get()
  list(@CurrentUser() user: RequestUser) {
    return this.service.list(user);
  }

  @Post()
  create(@CurrentUser() user: RequestUser, @Body() input: CreateIncidentDto) {
    return this.service.create(user, input);
  }

  @Patch(":id/close")
  close(@CurrentUser() user: RequestUser, @Param("id") id: string) {
    return this.service.close(user, id);
  }
}
