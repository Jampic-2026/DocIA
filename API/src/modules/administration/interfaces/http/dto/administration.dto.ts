import {
  ArrayMaxSize,
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsDateString,
  IsLatitude,
  IsLongitude,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  MinLength,
} from "class-validator";

export class UpsertRoleDto {
  [key: string]: unknown;

  @IsString() @Matches(/^[a-z][a-z0-9_]{1,59}$/) code!: string;
  @IsString() @MinLength(2) @MaxLength(120) name!: string;
  @IsOptional() @IsString() @MaxLength(1000) description?: string;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

export class AssignPermissionsDto {
  [key: string]: unknown;

  @IsArray()
  @ArrayUnique()
  @ArrayMaxSize(200)
  @IsString({ each: true })
  permissionCodes!: string[];

  @IsString() @MinLength(3) @MaxLength(1000) reason!: string;
}

export class UpsertOperatingSiteDto {
  [key: string]: unknown;

  @IsOptional() @IsUUID() partnerId?: string;
  @IsString() @Matches(/^[A-Z0-9][A-Z0-9_-]{1,79}$/) code!: string;
  @IsString() @MinLength(2) @MaxLength(180) name!: string;
  @IsString() @MinLength(2) @MaxLength(60) siteType!: string;
  @IsOptional() @IsString() @MaxLength(1000) address?: string;
  @IsOptional() @IsLatitude() latitude?: number;
  @IsOptional() @IsLongitude() longitude?: number;
  @IsOptional() @IsString() @MaxLength(40) phone?: string;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

export class UpsertBusinessRuleDto {
  [key: string]: unknown;

  @IsString() @Matches(/^[a-z][a-z0-9_.-]{2,119}$/) code!: string;
  @IsString() @MinLength(2) @MaxLength(80) domain!: string;
  @IsString() @MinLength(2) @MaxLength(180) name!: string;
  @IsObject() configuration!: Record<string, unknown>;
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsOptional() @IsBoolean() requiresClinicalApproval?: boolean;
  @IsOptional() @IsUUID() approvedByProfessionalId?: string;
  @IsOptional() @IsDateString() validFrom?: string;
  @IsOptional() @IsDateString() validUntil?: string;
  @IsString() @MinLength(3) @MaxLength(1000) reason!: string;
}
