import { Module } from "@nestjs/common";
import { UsersService } from "./application/users.service";
import { USERS_REPOSITORY } from "./domain/ports/users.repository";
import { PostgresUsersRepository } from "./infrastructure/persistence/postgres-users.repository";
import { UsersController } from "./interfaces/http/users.controller";
@Module({
  controllers: [UsersController],
  providers: [
    UsersService,
    { provide: USERS_REPOSITORY, useClass: PostgresUsersRepository },
  ],
  exports: [UsersService],
})
export class UsersModule {}
