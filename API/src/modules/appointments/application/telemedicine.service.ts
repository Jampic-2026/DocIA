import {
  Inject,
  Injectable,
  Inject as InjectRepository,
  OnModuleInit,
  OnModuleDestroy,
  Logger,
} from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import { ConsentsService } from "../../consents/application/consents.service";
import {
  MEET_PROVIDER,
  MeetProvider,
} from "../../integrations/domain/ports/meet-provider";
import {
  TELEMEDICINE_REPOSITORY,
  TelemedicineRepository,
} from "../domain/ports/telemedicine.repository";

@Injectable()
export class TelemedicineService implements OnModuleInit, OnModuleDestroy {
  private timer?: ReturnType<typeof setInterval>;
  private processing = false;
  onModuleInit() {
    this.timer = setInterval(() => void this.processRoomJobs(), 30000);
    this.timer.unref();
  }
  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }
  async processRoomJobs() {
    if (this.processing) return;
    this.processing = true;
    try {
      for (const job of await this.repository.claimRoomJobs()) {
        try {
          await this.createRoom(
            {
              id: job.requestedBy,
              sessionId: "",
              email: "",
              roleCode: "system",
              roles: ["admin"],
              permissions: [],
            },
            job.appointmentId,
          );
          await this.repository.completeRoomJob(job.appointmentId);
        } catch {
          await this.repository.failRoomJob(job.appointmentId);
          new Logger(TelemedicineService.name).warn(
            "Preparación de sala pendiente de reintento; no se expone información del paciente.",
          );
        }
      }
    } catch {
      new Logger(TelemedicineService.name).warn(
        "No se pudo procesar la cola de salas.",
      );
    } finally {
      this.processing = false;
    }
  }
  async closeRoom(user: RequestUser, roomId: string) {
    return this.repository.closeRoom(roomId, user, this.meet);
  }
  constructor(
    @InjectRepository(TELEMEDICINE_REPOSITORY)
    private readonly repository: TelemedicineRepository,
    private readonly consents: ConsentsService,
    @Inject(MEET_PROVIDER) private readonly meet: MeetProvider,
  ) {}

  async listRooms(user: RequestUser) {
    return this.repository.listRooms(user);
  }

  async createRoom(user: RequestUser, appointmentId: string) {
    return this.repository.createRoom(appointmentId, user, this.meet);
  }

  async registerJoin(user: RequestUser, roomId: string) {
    if (user.roles.includes("patient")) {
      await this.consents.assertAccepted(user, "telemedicine");
    }
    return this.repository.registerJoin(roomId, user);
  }

  async activity(user: RequestUser, roomId: string) {
    return this.repository.activity(roomId, user);
  }

  async registerLeave(user: RequestUser, roomId: string) {
    return this.repository.registerLeave(roomId, user);
  }

  async registerConnectionFailure(user: RequestUser, roomId: string) {
    return this.repository.registerConnectionFailure(roomId, user);
  }

  async shareFile(
    user: RequestUser,
    roomId: string,
    clinicalDocumentId: string,
  ) {
    return this.repository.shareFile(roomId, user, clinicalDocumentId);
  }
}
