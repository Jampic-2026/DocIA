import { Storage } from "@google-cloud/storage";
import { Injectable, BadRequestException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { createReadStream } from "node:fs";
import { mkdir, stat, unlink, writeFile } from "node:fs/promises";
import { basename, extname, resolve, sep } from "node:path";
import { switchMime } from "../../domain/file-storage-persistence-types";
import { ObjectStorage } from "../../domain/ports/object-storage";
@Injectable()
export class ConfiguredObjectStorage implements ObjectStorage {
  private readonly root: string;
  private readonly provider: "local" | "gcs";
  private readonly gcs?: Storage;
  private readonly bucketName?: string;
  constructor(config: ConfigService) {
    this.provider = config.get<"local" | "gcs">("storage.provider", "local");
    this.root = resolve(config.get<string>("STORAGE_ROOT", "storage"));
    this.bucketName = config.get<string>("storage.gcsBucketName");
    if (this.provider === "gcs") this.gcs = new Storage();
  }
  assertInsideRoot(target: string) {
    if (target !== this.root && !target.startsWith(`${this.root}${sep}`))
      throw new BadRequestException("Ruta de almacenamiento inválida.");
  }
  async writeObject(
    key: string,
    contents: Buffer,
    mimeType: string,
    originalName: string,
  ) {
    if (this.provider === "gcs") {
      await this.gcsBucket()
        .file(key)
        .save(contents, {
          contentType: mimeType,
          resumable: false,
          metadata: {
            cacheControl: "private, max-age=300",
            metadata: { originalName: basename(originalName).slice(0, 255) },
          },
        });
      return;
    }
    const directory = resolve(this.root, key.split("/")[0]);
    this.assertInsideRoot(directory);
    await mkdir(directory, { recursive: true });
    const target = resolve(this.root, key);
    this.assertInsideRoot(target);
    await writeFile(target, contents, { flag: "wx" });
  }
  async objectInfo(key: string) {
    if (this.provider === "gcs") {
      const [metadata] = await this.gcsBucket().file(key).getMetadata();
      return {
        size: Number(metadata.size ?? 0),
        mimeType:
          typeof metadata.contentType === "string"
            ? metadata.contentType
            : undefined,
      };
    }
    const target = resolve(this.root, key);
    this.assertInsideRoot(target);
    const info = await stat(target);
    return { size: info.size, mimeType: this.mimeType(target) };
  }
  createObjectReadStream(key: string) {
    if (this.provider === "gcs")
      return this.gcsBucket().file(key).createReadStream();
    const target = resolve(this.root, key);
    this.assertInsideRoot(target);
    return createReadStream(target);
  }
  async deleteObject(key: string) {
    if (this.provider === "gcs") {
      await this.gcsBucket().file(key).delete({ ignoreNotFound: true });
      return;
    }
    const target = resolve(this.root, key);
    this.assertInsideRoot(target);
    await unlink(target).catch(() => undefined);
  }
  gcsBucket() {
    if (!this.gcs || !this.bucketName) {
      throw new BadRequestException(
        "Google Cloud Storage no está configurado.",
      );
    }
    return this.gcs.bucket(this.bucketName);
  }
  mimeType(path: string) {
    return switchMime(extname(path).toLowerCase());
  }
}
