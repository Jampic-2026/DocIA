export const allowedMimeTypes = new Map([
  ["application/pdf", ".pdf"],
  ["image/jpeg", ".jpg"],
  ["image/png", ".png"],
  ["image/webp", ".webp"],
  ["text/plain", ".txt"],
]);
export const allowedExtensions = new Map([
  [".pdf", "application/pdf"],
  [".jpg", "image/jpeg"],
  [".jpeg", "image/jpeg"],
  [".png", "image/png"],
  [".webp", "image/webp"],
  [".txt", "text/plain"],
]);
export const allowedCategories = new Set([
  "clinical_documents",
  "professional_documents",
  "personnel_documents",
  "partner_documents",
  "payment_qr",
  "payment_receipts",
  "service_evidence",
  "delivery_evidence",
]);
export function switchMime(extension: string) {
  switch (extension) {
    case ".pdf":
      return "application/pdf";
    case ".jpg":
      return "image/jpeg";
    case ".png":
      return "image/png";
    case ".webp":
      return "image/webp";
    default:
      return "text/plain";
  }
}
