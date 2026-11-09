import { RequestUser } from "../../../../common/types/request-user";
import { MeetProvider } from "../../../integrations/domain/ports/meet-provider";
export const TELEMEDICINE_REPOSITORY = Symbol("TELEMEDICINE_REPOSITORY");
export interface TelemedicineRepository {
  claimRoomJobs(): Promise<
    Array<{ appointmentId: string; requestedBy: string }>
  >;
  completeRoomJob(appointmentId: string): Promise<void>;
  failRoomJob(appointmentId: string): Promise<void>;
  closeRoom(
    roomId: string,
    user: RequestUser,
    meet: MeetProvider,
  ): Promise<{ closed: boolean; durationSeconds: number }>;
  listRooms(user: RequestUser): Promise<{ items: any[] }>;
  createRoom(
    appointmentId: string,
    user: RequestUser,
    meetCallback: MeetProvider,
  ): Promise<any>;
  registerJoin(
    roomId: string,
    user: RequestUser,
  ): Promise<{ registered: boolean }>;
  activity(
    roomId: string,
    user: RequestUser,
  ): Promise<{ participants: any[]; events: any[]; files: any[] }>;
  registerLeave(
    roomId: string,
    user: RequestUser,
  ): Promise<{ registered: boolean }>;
  registerConnectionFailure(
    roomId: string,
    user: RequestUser,
  ): Promise<{ registered: boolean }>;
  shareFile(
    roomId: string,
    user: RequestUser,
    clinicalDocumentId: string,
  ): Promise<{ shared: boolean }>;
}
