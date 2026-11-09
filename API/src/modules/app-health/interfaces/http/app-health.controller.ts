import { Controller, Get, ServiceUnavailableException } from "@nestjs/common";
import { Public } from "../../../../common/decorators/public.decorator";
import { DatabaseService } from "../../../../database/database.service";

@Public()
@Controller("health")
export class AppHealthController {
  constructor(private readonly database: DatabaseService) {}

  @Get()
  check() {
    return {
      status: "ok",
      service: "api-docia",
      timestamp: new Date().toISOString(),
    };
  }

  @Get("ready")
  async ready() {
    try {
      await this.database.checkHealth();
    } catch {
      // Never return connection strings, driver messages or database credentials.
      throw new ServiceUnavailableException("Servicio no disponible");
    }

    return {
      status: "ok",
      service: "api-docia",
      release: process.env.DOCIA_RELEASE ?? "development",
    };
  }
}
