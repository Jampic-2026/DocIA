import { RequestUser } from "../../../common/types/request-user";
import { AppointmentsRepository } from "../domain/ports/appointments.repository";
import { AppointmentsService } from "./appointments.service";

describe("AppointmentsService", () => {
  it("returns the stable HTTP projection for authorized appointments", async () => {
    const repository: AppointmentsRepository = {
      markNoShow: jest.fn(),
      create: jest.fn(),
      cancel: jest.fn(),
      reschedule: jest.fn(),
      participantUserIds: jest.fn(),
      listCareActions: jest.fn(),
      rate: jest.fn(),
      createReferral: jest.fn(),
      resource: jest.fn(),
      listForUser: jest.fn().mockResolvedValue([
        {
          id: "appointment-id",
          patientId: "patient-id",
          patientName: "Paciente Prueba",
          professionalId: "professional-id",
          professionalName: "Profesional Prueba",
          specialty: "Medicina General",
          modality: "telemedicine",
          status: "confirmed",
          startAt: new Date("2026-07-23T14:00:00.000Z"),
          endAt: new Date("2026-07-23T14:30:00.000Z"),
          reason: "Control",
        },
      ]),
    };
    const notifications = { notifyUser: jest.fn() };
    const service = new AppointmentsService(repository, notifications as never);

    const result = await service.listForUser(user);

    expect(repository.listForUser).toHaveBeenCalledWith(user);
    expect(result.items[0]).toEqual(
      expect.objectContaining({
        id: "appointment-id",
        startAt: "2026-07-23T14:00:00.000Z",
        modality: "telemedicine",
      }),
    );
  });
});

const user: RequestUser = {
  id: "user-id",
  sessionId: "session-id",
  email: "patient@jampic.local",
  roleCode: "patient",
  roles: ["patient"],
  permissions: ["appointments.read"],
};
