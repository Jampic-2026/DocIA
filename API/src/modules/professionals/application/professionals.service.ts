import { Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import {
  SaveWorkShift,
  ShiftQuery,
  StaffAvailabilityQuery,
} from "../domain/work-shift";
import {
  PROFESSIONALS_REPOSITORY,
  ProfessionalResource,
  ProfessionalsRepository,
} from "../domain/ports/professionals.repository";

@Injectable()
export class ProfessionalsService {
  constructor(
    @Inject(PROFESSIONALS_REPOSITORY)
    private readonly professionalsRepository: ProfessionalsRepository,
  ) {}

  async shifts(user: RequestUser, query: ShiftQuery) {
    return {
      items: await this.professionalsRepository.listShifts(user, query),
    };
  }
  saveShift(user: RequestUser, input: SaveWorkShift, id?: string) {
    return this.professionalsRepository.saveShift(user, input, id);
  }
  async availableStaff(user: RequestUser, query: StaffAvailabilityQuery) {
    return {
      items: await this.professionalsRepository.availableStaff(user, query),
    };
  }

  async listDirectory(user: RequestUser) {
    return { items: await this.professionalsRepository.listDirectory(user) };
  }

  async ownSchedule(user: RequestUser) {
    const schedule = await this.professionalsRepository.getOwnSchedule(user);
    return {
      availability: schedule.availability,
      timeBlocks: schedule.timeBlocks.map((block) => ({
        ...block,
        startAt: block.startAt.toISOString(),
        endAt: block.endAt.toISOString(),
      })),
    };
  }

  async createAvailability(
    user: RequestUser,
    input: {
      weekday: number;
      startTime: string;
      endTime: string;
      modality: "telemedicine" | "home_visit" | "in_person";
    },
  ) {
    await this.professionalsRepository.createAvailability(user, input);
    return { created: true };
  }

  async removeAvailability(user: RequestUser, id: string) {
    await this.professionalsRepository.removeAvailability(user, id);
    return { removed: true };
  }

  async createTimeBlock(
    user: RequestUser,
    input: {
      startAt: string;
      endAt: string;
      reason?: string;
    },
  ) {
    await this.professionalsRepository.createTimeBlock(user, {
      startAt: new Date(input.startAt),
      endAt: new Date(input.endAt),
      reason: input.reason,
    });
    return { created: true };
  }

  async removeTimeBlock(user: RequestUser, id: string) {
    await this.professionalsRepository.removeTimeBlock(user, id);
    return { removed: true };
  }

  async ownProfile(user: RequestUser) {
    const profile = await this.professionalsRepository.getOwnProfile(user);
    return {
      ...profile,
      documents: profile.documents.map((document) => ({
        ...document,
        createdAt: document.createdAt.toISOString(),
      })),
    };
  }

  async updateOwnProfile(
    user: RequestUser,
    input: {
      licenseNumber?: string;
      specialtyId?: string;
      bio?: string;
      yearsExperience?: number;
      publicProfileEnabled?: boolean;
    },
  ) {
    await this.professionalsRepository.updateOwnProfile(user, input);
    return { updated: true };
  }

  async createOwnDocument(
    user: RequestUser,
    input: { documentType: string; fileUrl: string },
  ) {
    await this.professionalsRepository.createOwnDocument(user, input);
    return { created: true };
  }
  async resource(user: RequestUser, resource: ProfessionalResource) {
    return {
      items: await this.professionalsRepository.resource(user, resource),
    };
  }
}
