import {
  IsBoolean,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
} from "class-validator";

export class CreateClinicalDocumentDto {
  @IsString()
  @MaxLength(80)
  documentType!: string;

  @IsUrl({ require_protocol: true })
  @MaxLength(2000)
  fileUrl!: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  fileName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  mimeType?: string;

  @IsOptional()
  @IsBoolean()
  isRestricted?: boolean;
}
