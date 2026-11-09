import { Module } from "@nestjs/common";
import { CatalogService } from "./application/catalog.service";
import { CatalogController } from "./interfaces/http/catalog.controller";
import { CATALOG_REPOSITORY } from "./domain/ports/catalog.repository";
import { PostgresCatalogRepository } from "./infrastructure/persistence/postgres-catalog.repository";

@Module({
  controllers: [CatalogController],
  providers: [
    CatalogService,
    { provide: CATALOG_REPOSITORY, useClass: PostgresCatalogRepository },
  ],
  exports: [CatalogService],
})
export class CatalogModule {}
