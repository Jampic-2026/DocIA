import {
  Body,
  Controller,
  Delete,
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
import { ProfessionalsService } from "../../application/professionals.service";
import { CreateAvailabilityDto } from "./dto/create-availability.dto";
import { CreateTimeBlockDto } from "./dto/create-time-block.dto";
import { UpdateProfessionalProfileDto } from "./dto/update-professional-profile.dto";
import { CreateProfessionalDocumentDto } from "./dto/create-professional-document.dto";
import {
  SaveWorkShiftDto,
  ShiftQueryDto,
  StaffAvailabilityQueryDto,
} from "./dto/work-shift.dto";

@Permissions(PermissionCodes.professionalsRead)
@Controller("professionals")
export class ProfessionalsController {
  constructor(private readonly professionalsService: ProfessionalsService) {}

  @Get("specialties")
  specialties(@CurrentUser() user: RequestUser) {
    return this.professionalsService.resource(user, "specialties");
  }

  @Get("professionals")
  professionals(@CurrentUser() user: RequestUser) {
    return this.professionalsService.listDirectory(user);
  }

  @Get("professional-specialties")
  professionalSpecialties(@CurrentUser() user: RequestUser) {
    return this.professionalsService.resource(user, "professional_specialties");
  }

  @Get("professional-documents")
  professionalDocuments(@CurrentUser() user: RequestUser) {
    return this.professionalsService.ownProfile(user);
  }

  @Get("me")
  @Permissions()
  ownProfile(@CurrentUser() user: RequestUser) {
    return this.professionalsService.ownProfile(user);
  }

  @Patch("me")
  @Permissions()
  updateOwnProfile(
    @CurrentUser() user: RequestUser,
    @Body() input: UpdateProfessionalProfileDto,
  ) {
    return this.professionalsService.updateOwnProfile(user, input);
  }

  @Post("me/documents")
  @Permissions()
  createOwnDocument(
    @CurrentUser() user: RequestUser,
    @Body() input: CreateProfessionalDocumentDto,
  ) {
    return this.professionalsService.createOwnDocument(user, input);
  }

  @Get("schedule")
  schedule(@CurrentUser() user: RequestUser) {
    return this.professionalsService.ownSchedule(user);
  }

  @Post("professional-availability")
  createAvailability(
    @CurrentUser() user: RequestUser,
    @Body() input: CreateAvailabilityDto,
  ) {
    return this.professionalsService.createAvailability(user, input);
  }

  @Delete("professional-availability/:id")
  removeAvailability(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.professionalsService.removeAvailability(user, id);
  }

  @Post("professional-time-blocks")
  createTimeBlock(
    @CurrentUser() user: RequestUser,
    @Body() input: CreateTimeBlockDto,
  ) {
    return this.professionalsService.createTimeBlock(user, input);
  }

  @Delete("professional-time-blocks/:id")
  removeTimeBlock(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.professionalsService.removeTimeBlock(user, id);
  }

  @Get("work-shifts")
  workShifts(@CurrentUser() user: RequestUser, @Query() query: ShiftQueryDto) {
    return this.professionalsService.shifts(user, query);
  }

  @Post("work-shifts")
  @Permissions(PermissionCodes.humanResourcesManage)
  createShift(
    @CurrentUser() user: RequestUser,
    @Body() input: SaveWorkShiftDto,
  ) {
    return this.professionalsService.saveShift(user, input);
  }
  @Patch("work-shifts/:id")
  @Permissions(PermissionCodes.humanResourcesManage)
  updateShift(
    @CurrentUser() user: RequestUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() input: SaveWorkShiftDto,
  ) {
    return this.professionalsService.saveShift(user, input, id);
  }
  @Get("available-staff")
  @Permissions(PermissionCodes.humanResourcesRead)
  availableStaff(
    @CurrentUser() user: RequestUser,
    @Query() query: StaffAvailabilityQueryDto,
  ) {
    return this.professionalsService.availableStaff(user, query);
  }

  @Get("work-shift-history")
  workShiftHistory(@CurrentUser() user: RequestUser) {
    return this.professionalsService.resource(user, "work_shift_history");
  }
}
