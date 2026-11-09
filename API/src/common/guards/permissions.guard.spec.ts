import { ExecutionContext } from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { PermissionsGuard } from "./permissions.guard";

describe("PermissionsGuard", () => {
  const reflector = {
    getAllAndOverride: jest.fn(),
  } as unknown as Reflector;

  const guard = new PermissionsGuard(reflector);

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it("allows endpoints without required permissions", () => {
    jest
      .spyOn(reflector, "getAllAndOverride")
      .mockReturnValueOnce(false)
      .mockReturnValueOnce(undefined);
    expect(guard.canActivate(contextWithPermissions([]))).toBe(true);
  });

  it("allows public endpoints even when the controller requires permissions", () => {
    jest.spyOn(reflector, "getAllAndOverride").mockReturnValueOnce(true);

    expect(guard.canActivate(contextWithPermissions([]))).toBe(true);
  });

  it("allows a user with every required permission", () => {
    jest
      .spyOn(reflector, "getAllAndOverride")
      .mockReturnValueOnce(false)
      .mockReturnValueOnce(["appointments.read", "patients.read"]);

    expect(
      guard.canActivate(
        contextWithPermissions(["appointments.read", "patients.read"]),
      ),
    ).toBe(true);
  });

  it("denies a user missing a required permission", () => {
    jest
      .spyOn(reflector, "getAllAndOverride")
      .mockReturnValueOnce(false)
      .mockReturnValueOnce(["administration.read"]);

    expect(
      guard.canActivate(contextWithPermissions(["appointments.read"])),
    ).toBe(false);
  });
});

function contextWithPermissions(permissions: string[]) {
  return {
    getHandler: () => function handler() {},
    getClass: () => class Controller {},
    switchToHttp: () => ({
      getRequest: () => ({ user: { permissions } }),
    }),
  } as unknown as ExecutionContext;
}
