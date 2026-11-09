import { Type } from "class-transformer";
import {
  ArrayMaxSize,
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsIn,
  IsISO8601,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from "class-validator";
import {
  completionFields,
  CompletionField,
} from "../../../domain/profile-completion";
class CompletionRuleDto {
  @IsIn(completionFields) field!: CompletionField;
  @IsString() @MinLength(2) @MaxLength(100) label!: string;
  @IsIn(["patient", "professional"]) actor!: "patient" | "professional";
}
export class CompletionPolicyDto {
  @IsArray()
  @ArrayMaxSize(30)
  @ArrayUnique((rule: CompletionRuleDto) => rule.field)
  @ValidateNested({ each: true })
  @Type(() => CompletionRuleDto)
  rules!: CompletionRuleDto[];
  @IsBoolean() rewardEnabled!: boolean;
  @IsOptional() @IsUUID() benefitId?: string;
  @IsOptional() @IsString() @MinLength(3) @MaxLength(80) campaignId?: string;
  @IsOptional() @IsNumber() @Min(1) @Max(100) threshold?: number;
  @IsOptional() @IsISO8601() validUntil?: string;
}
