import { approvalProblems } from "./professional-verification-policy";

describe("professional approval requirements", () => {
  const today = "2026-10-10";
  it("blocks approvals before the role requirements are defined", () => {
    expect(
      approvalProblems(
        undefined,
        [{ document_type: "custom", status: "approved" }],
        today,
      ),
    ).not.toEqual([]);
    expect(approvalProblems([], [], today)).not.toEqual([]);
  });
  it("requires every configured type; an arbitrary approved document is insufficient", () => {
    expect(
      approvalProblems(
        ["title", "license"],
        [{ document_type: "license", status: "approved" }],
        today,
      ),
    ).toEqual(["Falta un documento aprobado y vigente: title."]);
  });
  it("never silently approves pending or rejected uploads", () => {
    expect(
      approvalProblems(
        ["title"],
        [{ document_type: "title", status: "pending" }],
        today,
      ),
    ).toHaveLength(2);
    expect(
      approvalProblems(
        ["title"],
        [{ document_type: "title", status: "rejected" }],
        today,
      ),
    ).toHaveLength(2);
  });
  it("rejects expired required credentials and accepts a current replacement", () => {
    const expired = {
      document_type: "license",
      status: "approved",
      valid_until: "2026-10-09",
    };
    expect(approvalProblems(["license"], [expired], today)).toHaveLength(1);
    expect(
      approvalProblems(
        ["license"],
        [
          expired,
          { ...expired, valid_until: new Date("2026-10-10T00:00:00Z") },
        ],
        today,
      ),
    ).toEqual([]);
  });
  it("accepts a complete approved set without inventing an expiration date", () => {
    expect(
      approvalProblems(
        ["custom credential"],
        [
          {
            document_type: "custom credential",
            status: "approved",
            valid_until: null,
          },
        ],
        today,
      ),
    ).toEqual([]);
  });
});
