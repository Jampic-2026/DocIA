export const personnelRoles = [
  "doctor_general",
  "doctor_specialist",
  "nurse",
  "operator",
  "clinical_supervisor",
  "delivery_assistant",
  "human_resources",
] as const;

export type VerificationDocument = {
  document_type: string;
  status: string;
  valid_until?: string | Date | null;
};

/** Deterministic checks shared by both approval paths; no implied requirements. */
export function approvalProblems(
  requiredTypes: string[] | undefined,
  documents: VerificationDocument[],
  today: string,
): string[] {
  if (!requiredTypes?.length)
    return ["Define los documentos obligatorios del rol antes de aprobar."];
  const problems: string[] = [];
  if (
    !documents.length ||
    documents.some((document) => document.status !== "approved")
  ) {
    problems.push("Todos los documentos presentados deben estar aprobados.");
  }
  for (const type of requiredTypes) {
    const matching = documents.filter(
      (document) =>
        document.document_type === type && document.status === "approved",
    );
    if (
      !matching.some(
        (document) =>
          !document.valid_until ||
          (document.valid_until instanceof Date
            ? document.valid_until.toISOString().slice(0, 10)
            : document.valid_until.slice(0, 10)) >= today,
      )
    ) {
      problems.push(`Falta un documento aprobado y vigente: ${type}.`);
    }
  }
  return problems;
}
