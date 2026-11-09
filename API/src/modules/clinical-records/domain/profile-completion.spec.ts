import { calculateCompletion } from "./profile-completion";
describe("Profile completion", () => {
  it("does not invent a percentage without configured rules", () => {
    expect(calculateCompletion([], {})).toEqual({
      configured: false,
      percent: null,
      completed: 0,
      total: 0,
      missing: [],
    });
  });
  it("counts equally configured fields and preserves responsible actor", () => {
    const rules = [
      {
        field: "bloodType" as const,
        label: "Grupo",
        actor: "patient" as const,
      },
      {
        field: "professionalVitals" as const,
        label: "Signos",
        actor: "professional" as const,
      },
    ];
    expect(
      calculateCompletion(rules, {
        bloodType: true,
        professionalVitals: false,
      }),
    ).toMatchObject({ percent: 50, missing: [rules[1]] });
  });
});
