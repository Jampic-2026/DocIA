import { IsUUID } from "class-validator";
export class ShareTelemedicineFileDto {
  @IsUUID() clinicalDocumentId!: string;
}
