/**
 * ========================================
 * 🎨 Stylelint設定ファイル
 * ========================================
 * 
 * CSSファイルのリント設定です。
 * Tailwind CSSの@tailwindと@applyディレクティブを認識します。
 */

export default {
  extends: [
    "stylelint-config-standard",
    "stylelint-config-tailwindcss"
  ],
  rules: {
    // Tailwind CSSの@applyディレクティブを許可
    "at-rule-no-unknown": [
      true,
      {
        ignoreAtRules: [
          "tailwind",
          "apply",
          "layer",
          "responsive",
          "screen",
          "variants",
          "utilities"
        ]
      }
    ],
    // カスタムプロパティを許可
    "property-no-unknown": [
      true,
      {
        ignoreProperties: [
          "composes",
          "theme"
        ]
      }
    ],
    // セレクタの命名規則を緩和
    "selector-class-pattern": null,
    // コメントスタイルを緩和
    "comment-empty-line-before": null,
    // 空行の規則を緩和
    "rule-empty-line-before": null,
    // 関数の命名規則を緩和
    "function-no-unknown": [
      true,
      {
        ignoreFunctions: [
          "theme",
          "screen"
        ]
      }
    ]
  },
  ignoreFiles: [
    "node_modules/**",
    "vendor/**",
    "tmp/**",
    "log/**",
    "storage/**",
    "public/assets/**",
    "app/assets/builds/**",
    "app/assets/stylesheets/tailwind.css"  // 自動生成されたTailwind CSSファイルを除外
  ]
};
