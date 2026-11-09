import { Module } from "@nestjs/common";
import { AppHealthController } from "./interfaces/http/app-health.controller";

@Module({
  controllers: [AppHealthController],
})
export class AppHealthModule {}
