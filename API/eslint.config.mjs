import eslint from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ["**/*.ts"],
    rules: {
      "@typescript-eslint/no-explicit-any": "off",
      // Stripe exports a CommonJS constructor; keep TypeScript import assignments.
      "@typescript-eslint/no-require-imports": ["error", { allowAsImport: true }]
    }
  }
);
