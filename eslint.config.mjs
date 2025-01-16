import { FlatCompat } from "@eslint/eslintrc";
import pluginJs from "@eslint/js";
import tseslint from "@typescript-eslint/eslint-plugin";
import pluginPrettier from "eslint-config-prettier";
import pluginImport from "eslint-plugin-import";
import globals from "globals";

const compat = new FlatCompat({
  baseDirectory: process.cwd(),
});

/** @type {import('eslint').Linter.Config[]} */
export default [
  { files: ["**/*.{js,mjs,cjs,ts}"] },
  {
    ignores: [
      "**/node_modules/**",
      "**/artifacts/**",
      "**/cache/**",
      "typechain-types/**",
      "dist/**",
      "eslint.config.mjs",
      "hardhat.config.ts",
      "tsconfig.json",
    ],
  },
  {
    languageOptions: {
      globals: { ...globals.node, process: "readonly" },
      parser: "@typescript-eslint/parser",
      parserOptions: {
        project: "./tsconfig.json",
      },
      ecmaVersion: "latest",
      sourceType: "module",
    },
    plugins: { "@typescript-eslint": tseslint, prettier: pluginPrettier, import: pluginImport },

    rules: {
      "@typescript-eslint/no-unused-vars": ["warn"],
      "@typescript-eslint/no-explicit-any": ["warn"],
      "@typescript-eslint/no-empty-interface": "warn",
      "@typescript-eslint/naming-convention": [
        "error",
        {
          selector: "parameter",
          format: ["camelCase", "PascalCase", "UPPER_CASE", "snake_case"],
          leadingUnderscore: "allow",
        },
      ],
      "import/no-unresolved": "warn",
      "no-undef": "warn",
    },
  },
  ...compat.extends("plugin:@typescript-eslint/recommended", "prettier"),
  pluginPrettier,
  pluginJs.configs.recommended,
];
