export type RiskRule = {
  code: string;
  terms: string[];
  antecedentTerms: string[];
  riskLevel: "green" | "yellow" | "red";
  action: "emergency" | "appointment" | "call_operator";
  questions: string[];
};
export type RiskPolicy = { rules: RiskRule[] };
export type RiskEvaluation = {
  riskLevel: "green" | "yellow" | "red" | "undetermined";
  recommendedAction: "emergency" | "appointment" | "call_operator" | null;
  classificationStatus:
    | "clinically_validated_rules"
    | "disabled"
    | "unclassified"
    | "preventive_alert";
  matchedRules: string[];
  questions: string[];
};
const normalize = (value: string) =>
  value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
export function evaluateRisk(
  policy: RiskPolicy,
  enabled: boolean,
  text: string,
  antecedents: string,
): RiskEvaluation {
  const empty: RiskEvaluation = {
    riskLevel: "undetermined",
    recommendedAction: null,
    classificationStatus: enabled ? "unclassified" : "disabled",
    matchedRules: [],
    questions: [],
  };
  if (!enabled) return empty;
  const input = normalize(text),
    context = normalize(antecedents);
  const matches = policy.rules.filter(
    (rule) =>
      rule.terms.some((term) => input.includes(normalize(term))) &&
      (!rule.antecedentTerms.length ||
        rule.antecedentTerms.some((term) => context.includes(normalize(term)))),
  );
  matches.sort(
    (a, b) =>
      ({ red: 3, yellow: 2, green: 1 })[b.riskLevel] -
      { red: 3, yellow: 2, green: 1 }[a.riskLevel],
  );
  if (!matches.length) return empty;
  return {
    riskLevel: matches[0].riskLevel,
    recommendedAction: matches[0].action,
    classificationStatus: "clinically_validated_rules",
    matchedRules: matches.map((rule) => rule.code),
    questions: [...new Set(matches.flatMap((rule) => rule.questions))].slice(
      0,
      6,
    ),
  };
}
export function isRiskPolicy(value: unknown): value is RiskPolicy {
  if (
    !value ||
    typeof value !== "object" ||
    !Array.isArray((value as RiskPolicy).rules)
  )
    return false;
  const rules = (value as RiskPolicy).rules;
  const strings = (items: unknown, max: number) =>
    Array.isArray(items) &&
    items.length <= max &&
    items.every(
      (item) =>
        typeof item === "string" &&
        item.trim().length > 0 &&
        item.length <= 250,
    );
  return (
    rules.length <= 100 &&
    new Set(rules.map((rule) => rule?.code)).size === rules.length &&
    rules.every(
      (rule) =>
        rule &&
        typeof rule.code === "string" &&
        /^[a-zA-Z0-9_-]{1,60}$/.test(rule.code) &&
        strings(rule.terms, 32) &&
        rule.terms.length > 0 &&
        strings(rule.antecedentTerms, 32) &&
        strings(rule.questions, 6) &&
        ["green", "yellow", "red"].includes(rule.riskLevel) &&
        ["emergency", "appointment", "call_operator"].includes(rule.action) &&
        (rule.riskLevel !== "red" || rule.action === "emergency"),
    )
  );
}
