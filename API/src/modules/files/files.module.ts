import { OBJECT_STORAGE } from "./domain/ports/object-storage";
import { ConfiguredObjectStorage } from "./infrastructure/object-storage/configured-object-storage";
import { Module } from "@nestjs/common";
import { FileStorageService } from "./application/file-storage.service";
import { FILE_STORAGE_REPOSITORY } from "./domain/ports/file-storage.repository";
import { PostgresFileStorageRepository } from "./infrastructure/persistence/postgres-file-storage.repository";
import { FilesController } from "./interfaces/http/files.controller";
@Module({
  controllers: [FilesController],
  providers: [
    { provide: OBJECT_STORAGE, useClass: ConfiguredObjectStorage },
    {
      provide: FILE_STORAGE_REPOSITORY,
      useClass: PostgresFileStorageRepository,
    },
    FileStorageService,
  ],
  exports: [FileStorageService],
})
export class FilesModule {}
