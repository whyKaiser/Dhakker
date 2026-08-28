// Static validation of the production-reconcile workflow's safety gates.
//
// This workflow points a credential at the PRODUCTION collection. Its whole
// claim is that it can only read. The claim rests on IAM — the impersonated
// service account holds `roles/datastore.viewer`, which has no write
// permission — and this suite is the second layer: it asserts, as text
// properties of the file, that nothing here asks for a write, a delete, a
// deploy, or the write-capable staging identity.
//
// Deliberately assertions about the FILE, not about YAML semantics: the point
// is that an edit which quietly adds `--write`, unpins an action, swaps in
// the staging service account or slips in a `push:` trigger must turn a test
// red rather than pass review on a skim.

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const PATH = ".github/workflows/production-reconcile.yml";
const wf = readFileSync(PATH, "utf8");

// The line-level view, comments stripped, so a rule that only appears in a
// comment cannot satisfy a test about behaviour.
const code = wf
  .split("\n")
  .filter((l) => !l.trim().startsWith("#"))
  .join("\n");

test("the only trigger is workflow_dispatch", () => {
  assert.match(code, /^on:\s*$/m);
  assert.match(code, /^ {2}workflow_dispatch:/m);
  for (const trigger of [
    "push",
    "pull_request",
    "pull_request_target",
    "schedule",
    "repository_dispatch",
    "workflow_run",
    "workflow_call",
    "issue_comment",
    "release",
  ]) {
    assert.equal(
      new RegExp(`^ {2}${trigger}:`, "m").test(code),
      false,
      `trigger "${trigger}" must not be present — a read of production must ` +
        `never start by itself`,
    );
  }
});

test("it runs from main and nowhere else", () => {
  assert.match(code, /REF: \$\{\{ github\.ref \}\}/);
  assert.match(code, /if \[ "\$REF" != "refs\/heads\/main" \]; then/);
  const refGate = code.indexOf("Refuse to run from any ref except main");
  const auth = code.indexOf("google-github-actions/auth@");
  assert.ok(refGate > -1 && refGate < auth, "the ref gate precedes auth");
});

test("the job runs in its own protected environment", () => {
  assert.match(code, /^ {4}environment: firebase-production-readonly$/m);
  // Not the staging environment: its reviewers and its variables are a
  // different decision.
  assert.equal(code.includes("environment: firebase-staging"), false);
});

