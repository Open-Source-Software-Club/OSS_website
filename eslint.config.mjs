import { FlatCompat } from "@eslint/eslintrc";
import { fileURLToPath } from "url";
import path from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const compat = new FlatCompat({
  baseDirectory: __dirname,
});

/** @type {import("eslint").Linter.FlatConfig[]} */
const config = [
  ...compat.extends("next/core-web-vitals", "prettier"),
  {
    ignores: [".next/**", "node_modules/**", "coverage/**", "dist/**", "out/**"],
  },
];

export default config;
