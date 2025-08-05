import js from "@eslint/js";

export default [
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
    },
    rules: {
      // 基本的なルール
      "no-unused-vars": "warn",
      "no-console": "warn",
      "no-debugger": "warn",
    },
  },
  {
    ignores: [
      "node_modules/**",
      "vendor/**",
      "tmp/**",
      "log/**",
      "storage/**",
      "public/assets/**",
    ],
  },
];
