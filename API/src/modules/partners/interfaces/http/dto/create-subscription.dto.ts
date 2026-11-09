import { IsBoolean, IsOptional, IsUUID } from "class-validator";

export class CreateSubscriptionDto {
  @IsUUID() partnerId!: string;
  @IsUUID() planId!: string;
  @IsUUID() payerUserId!: string;
  @IsOptional() @IsBoolean() autoRenew?: boolean;
}
