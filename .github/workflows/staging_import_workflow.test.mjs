// Static validation of the staging-import workflow's safety gates.
//
// A workflow file has no unit tests of its own, and its failure mode is the
// worst kind: it looks fine in review and only misbehaves the day someone
// runs it against a real project. So the guarantees are asserted here as
// text properties of the file, and this suite runs in CI on every change.
//
// These are deliberately assertions about the FILE, not about YAML
// semantics: the point is that a future edit which quietly adds a `push:`
// trigger, unpins an action, or slips `--production` in must turn a test
// red rather than pass review on a skim.

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const PATH = ".github/workflows/staging-import.yml";
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

  // Every automatic trigger must be absent. A staging write must never be
  // startable by pushing a commit or opening a PR.
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
      `trigger "${trigger}" must not be present`,
    );
  }
});

test("permissions are exactly contents:read and id-token:write", () => {
  const block = code.match(/^permissions:\n((?: {2}\S.*\n)+)/m);
  assert.ok(block, "a top-level permissions block is required");

  const lines = block[1].trim().split("\n").map((l) => l.trim());
  assert.deepEqual(lines.sort(), ["contents: read", "id-token: write"]);
});

test("the job runs in the protected firebase-staging environment", () => {
  assert.match(code, /^ {4}environment: firebase-staging$/m);
});

test("concurrency prevents two staging imports at once, without cancelling", () => {
  assert.match(code, /^concurrency:/m);
  assert.match(code, /group: staging-import/);
  // Cancelling mid-write would leave a half-imported collection; queueing is
  // the correct behaviour for a job that writes.
  assert.match(code, /cancel-in-progress: false/);
});

test("production is unreachable from this workflow", () => {
  assert.equal(code.includes("--production"), false);
  // The only collection named anywhere in the executable part is staging.
  assert.equal(/supplications(?!_staging)/.test(code), false);
  assert.ok(code.includes("supplications_staging"));
});

test("the write is limited to one record and carries its confirmations", () => {
  assert.match(code, /--staging --limit 1 --write/);
  assert.match(code, /--confirm-project=/);
  assert.match(code, /--confirm-count=/);
});

test("a dry run happens before authentication", () => {
  const dryRun = code.indexOf("--staging --limit 1\n");
  const auth = code.indexOf("google-github-actions/auth@");
  assert.ok(dryRun > -1, "a dry-run step is required");
  assert.ok(auth > -1, "an auth step is required");
  assert.ok(dryRun < auth, "the dry run must precede authentication");
});

test("confirmations are checked before authentication", () => {
  const confirmStep = code.indexOf("Verify manual confirmations");
  const auth = code.indexOf("google-github-actions/auth@");
  assert.ok(confirmStep > -1);
  assert.ok(
    confirmStep < auth,
    "the confirmation gate must run before any credential is minted",
  );
});

test("each confirmation is compared to its exact required value", () => {
  assert.match(code, /CONFIRM_PROJECT" != "dhakker-160d0"/);
  assert.match(code, /CONFIRM_COLLECTION" != "supplications_staging"/);
  assert.match(code, /CONFIRM_COUNT" != "1"/);
  // Each mismatch must end the run.
  assert.match(code, /exit 1/);
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
  // A bare SHA is unreviewable. Each `uses:` must be preceded by a comment
  // naming the version that SHA corresponds to.
  const lines = wf.split("\n");
  const usesLines = lines
    .map((l, i) => [l, i])
    .filter(([l]) => /^\s*uses:/.test(l));

  assert.ok(usesLines.length > 0);
  for (const [line, i] of usesLines) {
    const preceding = lines.slice(Math.max(0, i - 6), i).join("\n");
    assert.match(
      preceding,
      /#.*v\d+\.\d+\.\d+/,
      `no version comment documented above: ${line.trim()}`,
    );
  }
});

test("configuration comes from vars, never from inline secrets", () => {
  for (const name of [
    "FIREBASE_PROJECT_ID",
    "FIREBASE_DATABASE_ID",
    "GCP_WORKLOAD_IDENTITY_PROVIDER",
    "GCP_SERVICE_ACCOUNT",
  ]) {
    assert.ok(
      code.includes(`vars.${name}`),
      `${name} must be read from vars.*`,
    );
    assert.equal(
      code.includes(`secrets.${name}`),
      false,
      `${name} must not be read from secrets.*`,
    );
  }
});

test("no long-lived credential is created or exported", () => {
  assert.match(code, /create_credentials_file:\s*false/);
  assert.match(code, /export_environment_variables:\s*false/);
  assert.match(code, /access_token_lifetime:\s*\d+s/);
  // A service-account key must never appear.
  assert.equal(/credentials_json|private_key|service_account_key/.test(code), false);
});

test("nothing echoes a token, a credential, or the environment", () => {
  const dangerous = [
    /echo[^\n]*\$\{?\{?\s*secrets\./,
    /echo[^\n]*access_token/i,
    /echo[^\n]*FIREBASE_ADMIN_TOKEN/,
    /echo[^\n]*Authorization/i,
    /\bprintenv\b/,
    /\benv\s*$/m,
    /set -x/,
  ];
  for (const pattern of dangerous) {
    assert.equal(
      pattern.test(code),
      false,
      `workflow must not contain ${pattern}`,
    );
  }
});

test("the checkout does not leave repository credentials on disk", () => {
  // Otherwise the job would carry a token it has no use for.
  assert.match(code, /persist-credentials:\s*false/);
});
