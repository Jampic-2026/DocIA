import { IsString, IsUrl, MaxLength } from "class-validator";

export class CreateProfessionalDocumentDto {
  @IsString()
  @MaxLength(80)
  documentType!: string;

  @IsUrl({ require_protocol: true })
  fileUrl!: string;
}
