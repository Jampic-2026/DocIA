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
import { DeliveriesService } from "../../application/deliveries.service";
import {
  AssignDeliveryDto,
  CreateDeliveryDto,
  CreateDeliveryEvidenceDto,
  UpdateDeliveryStatusDto,
} from "./dto/delivery.dto";
@Permissions(PermissionCodes.deliveriesRead)
@Controller("deliveries")
export class DeliveriesController {
  constructor(private readonly service: DeliveriesService) {}
  @Get("deliveries") list(@CurrentUser() u: RequestUser) {
    return this.service.list(u);
  }
  @Post("deliveries") @Permissions(PermissionCodes.deliveriesManage) create(
    @CurrentUser() u: RequestUser,
    @Body() i: CreateDeliveryDto,
  ) {
    return this.service.create(u, i);
  }
  @Patch("deliveries/:id/assignment")
  @Permissions(PermissionCodes.deliveriesManage)
  assign(
    @CurrentUser() u: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() i: AssignDeliveryDto,
  ) {
    return this.service.assign(u, id, i);
  }
  @Patch("deliveries/:id/status")
  @Permissions(PermissionCodes.deliveriesManage)
  status(
    @CurrentUser() u: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() i: UpdateDeliveryStatusDto,
  ) {
    return this.service.status(u, id, i);
  }
  @Get("delivery-status-history") history(
    @CurrentUser() u: RequestUser,
    @Query("deliveryId") id?: string,
  ) {
    return this.service.history(u, id);
  }
  @Get("delivery-evidence") evidence(
    @CurrentUser() u: RequestUser,
    @Query("deliveryId") id?: string,
  ) {
    return this.service.evidence(u, id);
  }
  @Post("deliveries/:id/evidence")
  @Permissions(PermissionCodes.deliveriesManage)
  addEvidence(
    @CurrentUser() u: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() i: CreateDeliveryEvidenceDto,
  ) {
    return this.service.addEvidence(u, id, i);
  }
}
