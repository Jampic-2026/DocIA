import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { HomeServicesService } from "../../application/home-services.service";
import {
  AssignHomeServiceDto,
  CreateHomeServiceDto,
  CreateHomeServiceRatingDto,
  CreateServiceEvidenceDto,
  CreateServiceLocationDto,
  UpdateHomeServiceStatusDto,
} from "./dto/home-service.dto";

@Permissions(PermissionCodes.homeServicesRead)
@Controller("home-services")
export class HomeServicesController {
  constructor(private readonly service: HomeServicesService) {}
  @Get("home-service-requests") list(@CurrentUser() user: RequestUser) {
    return this.service.list(user);
  }
  @Post("home-service-requests")
  @Permissions(PermissionCodes.homeServicesManage)
  create(
    @CurrentUser() user: RequestUser,
    @Body() input: CreateHomeServiceDto,
  ) {
    return this.service.create(user, input);
  }
  @Patch("home-service-requests/:id/assignment")
  @Permissions(PermissionCodes.homeServicesManage)
  assign(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: AssignHomeServiceDto,
  ) {
    return this.service.assign(user, id, input);
  }
  @Patch("home-service-requests/:id/status")
  @Permissions(PermissionCodes.homeServicesManage)
  status(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: UpdateHomeServiceStatusDto,
  ) {
    return this.service.updateStatus(user, id, input);
  }
  @Get("service-status-history") history(
    @CurrentUser() user: RequestUser,
    @Query("homeServiceId") id?: string,
  ) {
    return this.service.history(user, id);
  }
  @Get("realtime-locations") locations(
    @CurrentUser() user: RequestUser,
    @Query("homeServiceId") id?: string,
  ) {
    return this.service.locations(user, id);
  }
  @Post("home-service-requests/:id/locations")
  @Permissions(PermissionCodes.homeServicesManage)
  location(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: CreateServiceLocationDto,
  ) {
    return this.service.addLocation(user, id, input);
  }
  @Get("service-evidence") evidence(
    @CurrentUser() user: RequestUser,
    @Query("homeServiceId") id?: string,
  ) {
    return this.service.evidence(user, id);
  }
  @Post("home-service-requests/:id/evidence")
  @Permissions(PermissionCodes.homeServicesManage)
  addEvidence(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: CreateServiceEvidenceDto,
  ) {
    return this.service.addEvidence(user, id, input);
  }
  @Get("home-service-ratings") ratings(
    @CurrentUser() user: RequestUser,
    @Query("homeServiceId") id?: string,
  ) {
    return this.service.ratings(user, id);
  }
  @Post("home-service-requests/:id/rating")
  @Permissions(PermissionCodes.homeServicesManage)
  rate(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: CreateHomeServiceRatingDto,
  ) {
    return this.service.rate(user, id, input);
  }
}
