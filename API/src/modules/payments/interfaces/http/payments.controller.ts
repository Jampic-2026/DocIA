import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Headers,
  Req,
} from "@nestjs/common";
import { FastifyRequest } from "fastify";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { Public } from "../../../../common/decorators/public.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { PaymentsService } from "../../application/payments.service";
import {
  AcceptPaymentOrderDto,
  CreateStripePaymentIntentDto,
  CreatePaymentOrderDto,
  ConfirmInPersonPaymentDto,
  RegisterInPersonPaymentDto,
  ReportPaymentIncidentDto,
  ResolvePaymentIncidentDto,
  ReviewPaymentDto,
  SubmitPaymentDto,
} from "./dto/payment-commands.dto";

@Permissions(PermissionCodes.paymentsRead)
@Controller("payments")
export class PaymentsController {
  constructor(private readonly service: PaymentsService) {}

  @Get("orders")
  orders(@CurrentUser() user: RequestUser) {
    return this.service.orders(user);
  }

  @Get("history")
  history(@CurrentUser() user: RequestUser) {
    return this.service.history(user);
  }

  @Post("orders")
  createOrder(
    @CurrentUser() user: RequestUser,
    @Body() input: CreatePaymentOrderDto,
  ) {
    return this.service.createOrder(user, input);
  }

  @Patch("orders/:orderId/acceptance")
  acceptOrder(
    @CurrentUser() user: RequestUser,
    @Param("orderId", ParseUUIDPipe) orderId: string,
    @Body() input: AcceptPaymentOrderDto,
  ) {
    return this.service.acceptOrder(user, orderId, input);
  }

  @Get("configuration")
  configuration(@CurrentUser() user: RequestUser) {
    return this.service.configuration(user);
  }

  @Post("orders/:orderId/payments")
  submit(
    @CurrentUser() user: RequestUser,
    @Param("orderId", ParseUUIDPipe) orderId: string,
    @Body() input: SubmitPaymentDto,
  ) {
    return this.service.submit(user, orderId, input);
  }

  @Post("orders/:orderId/stripe/payment-intent")
  createStripePaymentIntent(
    @CurrentUser() user: RequestUser,
    @Param("orderId", ParseUUIDPipe) orderId: string,
    @Body() input: CreateStripePaymentIntentDto,
  ) {
    return this.service.createStripePaymentIntent(user, orderId, input);
  }

  @Post("orders/:orderId/stripe/checkout-session")
  createStripeCheckoutSession(
    @CurrentUser() user: RequestUser,
    @Param("orderId", ParseUUIDPipe) orderId: string,
    @Body() input: CreateStripePaymentIntentDto,
  ) {
    return this.service.createStripeCheckoutSession(user, orderId, input);
  }

  @Post("stripe/checkout-sessions/:sessionId/sync")
  syncStripeCheckoutSession(
    @CurrentUser() user: RequestUser,
    @Param("sessionId") sessionId: string,
  ) {
    return this.service.syncStripeCheckoutSession(user, sessionId);
  }

  @Post("stripe/payment-intents/:paymentIntentId/sync")
  syncStripePaymentIntent(
    @CurrentUser() user: RequestUser,
    @Param("paymentIntentId") paymentIntentId: string,
  ) {
    return this.service.syncStripePaymentIntent(user, paymentIntentId);
  }

  @Post("stripe/webhook")
  @Public()
  stripeWebhook(
    @Headers("stripe-signature") signature: string | undefined,
    @Req() request: FastifyRequest & { rawBody?: string },
  ) {
    return this.service.handleStripeWebhook(signature, request.rawBody ?? "");
  }

  @Get("review-queue")
  @Permissions(PermissionCodes.paymentsManage)
  reviewQueue(@CurrentUser() user: RequestUser) {
    return this.service.reviewQueue(user);
  }

  @Post("orders/:orderId/in-person-payment")
  registerInPerson(
    @CurrentUser() user: RequestUser,
    @Param("orderId", ParseUUIDPipe) orderId: string,
    @Body() input: RegisterInPersonPaymentDto,
  ) {
    return this.service.registerInPerson(user, orderId, input);
  }

  @Patch(":paymentId/in-person-confirmation")
  confirmInPerson(
    @CurrentUser() user: RequestUser,
    @Param("paymentId", ParseUUIDPipe) paymentId: string,
    @Body() input: ConfirmInPersonPaymentDto,
  ) {
    return this.service.confirmInPerson(user, paymentId, input);
  }

  @Patch(":paymentId/review")
  @Permissions(PermissionCodes.paymentsManage)
  review(
    @CurrentUser() user: RequestUser,
    @Param("paymentId", ParseUUIDPipe) paymentId: string,
    @Body() input: ReviewPaymentDto,
  ) {
    return this.service.review(user, paymentId, input);
  }

  @Get("incidents")
  incidents(@CurrentUser() user: RequestUser) {
    return this.service.incidents(user);
  }

  @Post(":paymentId/incidents")
  reportIncident(
    @CurrentUser() user: RequestUser,
    @Param("paymentId", ParseUUIDPipe) paymentId: string,
    @Body() input: ReportPaymentIncidentDto,
  ) {
    return this.service.reportIncident(user, paymentId, input);
  }

  @Patch("incidents/:incidentId/resolve")
  @Permissions(PermissionCodes.paymentsManage)
  resolveIncident(
    @CurrentUser() user: RequestUser,
    @Param("incidentId", ParseUUIDPipe) incidentId: string,
    @Body() input: ResolvePaymentIncidentDto,
  ) {
    return this.service.resolveIncident(user, incidentId, input);
  }

  @Patch("incidents/:incidentId/review")
  @Permissions(PermissionCodes.paymentsManage)
  startIncidentReview(
    @CurrentUser() user: RequestUser,
    @Param("incidentId", ParseUUIDPipe) incidentId: string,
  ) {
    return this.service.startIncidentReview(user, incidentId);
  }

  @Get("refunds")
  refunds(@CurrentUser() user: RequestUser) {
    return this.service.refunds(user);
  }
}
