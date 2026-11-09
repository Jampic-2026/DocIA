import { IsString, Matches } from "class-validator";
export class FileAccessDto {
  @IsString()
  @Matches(/^[a-z][a-z0-9_-]{1,39}\/[0-9a-f-]{36}\.[a-z0-9]+$/)
  key!: string;
}
