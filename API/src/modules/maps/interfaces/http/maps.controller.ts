import { Body, Controller, Post } from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { ConsentsService } from "../../../consents/application/consents.service";
import { MapsService } from "../../application/maps.service";
import { LocationPreviewDto } from "./dto/location-preview.dto";

@Controller("maps")
export class MapsController {
  constructor(
    private readonly service: MapsService,
    private readonly consents: ConsentsService,
  ) {}

  @Post("location-preview")
  @Permissions(PermissionCodes.emergenciesManage)
  async locationPreview(
    @CurrentUser() user: RequestUser,
    @Body() input: LocationPreviewDto,
  ) {
    await this.consents.assertAccepted(user, "geolocation");
    return this.service.locationPreview(user, input.latitude, input.longitude);
  }
}
