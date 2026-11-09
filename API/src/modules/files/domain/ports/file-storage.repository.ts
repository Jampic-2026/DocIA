import type { MultipartFile } from "@fastify/multipart";
import { RequestUser } from "../../../../common/types/request-user";
export const FILE_STORAGE_REPOSITORY = Symbol("FILE_STORAGE_REPOSITORY");
export interface FileStorageRepository {
  saveFileMetadata(
    user: RequestUser,
    contents: Buffer<ArrayBufferLike>,
    key: string,
    fileType: { extension: string; mimeType: string },
    file: MultipartFile,
    category: string,
    writeObjectCallback: (
      key: string,
      contents: Buffer,
      mimeType: string,
      originalName: string,
    ) => Promise<void>,
    objectInfoCallback: (
      key: string,
    ) => Promise<{ size: number; mimeType: string | undefined }>,
  ): Promise<{ size: number; mimeType: string | undefined }>;
  authorizeFileRead(
    suffix: string,
    keySuffix: string,
    user: RequestUser,
    key: string,
    hasPermissionCallback: (user: RequestUser, permission: string) => boolean,
  ): Promise<{ rowCount: number | null }>;
  logFileRead(
    user: RequestUser,
    entityId: string,
    key: string,
    result: { url: string; expiresAt: string },
  ): Promise<void>;
}
