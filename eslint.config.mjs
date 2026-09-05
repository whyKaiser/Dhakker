// ESLint for the repository's Node code: the assistant Worker, the
// import/retirement scripts, and the static workflow gate tests.
//
// Scope is deliberately narrow. This is a correctness net, not a style
// rewrite: the rules below catch things that are bugs — an undefined
// identifier, an unreachable branch, a promise executor that returns, a
// `case` that falls through — and stay quiet about everything a formatter or
// a matter of taste would decide. Widening it into a stylistic overhaul
// would mean touching every file in a change nobody asked for.
//
// Not covered: Dart (see `dart format` and `flutter analyze`), and
// node_modules / build output.

import js from "@eslint/js";
import globals from "globals";

export default [
  {
    ignores: [
      "**/node_modules/**",
      "build/**",
      "graphify-out/**",
      "third_party/**",
      ".dart_tool/**",
      "web/**", // browser bootstrap, checked by the boot smoke check instead
    ],
  },

  js.configs.recommended,

  {
    // Everything here is ESM and runs on Node 20.
    files: ["**/*.mjs"],
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: "module",
      globals: { ...globals.node },
    },
    rules: {
      // An unused variable is usually a leftover from an edit; an unused
      // ARGUMENT often is not, so only trailing ones are reported and an
      // underscore prefix opts out.
      "no-unused-vars": [
        "error",
        { args: "after-used", argsIgnorePattern: "^_", caughtErrors: "none" },
      ],
      eqeqeq: ["error", "smart"],
      "no-var": "error",
      "prefer-const": ["error", { destructuring: "all" }],
      "no-throw-literal": "error",
      "no-constant-binary-expression": "error",

      // OFF, deliberately:
      //
      // no-return-await     — `return await` inside a try/catch is not
      //                       redundant, and the rule cannot tell the cases
      //                       apart. Semantics, not style.
      // no-regex-spaces     — several regexes match fixed-width log output
      //                       (`Storage:   NOT CONTACTED`). The literal
      //                       spaces are the point; ` {3}` reads worse.
      // require-atomic-updates — noisy on legitimate sequential awaits.
      "no-return-await": "off",
      "no-regex-spaces": "off",
      "require-atomic-updates": "off",
    },
  },

  {
    // The Cloudflare Worker runs in a browser-like runtime, not Node: no
    // `process`, no `require`, but `fetch`, `Request`, `Response`, `crypto`
    // and friends are ambient.
    files: ["assistant-proxy/worker.js"],
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: "module",
      globals: { ...globals.browser, ...globals.worker },
    },
    rules: {
      // The `fetch(request, env, ctx)` signature is fixed by the runtime, and
      // `catch (_)` is used throughout to mean "expected, ignored".
      "no-unused-vars": [
        "error",
        { args: "none", varsIgnorePattern: "^_", caughtErrors: "none" },
      ],

      // sanitizeText() strips control characters from untrusted input. The
      // control characters in that class are exactly the point of it, and
      // rewriting the expression to satisfy a linter would be a security
      // change made for cosmetic reasons.
      "no-control-regex": "off",
    },
  },

  {
    // A regex here trims trailing ASCII space AND U+00A0, which matters for
    // the Arabic text this script rewrites. The "irregular" whitespace is
    // deliberate and load-bearing.
    files: ["scripts/rebuild_quran_authority.mjs"],
    rules: { "no-irregular-whitespace": ["error", { skipRegExps: true }] },
  },

  {
    // Test files additionally use the node:test globals via imports, so
    // nothing extra is needed — but they legitimately declare helpers that
    // only some cases use.
    files: ["**/*.test.mjs", "test_web_boot/*.mjs"],
    rules: {
      "no-unused-vars": ["warn", { args: "none", caughtErrors: "none" }],
    },
  },

  {
    // The boot smoke check drives a browser: `window` is evaluated inside the
    // page, not in Node.
    files: ["test_web_boot/*.mjs"],
    languageOptions: {
      globals: { ...globals.node, ...globals.browser },
    },
  },
];
