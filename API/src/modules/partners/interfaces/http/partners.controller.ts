import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
} from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { PartnersService } from "../../application/partners.service";
import { PartnerResource } from "../../domain/ports/partners.repository";
import { UpsertSubscriptionPlanDto } from "./dto/upsert-subscription-plan.dto";
import { CreateSubscriptionDto } from "./dto/create-subscription.dto";
import {
  CancelSubscriptionDto,
  RecordSubscriptionUsageDto,
  RenewSubscriptionDto,
  SetPlanBenefitDto,
} from "./dto/plan-operations.dto";
import {
  AddPartnerDocumentDto,
  AssignPartnerUserDto,
  CompleteDiagnosticOrderDto,
  CreateDiagnosticOrderDto,
  CreatePartnerRequestDto,
  RespondPartnerRequestDto,
  ReviewPartnerDocumentDto,
  UpsertPartnerDto,
} from "./dto/partner-workflows.dto";

@Permissions(PermissionCodes.partnersRead)
@Controller("partners")
export class PartnersController {
  constructor(private readonly service: PartnersService) {}
  @Get("health-partners") healthPartners(@CurrentUser() u: RequestUser) {
    return this.service.list(u);
  }
  @Post("health-partners")
  @Permissions(PermissionCodes.partnersManage)
  createPartner(
    @CurrentUser() u: RequestUser,
    @Body() input: UpsertPartnerDto,
  ) {
    return this.service.createPartner(u, input);
  }
  @Patch("health-partners/:id")
  @Permissions(PermissionCodes.partnersManage)
  updatePartner(
    @CurrentUser() u: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: UpsertPartnerDto,
  ) {
    return this.service.updatePartner(u, id, input);
  }
  @Post("health-partners/:id/documents")
  @Permissions(PermissionCodes.partnersManage)
  addDocument(
    @CurrentUser() u: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: AddPartnerDocumentDto,
  ) {
    return this.service.addDocument(u, id, input);
  }
  @Patch("partner-documents/:id/review")
  @Permissions(PermissionCodes.partnersManage)
  reviewDocument(
    @CurrentUser() u: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: ReviewPartnerDocumentDto,
  ) {
    return this.service.reviewDocument(u, id, input);
  }
  @Put("health-partners/:id/users")
  @Permissions(PermissionCodes.partnersManage)
  assignUser(
    @CurrentUser() u: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: AssignPartnerUserDto,
  ) {
    return this.service.assignUser(u, id, input);
  }
  private resource(u: RequestUser, r: PartnerResource) {
    return this.service.resource(u, r);
  }
  @Get("partner-subscription-plans") plans(@CurrentUser() u: RequestUser) {
    return this.resource(u, "partner_subscription_plans");
  }
  @Post("partner-subscription-plans")
  @Permissions(PermissionCodes.partnersManage)
  createPlan(
    @CurrentUser() u: RequestUser,
    @Body() input: UpsertSubscriptionPlanDto,
  ) {
    return this.service.createPlan(u, input);
  }
  @Patch("partner-subscription-plans/:id")
  @Permissions(PermissionCodes.partnersManage)
  updatePlan(
    @CurrentUser() u: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: UpsertSubscriptionPlanDto,
  ) {
    return this.service.updatePlan(u, id, input);
  }
  @Get("partner-plan-benefits") planBenefits(@CurrentUser() u: RequestUser) {
    return this.resource(u, "partner_plan_benefits");
  }
  @Get("partner-subscriptions") subscriptions(@CurrentUser() u: RequestUser) {
    return this.resource(u, "partner_subscriptions");
  }
  @Post("partner-subscriptions")
  @Permissions(PermissionCodes.partnersManage)
  createSubscription(
    @CurrentUser() u: RequestUser,
    @Body() input: CreateSubscriptionDto,
  ) {
    return this.service.createSubscription(u, input);
  }
  @Put("partner-subscription-plans/:planId/benefits")
  @Permissions(PermissionCodes.partnersManage)
  setPlanBenefit(
    @CurrentUser() u: RequestUser,
    @Param("planId", ParseUUIDPipe) planId: string,
    @Body() input: SetPlanBenefitDto,
  ) {
    return this.service.setPlanBenefit(u, planId, input);
  }
  @Delete("partner-subscription-plans/:planId/benefits/:benefitId")
  @Permissions(PermissionCodes.partnersManage)
  removePlanBenefit(
    @CurrentUser() u: RequestUser,
    @Param("planId", ParseUUIDPipe) planId: string,
    @Param("benefitId", ParseUUIDPipe) benefitId: string,
  ) {
    return this.service.removePlanBenefit(u, planId, benefitId);
  }
  @Patch("partner-subscriptions/:id/cancel")
  @Permissions(PermissionCodes.partnersManage)
  cancelSubscription(
    @CurrentUser() u: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: CancelSubscriptionDto,
  ) {
    return this.service.cancelSubscription(u, id, input.reason);
  }
  @Post("partner-subscriptions/:id/renew")
  @Permissions(PermissionCodes.partnersManage)
  renewSubscription(
    @CurrentUser() u: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: RenewSubscriptionDto,
  ) {
    return this.service.renewSubscription(u, id, input);
  }
  @Post("partner-subscriptions/:id/usage")
  @Permissions(PermissionCodes.partnersManage)
  recordUsage(
    @CurrentUser() u: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: RecordSubscriptionUsageDto,
  ) {
    return this.service.recordUsage(u, id, input);
  }
  @Post("maintenance/process-subscriptions")
  @Permissions(PermissionCodes.partnersManage)
  processLifecycle(@CurrentUser() u: RequestUser) {
    return this.service.processSubscriptionLifecycle(u);
  }
  @Get("partner-subscription-usage") usage(@CurrentUser() u: RequestUser) {
    return this.resource(u, "partner_subscription_usage");
  }
  @Get("partner-users") users(@CurrentUser() u: RequestUser) {
    return this.resource(u, "partner_users");
  }
  @Get("partner-documents") documents(@CurrentUser() u: RequestUser) {
    return this.resource(u, "partner_documents");
  }
  @Get("operating-sites") sites(@CurrentUser() u: RequestUser) {
    return this.resource(u, "operating_sites");
  }
  @Get("coverage-zones") zones(@CurrentUser() u: RequestUser) {
    return this.resource(u, "coverage_zones");
  }
  @Get("partner-catalog-items") catalog(@CurrentUser() u: RequestUser) {
    return this.resource(u, "partner_catalog_items");
  }
  @Get("partner-requests") requests(@CurrentUser() u: RequestUser) {
    return this.resource(u, "partner_requests");
  }
  @Post("partner-requests")
  createRequest(
    @CurrentUser() u: RequestUser,
    @Body() input: CreatePartnerRequestDto,
  ) {
    return this.service.createRequest(u, input);
  }
  @Post("partner-requests/:id/confirm")
  confirmRequest(
    @CurrentUser() u: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.service.confirmRequest(u, id);
  }
  @Patch("partner-requests/:id/respond")
  @Permissions(PermissionCodes.partnersManage)
  respondRequest(
    @CurrentUser() u: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: RespondPartnerRequestDto,
  ) {
    return this.service.respondRequest(u, id, input);
  }
  @Get("partner-request-items") requestItems(@CurrentUser() u: RequestUser) {
    return this.resource(u, "partner_request_items");
  }
  @Get("diagnostic-orders")
  @Permissions(PermissionCodes.clinicalRecordsRead)
  orders(@CurrentUser() u: RequestUser) {
    return this.resource(u, "diagnostic_orders");
  }
  @Post("diagnostic-orders")
  @Permissions(PermissionCodes.clinicalRecordsManage)
  createDiagnosticOrder(
    @CurrentUser() u: RequestUser,
    @Body() input: CreateDiagnosticOrderDto,
  ) {
    return this.service.createDiagnosticOrder(u, input);
  }
  @Post("diagnostic-orders/:id/result")
  @Permissions(PermissionCodes.partnersManage)
  completeDiagnosticOrder(
    @CurrentUser() u: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: CompleteDiagnosticOrderDto,
  ) {
    return this.service.completeDiagnosticOrder(u, id, input);
  }
}
