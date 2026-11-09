import { Readable } from "node:stream";
export const OBJECT_STORAGE = Symbol("OBJECT_STORAGE");
export interface ObjectStorage {
  writeObject(
    key: string,
    contents: Buffer,
    mimeType: string,
    originalName: string,
  ): Promise<void>;
  objectInfo(
    key: string,
  ): Promise<{ size: number; mimeType: string | undefined }>;
  createObjectReadStream(key: string): Readable;
  deleteObject(key: string): Promise<void>;
  mimeType(path: string): string;
}
