import { OBJECT_STORAGE, ObjectStorage } from "../domain/ports/object-storage";
import type { MultipartFile } from "@fastify/multipart";

import {
  BadRequestException,
  Injectable,
  Inject as InjectRepository,
  NotFoundException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { createHmac, randomUUID, timingSafeEqual } from "node:crypto";

import { basename, extname } from "node:path";
import { RequestUser } from "../../../common/types/request-user";
import {
  allowedCategories,
  allowedExtensions,
  allowedMimeTypes,
} from "../domain/file-storage-persistence-types";
import {
  FILE_STORAGE_REPOSITORY,
  FileStorageRepository,
} from "../domain/ports/file-storage.repository";

@Injectable()
export class FileStorageService {
  constructor(
    private readonly config: ConfigService,
    @InjectRepository(FILE_STORAGE_REPOSITORY)
    private readonly repository: FileStorageRepository,
    @InjectRepository(OBJECT_STORAGE) private readonly storage: ObjectStorage,
  ) {}

  async save(user: RequestUser, file: MultipartFile, categoryValue?: string) {
    const fileType = this.resolveFileType(file);
    if (!fileType)
      throw new BadRequestException("El tipo de archivo no está permitido.");
    const category = categoryValue?.trim().toLowerCase().replace(/-/g, "_");
    if (!category || !allowedCategories.has(category)) {
      throw new BadRequestException("La categoría del archivo no es válida.");
    }
    this.assertUploadPermission(user, category);
    const contents = await file.toBuffer();
    if (file.file.truncated) {
      throw new BadRequestException("El archivo supera el tamaño permitido.");
    }
    if (!this.matchesFileSignature(contents, fileType.mimeType)) {
      throw new BadRequestException(
        "El contenido del archivo no coincide con el tipo declarado.",
      );
    }
    const key = `${category}/${randomUUID()}${fileType.extension}`;
    try {
      const saved = await this.repository.saveFileMetadata(
        user,
        contents,
        key,
        fileType,
        file,
        category,
        this.storage.writeObject.bind(this.storage),
        this.storage.objectInfo.bind(this.storage),
      );
      const baseUrl = this.config
        .get<string>("PUBLIC_API_URL", "http://localhost:3000")
        .replace(/\/$/, "");
      const prefix = this.config.get<string>("API_PREFIX", "api/v1");
      return {
        key,
        fileName: basename(file.filename).slice(0, 255),
        mimeType: fileType.mimeType,
        size: saved.size,
        fileUrl: `${baseUrl}/${prefix}/files/${key}`,
      };
    } catch (error) {
      await this.storage.deleteObject(key);
      throw error;
    }
  }

  async open(key: string) {
    if (!/^[a-z][a-z0-9_-]{1,39}\/[0-9a-f-]{36}\.[a-z0-9]+$/.test(key)) {
      throw new NotFoundException("Archivo no encontrado.");
    }
    try {
      const info = await this.storage.objectInfo(key);
      return {
        stream: this.storage.createObjectReadStream(key),
        size: info.size,
        mimeType: info.mimeType ?? this.storage.mimeType(key),
      };
    } catch {
      throw new NotFoundException("Archivo no encontrado.");
    }
  }

  accessUrl(key: string) {
    this.validateKey(key);
    const expiresAt =
      Math.floor(Date.now() / 1000) +
      this.config.get<number>("storage.signedUrlExpiresSeconds", 300);
    const signature = this.signature(key, expiresAt);
    const baseUrl = this.config
      .get<string>("PUBLIC_API_URL", "http://localhost:3000")
      .replace(/\/$/, "");
    const prefix = this.config.get<string>("API_PREFIX", "api/v1");
    return {
      url: `${baseUrl}/${prefix}/files/${key}?expires=${expiresAt}&signature=${signature}`,
      expiresAt: new Date(expiresAt * 1000).toISOString(),
    };
  }

  async accessUrlForUser(user: RequestUser, key: string) {
    this.validateKey(key);
    const suffix = `%/files/${key}`;
    const keySuffix = `%${key}`;
    const allowed = await this.repository.authorizeFileRead(
      suffix,
      keySuffix,
      user,
      key,
      this.hasPermission.bind(this),
    );
    if (!allowed.rowCount) {
      throw new NotFoundException("No tienes acceso a este archivo.");
    }
    const result = this.accessUrl(key);
    const entityId = key.split("/")[1]?.split(".")[0] ?? "unknown";
    await this.repository.logFileRead(user, entityId, key, result);
    return result;
  }
  assertAccess(key: string, expires: number, signature: string) {
    this.validateKey(key);
    if (!Number.isInteger(expires) || expires < Math.floor(Date.now() / 1000))
      throw new NotFoundException("El enlace venció.");
    const expected = this.signature(key, expires);
    const left = Buffer.from(signature, "hex"),
      right = Buffer.from(expected, "hex");
    if (left.length !== right.length || !timingSafeEqual(left, right))
      throw new NotFoundException("Enlace inválido.");
  }

  private validateKey(key: string) {
    if (!/^[a-z0-9_-]{1,40}\/[a-zA-Z0-9_.-]{1,100}$/.test(key))
      throw new NotFoundException("Archivo no encontrado.");
  }
  private signature(key: string, expires: number) {
    return createHmac(
      "sha256",
      this.config.getOrThrow<string>("storage.signingSecret"),
    )
      .update(`${key}:${expires}`)
      .digest("hex");
  }

  private resolveFileType(file: MultipartFile) {
    const mimeExtension = allowedMimeTypes.get(file.mimetype);
    if (mimeExtension) {
      return { extension: mimeExtension, mimeType: file.mimetype };
    }
    const originalExtension = extname(file.filename).toLowerCase();
    const mimeType = allowedExtensions.get(originalExtension);
    if (!mimeType) return null;
    return {
      extension: originalExtension === ".jpeg" ? ".jpg" : originalExtension,
      mimeType,
    };
  }

  private assertUploadPermission(user: RequestUser, category: string) {
    const allowed =
      category === "personnel_documents" ||
      (category === "clinical_documents" &&
        (this.hasPermission(user, "patients.manage") ||
          this.hasPermission(user, "clinical_records.manage"))) ||
      // Pending/rejected professionals must be able to submit new credentials.
      // Linking and reading uploads still enforce ownership in their commands.
      category === "professional_documents" ||
      (category === "partner_documents" &&
        this.hasPermission(user, "partners.manage")) ||
      (category === "payment_qr" &&
        (this.hasPermission(user, "payments.manage") ||
          this.hasPermission(user, "coins.manage"))) ||
      (category === "payment_receipts" &&
        this.hasPermission(user, "payments.read")) ||
      (category === "service_evidence" &&
        this.hasPermission(user, "home_services.manage")) ||
      (category === "delivery_evidence" &&
        this.hasPermission(user, "deliveries.manage"));
    if (!allowed) {
      throw new NotFoundException(
        "No tienes permiso para subir este tipo de archivo.",
      );
    }
  }

  private matchesFileSignature(contents: Buffer, mimeType: string) {
    if (contents.length === 0) return false;
    if (mimeType === "application/pdf")
      return contents.subarray(0, 5).toString() === "%PDF-";
    if (mimeType === "image/jpeg")
      return (
        contents[0] === 0xff && contents[1] === 0xd8 && contents[2] === 0xff
      );
    if (mimeType === "image/png")
      return contents
        .subarray(0, 8)
        .equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
    if (mimeType === "image/webp")
      return (
        contents.subarray(0, 4).toString() === "RIFF" &&
        contents.subarray(8, 12).toString() === "WEBP"
      );
    if (mimeType === "text/plain") {
      if (contents.includes(0)) return false;
      try {
        new TextDecoder("utf-8", { fatal: true }).decode(contents);
        return true;
      } catch {
        return false;
      }
    }
    return false;
  }

  private hasPermission(user: RequestUser, permission: string) {
    return user.permissions.includes(permission);
  }
}
