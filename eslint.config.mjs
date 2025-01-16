import pluginJs from "@eslint/js";
import globals from "globals";
import tseslint from "typescript-eslint";

/** @type {import('eslint').Linter.Config[]} */
export default [
  { files: ["**/*.{js,mjs,cjs,ts}"] },
  {
    languageOptions: {
      globals: globals.node,
      parser: "@typescript-eslint/parser",
      ecmaVersion: "latest",
      sourceType: "module",
    },
    linterOptions: { env: { node: true } },
    plugins: ["prettier", "@typescript-eslint"],
    extends: ["plugin:prettier/recommended", "plugin:@typescript-eslint/recommended"],
    rules: {
      "@typescript-eslint/no-unused-vars": ["error"],
      "@typescript-eslint/no-explicit-any": ["off"],
      "prettier/prettier": [
        "warn",
        {
          endOfLine: "auto",
        },
      ],
    },
  },
  pluginJs.configs.recommended,
  ...tseslint.configs.recommended,
];
