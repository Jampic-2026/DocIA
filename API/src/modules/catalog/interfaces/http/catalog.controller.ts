import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { CatalogService } from "../../application/catalog.service";
import { CreatePriceDto } from "./dto/create-price.dto";
import { ClosePriceDto } from "./dto/close-price.dto";
import { UpsertServiceDto } from "./dto/upsert-service.dto";

@Permissions(PermissionCodes.catalogRead)
@Controller("catalog")
export class CatalogController {
  constructor(private readonly service: CatalogService) {}

  @Get("service-catalog")
  serviceCatalog(@CurrentUser() user: RequestUser) {
    return this.service.list(user);
  }

  @Get("price-list")
  priceList(@CurrentUser() user: RequestUser) {
    return this.service.prices(user);
  }
  @Get("management")
  @Permissions(PermissionCodes.catalogManage)
  management(@CurrentUser() user: RequestUser) {
    return this.service.management(user);
  }

  @Post("price-list")
  @Permissions(PermissionCodes.catalogManage)
  createPrice(@CurrentUser() user: RequestUser, @Body() input: CreatePriceDto) {
    return this.service.createPrice(user, input);
  }
  @Post("service-catalog")
  @Permissions(PermissionCodes.catalogManage)
  createService(
    @CurrentUser() user: RequestUser,
    @Body() input: UpsertServiceDto,
  ) {
    return this.service.createService(user, input);
  }
  @Patch("service-catalog/:id")
  @Permissions(PermissionCodes.catalogManage)
  updateService(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: UpsertServiceDto,
  ) {
    return this.service.updateService(user, id, input);
  }
  @Patch("price-list/:id/validity")
  @Permissions(PermissionCodes.catalogManage)
  closePrice(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: ClosePriceDto,
  ) {
    return this.service.closePrice(user, id, input.validUntil);
  }
}
