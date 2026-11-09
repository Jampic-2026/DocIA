import { evaluateRisk, isRiskPolicy, RiskPolicy } from "./risk-policy";
const policy: RiskPolicy = {
  rules: [
    {
      code: "synthetic_yellow",
      terms: ["synthetic symptom"],
      antecedentTerms: ["synthetic antecedent"],
      riskLevel: "yellow",
      action: "appointment",
      questions: ["Synthetic question?"],
    },
    {
      code: "synthetic_red",
      terms: ["synthetic urgent"],
      antecedentTerms: [],
      riskLevel: "red",
      action: "emergency",
      questions: [],
    },
  ],
};
describe("Configurable risk policy, synthetic criteria only", () => {
  it("keeps classification disabled even when text matches a configured rule", () => {
    expect(evaluateRisk(policy, false, "synthetic urgent", "").riskLevel).toBe(
      "undetermined",
    );
  });
  it("requires matching antecedents and preserves requests for additional information", () => {
    expect(evaluateRisk(policy, true, "synthetic symptom", "").riskLevel).toBe(
      "undetermined",
    );
    expect(
      evaluateRisk(policy, true, "SYNTHETIC SYMPTOM", "synthetic antecedent"),
    ).toEqual(
      expect.objectContaining({
        riskLevel: "yellow",
        recommendedAction: "appointment",
        questions: ["Synthetic question?"],
      }),
    );
  });
  it("chooses the highest matched level without treating unmatched input as low risk", () => {
    expect(
      evaluateRisk(
        policy,
        true,
        "synthetic symptom and synthetic urgent",
        "synthetic antecedent",
      ).riskLevel,
    ).toBe("red");
    expect(
      evaluateRisk(policy, true, "unmatched", "").classificationStatus,
    ).toBe("unclassified");
  });
  it("rejects duplicate criteria, empty terms, and red rules that defer emergency attention", () => {
    expect(isRiskPolicy(policy)).toBe(true);
    expect(isRiskPolicy({ rules: [policy.rules[0], policy.rules[0]] })).toBe(
      false,
    );
    expect(
      isRiskPolicy({ rules: [{ ...policy.rules[1], action: "appointment" }] }),
    ).toBe(false);
    expect(isRiskPolicy({ rules: [{ ...policy.rules[0], terms: [] }] })).toBe(
      false,
    );
    expect(isRiskPolicy(null)).toBe(false);
  });
});
