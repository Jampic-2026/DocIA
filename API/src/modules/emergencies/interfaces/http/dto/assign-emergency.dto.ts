import { IsOptional, IsUUID } from "class-validator";

export class AssignEmergencyDto {
  @IsOptional()
  @IsUUID()
  professionalId?: string;

  @IsOptional()
  @IsUUID()
  operatorId?: string;
}