test("all four confirmations are checked, before authentication", () => {
  assert.match(code, /CONFIRM_PROJECT" != "dhakker-160d0"/);
  assert.match(code, /CONFIRM_DATABASE" != "\(default\)"/);
  assert.match(code, /CONFIRM_COLLECTION" != "supplications"/);
  assert.match(code, /CONFIRM_MODE" != "RECONCILE_READ_ONLY"/);

  const confirmStep = code.indexOf("Verify manual confirmations");
  const auth = code.indexOf("google-github-actions/auth@");
  assert.ok(confirmStep > -1);
  assert.ok(
    confirmStep < auth,
    "confirmations must be checked before any credential is minted",
  );
  // Each mismatch ends the run.
  assert.equal((code.match(/exit 1/g) ?? []).length >= 4, true);
});

test("the command reconciles production and cannot write", () => {
  assert.match(code, /--production --reconcile/);
  assert.equal(code.includes("--write"), false, "--write must not appear");
  assert.equal(code.includes("--limit"), false);
  assert.equal(code.includes("--confirm-count"), false);
});

test("nothing here mutates, deletes, publishes or deploys", () => {
  // Matched as things the job could DO, not as substrings: the file
  // legitimately greps for the importer's own line "No document was written,
  // deleted or revoked", and a test that banned the word "revoke" outright
  // would forbid asserting its absence.
  for (const forbidden of [
    "--write",
    '"PATCH"',
    "-X PATCH",
    "method: PATCH",
    '"DELETE"',
    "-X DELETE",
    "--prune",
    "firebase deploy",
    "gsutil",
    "gcloud storage",
    "storage.googleapis.com",
    "firestore.rules",
    "storage.rules",
    "flutter build",
    "wrangler",
  ]) {
    assert.equal(
      code.includes(forbidden),
      false,
      `"${forbidden}" must not appear in an executable line`,
    );
  }
  // And no HTTP verb that mutates, however it is spelled.
  assert.equal(
    /\b(PATCH|DELETE|POST|PUT)\b/.test(
      code.replace(/deleted or revoked/g, "").replace(/reported a write/g, ""),
    ),
    false,
    "no mutating HTTP verb may appear",
  );
  // A write reported by the importer fails the step outright.
  assert.match(code, /a read-only reconciliation reported a write/);
});

test("the staging collection is never named", () => {
  assert.equal(code.includes("supplications_staging"), false);
  assert.ok(code.includes("supplications"));
});

test("it uses the read-only service account, never the staging one", () => {
  assert.match(
    code,
    /service_account: \$\{\{ vars\.FIREBASE_PRODUCTION_READER_SERVICE_ACCOUNT \}\}/,
  );
  // The staging account appears exactly once, and only to be REJECTED if it
  // is the same principal as the reader.
  assert.match(
    code,
    /if \[ "\$READER_SERVICE_ACCOUNT" = "\$STAGING_SERVICE_ACCOUNT" \]; then/,
  );
  assert.equal(
    /service_account: \$\{\{ vars\.GCP_SERVICE_ACCOUNT \}\}/.test(code),
    false,
    "the write-capable staging account must never be impersonated here",
  );
});

test("the token is short-lived and never written to disk", () => {
  assert.match(code, /token_format: access_token/);
  assert.match(code, /access_token_lifetime: 300s/);
  assert.match(code, /create_credentials_file: false/);
  assert.match(code, /export_environment_variables: false/);
});

test("permissions are exactly contents:read and id-token:write", () => {
  const block = code.match(/^permissions:\n((?: {2}\S.*\n)+)/m);
  assert.ok(block, "a top-level permissions block is required");
  const lines = block[1].trim().split("\n").map((l) => l.trim());
  assert.deepEqual(lines.sort(), ["contents: read", "id-token: write"]);
});

test("concurrency is its own group and does not cancel", () => {
  assert.match(code, /^concurrency:/m);
  assert.match(code, /group: production-reconcile/);
  assert.equal(code.includes("group: staging-import"), false);
  assert.match(code, /cancel-in-progress: false/);
});

test("nothing re-runs automatically", () => {
  for (const bad of ["retry", "max-attempts", "nick-fields/retry"]) {
    assert.equal(code.includes(bad), false, `"${bad}" must not appear`);
  }
});

test("every third-party action is pinned to a full 40-hex commit SHA", () => {
  const uses = [...code.matchAll(/uses:\s*(\S+)/g)].map((m) => m[1]);
  assert.ok(uses.length > 0, "expected at least one action");
  for (const ref of uses) {
    assert.match(
      ref,
      /^[\w.-]+\/[\w.-]+@[0-9a-f]{40}$/,
      `"${ref}" must be pinned to a full commit SHA, not a tag or branch`,
    );
  }
});

test("every pinned action documents its release version in a comment", () => {
  const lines = wf.split("\n");
  const usesLines = lines
    .map((l, i) => [l, i])
    .filter(([l]) => /^\s*uses:/.test(l));
  assert.ok(usesLines.length > 0);
  for (const [line, i] of usesLines) {
    const preceding = lines.slice(Math.max(0, i - 8), i).join("\n");
    assert.match(
      preceding,
      /#.*v\d+\.\d+\.\d+/,
      `no version comment documented above: ${line.trim()}`,
    );
  }
});

test("configuration comes from vars, and no secret is inlined", () => {
  for (const name of [
    "FIREBASE_PROJECT_ID",
    "FIREBASE_DATABASE_ID",
    "GCP_WORKLOAD_IDENTITY_PROVIDER",
    "FIREBASE_PRODUCTION_READER_SERVICE_ACCOUNT",
  ]) {
    assert.ok(code.includes(`vars.${name}`), `${name} must come from vars.*`);
  }
  // No long-lived key material of any kind.
  for (const bad of [
    "credentials_json",
    "service_account_key",
    "private_key",
    "GOOGLE_APPLICATION_CREDENTIALS",
  ]) {
    assert.equal(code.includes(bad), false, `"${bad}" must not appear`);
  }
});

test("the token reaches one step only, through env, and is never echoed", () => {
  const tokenUses = [...code.matchAll(/steps\.auth\.outputs\.access_token/g)];
  assert.equal(tokenUses.length, 1, "the token must be referenced exactly once");
  assert.match(code, /FIREBASE_ADMIN_TOKEN: \$\{\{ steps\.auth\.outputs\.access_token \}\}/);
  // Nothing prints it, and nothing prints the environment wholesale.
  for (const bad of ["echo $FIREBASE_ADMIN_TOKEN", "env |", "printenv", "set -x"]) {
    assert.equal(code.includes(bad), false, `"${bad}" would expose the token`);
  }
});

test("the summary prints findings, never field values", () => {
  // The reconciler prints ids, cases and hold reasons only. The summary
  // filters to those lines, so no Arabic text and no signed audio URL can be
  // carried into a public job summary.
  assert.match(code, /grep -E '\^\(Reconciling\|expected_\|present_but_\|text_changed\|  - \|No document\)'/);
  for (const bad of ["cat reconcile.log", "audioUrl", "text.ar"]) {
    assert.equal(code.includes(bad), false, `"${bad}" must not be printed`);
  }
});

test("the run proves it wrote nothing before it can pass", () => {
  assert.match(code, /grep -q "READ ONLY, nothing is written" reconcile\.log/);
  assert.match(
    code,
    /grep -q "No document was written, deleted or revoked\." reconcile\.log/,
  );
});

test("stale documents are REPORTED, and the job never repairs them", () => {
  // A finding must not become an edit. The workflow's response to a stale
  // document is a summary and a non-zero exit — nothing else.
  assert.match(code, /Findings above need a human decision/);
  assert.match(code, /Retraction is a/);
  assert.match(code, /exit "\$\{RECONCILE_EXIT:-1\}"/);
  // continue-on-error exists so the REPORT survives a non-zero reconcile,
  // not so a failure is swallowed: the final step re-raises the exit code.
  assert.match(code, /continue-on-error: true/);
});

test("the importer itself refuses --reconcile together with --write", async () => {
  // The workflow not naming --write is one layer; the CLI refusing the
  // combination is the layer beneath it.
  const { resolvePlan } = await import("../../scripts/import_source_pack.mjs");
  assert.throws(
    () =>
      resolvePlan(
        ["source_packs/x.json", "--production", "--reconcile", "--write"],
        { FIREBASE_PROJECT_ID: "p", FIREBASE_ADMIN_TOKEN: "t" },
      ),
    /--reconcile is read-only and cannot be combined with --write/,
  );
  const plan = resolvePlan(
    ["source_packs/x.json", "--production", "--reconcile"],
    { FIREBASE_PROJECT_ID: "p", FIREBASE_ADMIN_TOKEN: "t" },
  );
  assert.equal(plan.mode, "reconcile");
  assert.equal(plan.collection, "supplications");
});

// The stale-document inventory is only useful if it survives into the job
// summary — and only safe if what survives is presence, not values.
test("the job-summary filter passes an inventory row through unchanged", async () => {
  const { reconcile, printReconcile } = await import(
    "../../scripts/import_source_pack.mjs"
  );
  const findings = reconcile({
    live: [
      {
        documentId: "legacy-001",
        verificationStatus: "verified",
        isActive: true,
        audioMode: "file",
        audioUrl: "https://storage.example/a.mp3?token=SECRET",
        contentKind: "dua",
        createdAt: "2025-01-01T00:00:00.000Z",
        text: { ar: "نص", en: "text" },
      },
    ],
    cleared: [],
    excluded: [],
    packIds: new Set(),
  });

  const realLog = console.log;
  const lines = [];
  console.log = (...a) => lines.push(a.join(" "));
  try {
    printReconcile(findings, "supplications");
  } finally {
    console.log = realLog;
  }

  // The exact filter the workflow applies to reconcile.log.
  const filter =
    /^(Reconciling|expected_|present_but_|text_changed|  - |No document)/;
  const kept = lines.filter((l) => filter.test(l));
  const row = kept.find((l) => l.includes("legacy-001"));
  assert.ok(row, "the inventory row was filtered out of the job summary");
  assert.match(row, /audioUrl=present/);
  assert.ok(!row.includes("SECRET"), "the summary would carry a download token");
  assert.ok(!row.includes("نص"), "the summary would carry record text");
});

// The setup doc is the only record of how the reader identity is actually
// bound. An earlier draft named a principal that was never configured, so
// these pin the real one.
const SETUP_DOC = readFileSync("docs/PRODUCTION_RECONCILE_SETUP.md", "utf8");

test("the reader binding is documented in the attribute.repository form", () => {
  assert.match(
    SETUP_DOC,
    /principalSet:\/\/iam\.googleapis\.com\/projects\/435128982475\/locations\/global\/workloadIdentityPools\/github-pool\/attribute\.repository\/whyKaiser\/Dhakker/,
  );
});

test("the never-configured /subject/repo: principal is not presented as the binding", () => {
  // It may be MENTIONED, but only as the correction note saying it was wrong.
  const asMember = /--member="principalSet:[^"]*\/subject\/repo:/;
  assert.ok(
    !asMember.test(SETUP_DOC),
    "the doc still binds the subject/repo principal",
  );
  assert.match(SETUP_DOC, /never configured/);
});

test("the branch restriction is documented on the provider condition, not the binding", () => {
  for (const clause of [
    "assertion.repository_owner == 'whyKaiser'",
    "assertion.repository == 'whyKaiser/Dhakker'",
    "assertion.ref == 'refs/heads/main'",
  ]) {
    assert.ok(SETUP_DOC.includes(clause), `the doc omits: ${clause}`);
  }
  assert.match(SETUP_DOC, /The branch is not restricted by this binding/);
});
