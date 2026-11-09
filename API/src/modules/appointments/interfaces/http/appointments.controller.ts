import { Body, Controller, Get, Param, Patch, Post } from "@nestjs/common";
import { PermissionCodes } from "../../../../common/auth/permission-codes";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { Permissions } from "../../../../common/decorators/permissions.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { AppointmentsService } from "../../application/appointments.service";
import { TelemedicineService } from "../../application/telemedicine.service";
import { CreateAppointmentDto } from "./dto/create-appointment.dto";
import { CancelAppointmentDto } from "./dto/cancel-appointment.dto";
import { RescheduleAppointmentDto } from "./dto/reschedule-appointment.dto";
import { CreateAppointmentRatingDto } from "./dto/create-appointment-rating.dto";
import { CreateReferralDto } from "./dto/create-referral.dto";
import { ShareTelemedicineFileDto } from "./dto/share-telemedicine-file.dto";
import { NoShowDto } from "./dto/no-show.dto";

@Permissions(PermissionCodes.appointmentsRead)
@Controller("appointments")
export class AppointmentsController {
  @Patch("appointments/:appointmentId/no-show")
  @Permissions(PermissionCodes.clinicalRecordsManage)
  noShow(
    @CurrentUser() user: RequestUser,
    @Param("appointmentId") id: string,
    @Body() input: NoShowDto,
  ) {
    return this.appointmentsService.markNoShow(user, id, input.reason);
  }
  constructor(
    private readonly appointmentsService: AppointmentsService,
    private readonly telemedicineService: TelemedicineService,
  ) {}

  @Get("referrals")
  referrals(@CurrentUser() user: RequestUser) {
    return this.appointmentsService.careActions(user);
  }

  @Post("referrals")
  @Permissions(PermissionCodes.appointmentsManage)
  createReferral(
    @CurrentUser() user: RequestUser,
    @Body() input: CreateReferralDto,
  ) {
    return this.appointmentsService.createReferral(user, input);
  }

  @Get("appointments")
  appointments(@CurrentUser() user: RequestUser) {
    return this.appointmentsService.listForUser(user);
  }

  @Post("appointments")
  @Permissions(PermissionCodes.appointmentsManage)
  createAppointment(
    @CurrentUser() user: RequestUser,
    @Body() input: CreateAppointmentDto,
  ) {
    return this.appointmentsService.create(user, input);
  }

  @Patch("appointments/:appointmentId/cancel")
  @Permissions(PermissionCodes.appointmentsManage)
  cancelAppointment(
    @CurrentUser() user: RequestUser,
    @Param("appointmentId") appointmentId: string,
    @Body() input: CancelAppointmentDto,
  ) {
    return this.appointmentsService.cancel(user, appointmentId, input.reason);
  }

  @Patch("appointments/:appointmentId/reschedule")
  @Permissions(PermissionCodes.appointmentsManage)
  rescheduleAppointment(
    @CurrentUser() user: RequestUser,
    @Param("appointmentId") appointmentId: string,
    @Body() input: RescheduleAppointmentDto,
  ) {
    return this.appointmentsService.reschedule(user, appointmentId, input);
  }

  @Get("appointment-status-history")
  appointmentStatusHistory(@CurrentUser() user: RequestUser) {
    return this.appointmentsService.resource(
      user,
      "appointment_status_history",
    );
  }

  @Get("appointment-followups")
  appointmentFollowups(@CurrentUser() user: RequestUser) {
    return this.appointmentsService.careActions(user);
  }

  @Get("telemedicine-rooms")
  telemedicineRooms(@CurrentUser() user: RequestUser) {
    return this.telemedicineService.listRooms(user);
  }

  @Post("appointments/:appointmentId/telemedicine-room")
  @Permissions(PermissionCodes.appointmentsManage)
  createTelemedicineRoom(
    @CurrentUser() user: RequestUser,
    @Param("appointmentId") appointmentId: string,
  ) {
    return this.telemedicineService.createRoom(user, appointmentId);
  }

  @Post("telemedicine-rooms/:roomId/join")
  registerTelemedicineJoin(
    @CurrentUser() user: RequestUser,
    @Param("roomId") roomId: string,
  ) {
    return this.telemedicineService.registerJoin(user, roomId);
  }

  @Get("telemedicine-rooms/:roomId/activity")
  telemedicineActivity(
    @CurrentUser() user: RequestUser,
    @Param("roomId") roomId: string,
  ) {
    return this.telemedicineService.activity(user, roomId);
  }
  @Post("telemedicine-rooms/:roomId/leave")
  telemedicineLeave(
    @CurrentUser() user: RequestUser,
    @Param("roomId") roomId: string,
  ) {
    return this.telemedicineService.registerLeave(user, roomId);
  }
  @Post("telemedicine-rooms/:roomId/close")
  @Permissions(PermissionCodes.appointmentsManage)
  telemedicineClose(
    @CurrentUser() user: RequestUser,
    @Param("roomId") roomId: string,
  ) {
    return this.telemedicineService.closeRoom(user, roomId);
  }
  @Post("telemedicine-rooms/:roomId/connection-failure")
  telemedicineConnectionFailure(
    @CurrentUser() user: RequestUser,
    @Param("roomId") roomId: string,
  ) {
    return this.telemedicineService.registerConnectionFailure(user, roomId);
  }
  @Post("telemedicine-rooms/:roomId/files")
  telemedicineShareFile(
    @CurrentUser() user: RequestUser,
    @Param("roomId") roomId: string,
    @Body() input: ShareTelemedicineFileDto,
  ) {
    return this.telemedicineService.shareFile(
      user,
      roomId,
      input.clinicalDocumentId,
    );
  }

  @Get("clinical-notes")
  clinicalNotes(@CurrentUser() user: RequestUser) {
    return this.appointmentsService.resource(user, "clinical_notes");
  }

  @Get("diagnoses")
  diagnoses(@CurrentUser() user: RequestUser) {
    return this.appointmentsService.resource(user, "diagnoses");
  }

  @Get("treatments")
  treatments(@CurrentUser() user: RequestUser) {
    return this.appointmentsService.resource(user, "treatments");
  }

  @Get("appointment-ratings")
  appointmentRatings(@CurrentUser() user: RequestUser) {
    return this.appointmentsService.careActions(user);
  }

  @Post("appointments/:appointmentId/rating")
  @Permissions(PermissionCodes.appointmentsManage)
  rateAppointment(
    @CurrentUser() user: RequestUser,
    @Param("appointmentId") appointmentId: string,
    @Body() input: CreateAppointmentRatingDto,
  ) {
    return this.appointmentsService.rate(user, appointmentId, input);
  }
}
