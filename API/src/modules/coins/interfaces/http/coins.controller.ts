import {
  Body,
  Controller,
  Delete,
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
import { CoinsService } from "../../application/coins.service";
import {
  PurchaseCoinPackageDto,
  UpsertCoinPackageDto,
} from "./dto/coin-package.dto";

@Permissions(PermissionCodes.coinsRead)
@Controller("coins")
export class CoinsController {
  constructor(private readonly service: CoinsService) {}
  @Get("overview") overview(@CurrentUser() user: RequestUser) {
    return this.service.overview(user);
  }
  @Get("coin-packages") async coinPackages(@CurrentUser() user: RequestUser) {
    return { items: (await this.service.overview(user)).packages };
  }
  @Get("coin-wallets") async coinWallets(@CurrentUser() user: RequestUser) {
    const value = await this.service.overview(user);
    return {
      items: [
        {
          availableBalance: value.availableBalance,
          reservedBalance: value.reservedBalance,
          lifetimeCredited: value.lifetimeCredited,
          lifetimeSpent: value.lifetimeSpent,
        },
      ],
    };
  }
  @Get("coin-purchases") purchases(@CurrentUser() user: RequestUser) {
    return this.service.resource(user, "coin-purchases");
  }
  @Get("coin-lots") lots(@CurrentUser() user: RequestUser) {
    return this.service.resource(user, "coin-lots");
  }
  @Get("coin-transactions") async transactions(
    @CurrentUser() user: RequestUser,
  ) {
    return { items: (await this.service.overview(user)).transactions };
  }
  @Get("coin-transaction-allocations") allocations(
    @CurrentUser() user: RequestUser,
  ) {
    return this.service.resource(user, "coin-transaction-allocations");
  }
  @Post("purchases") purchase(
    @CurrentUser() user: RequestUser,
    @Body() input: PurchaseCoinPackageDto,
  ) {
    return this.service.purchase(user, input.packageId);
  }
  @Post("coin-packages")
  @Permissions(PermissionCodes.coinsManage)
  createPackage(
    @CurrentUser() user: RequestUser,
    @Body() input: UpsertCoinPackageDto,
  ) {
    return this.service.createPackage(user, input);
  }
  @Post("maintenance/process-expirations")
  @Permissions(PermissionCodes.coinsManage)
  processMaintenance(@CurrentUser() user: RequestUser) {
    return this.service.processMaintenance(user);
  }
  @Patch("coin-packages/:id")
  @Permissions(PermissionCodes.coinsManage)
  updatePackage(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: UpsertCoinPackageDto,
  ) {
    return this.service.updatePackage(user, id, input);
  }
  @Delete("coin-packages/:id")
  @Permissions(PermissionCodes.coinsManage)
  deletePackage(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.service.deletePackage(user, id);
  }
}
