import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  Res,
} from "@nestjs/common";
import type { FastifyReply, FastifyRequest } from "fastify";
import { FileStorageService } from "../../application/file-storage.service";
import { Public } from "../../../../common/decorators/public.decorator";
import { FileAccessDto } from "./file-access.dto";
import { CurrentUser } from "../../../../common/decorators/current-user.decorator";
import { RequestUser } from "../../../../common/types/request-user";
import { Throttle } from "@nestjs/throttler";

@Controller("files")
export class FilesController {
  constructor(private readonly storage: FileStorageService) {}

  @Post()
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  async upload(
    @CurrentUser() user: RequestUser,
    @Req() request: FastifyRequest,
  ) {
    const file = await request.file();
    if (!file) throw new BadRequestException("No se recibió ningún archivo.");
    const rawCategory = file.fields.category;
    const categoryField = Array.isArray(rawCategory)
      ? rawCategory[0]
      : rawCategory;
    const category =
      categoryField?.type === "field" && typeof categoryField.value === "string"
        ? categoryField.value
        : undefined;
    return this.storage.save(user, file, category);
  }

  @Get(":category/:fileName")
  @Public()
  async download(
    @Param("category") category: string,
    @Param("fileName") fileName: string,
    @Query("expires") expiresValue: string,
    @Query("signature") signature: string,
    @Res() reply: FastifyReply,
  ) {
    const key = `${category}/${fileName}`;
    this.storage.assertAccess(key, Number(expiresValue), signature);
    const file = await this.storage.open(key);
    return reply
      .type(file.mimeType)
      .header("Content-Length", file.size)
      .header("Cache-Control", "private, max-age=300")
      .header("X-Content-Type-Options", "nosniff")
      .header("Content-Disposition", `inline; filename="${fileName}"`)
      .send(file.stream);
  }

  @Post("access")
  access(@CurrentUser() user: RequestUser, @Body() input: FileAccessDto) {
    return this.storage.accessUrlForUser(user, input.key);
  }
}
