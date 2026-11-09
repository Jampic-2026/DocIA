import { Module } from "@nestjs/common";
import { PeopleService } from "./application/people.service";
import { PeopleController } from "./interfaces/http/people.controller";
import { PEOPLE_REPOSITORY } from "./domain/ports/people.repository";
import { PostgresPeopleRepository } from "./infrastructure/persistence/postgres-people.repository";

@Module({
  controllers: [PeopleController],
  providers: [
    PeopleService,
    {
      provide: PEOPLE_REPOSITORY,
      useClass: PostgresPeopleRepository,
    },
  ],
  exports: [PeopleService],
})
export class PeopleModule {}
