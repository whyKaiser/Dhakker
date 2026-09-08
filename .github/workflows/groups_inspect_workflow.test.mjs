// Static validation of the groups-inspection workflow's safety gates.
//
// This workflow points a credential at PRODUCTION. Its whole claim is that it
// can only read, and that it cannot leak a join code. The first claim rests
// on IAM — the impersonated account holds `roles/datastore.viewer`, which has
// no write permission — and this suite is the second layer: it asserts, as
// text properties of the file, that nothing here asks for a write, a delete,
// a deploy, or the write-capable staging identity.
//
// Deliberately assertions about the FILE, not about YAML semantics: the point
// is that an edit which quietly adds a write, unpins an action, swaps in the
// staging service account or slips in a `push:` trigger must turn a test red
// rather than pass review on a skim.

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const PATH = ".github/workflows/groups-inspect.yml";
const wf = readFileSync(PATH, "utf8");

// The line-level view, comments stripped, so a rule that only appears in a
// comment cannot satisfy a test about behaviour.
const code = wf
  .split("\n")
  .filter((l) => !l.trim().startsWith("#"))
  .join("\n");

test("the comment stripping the other tests rely on works", () => {
  // Without this, every scan below could pass for the wrong reason.
  assert.ok(wf.includes("READ ONLY, by hand only"), "fixture comment missing");
  assert.equal(code.includes("READ ONLY, by hand only"), false);
  assert.ok(code.includes("workflow_dispatch"), "the stripper ate the code");
});

// ── Trigger ───────────────────────────────────────────────────────────────

test("the only trigger is workflow_dispatch", () => {
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
  ]) {
    assert.equal(
      new RegExp(`^ {2}${trigger}:`, "m").test(code),
      false,
      `${trigger} must not trigger a production read`,
    );
  }
});

test("it refuses to run from any ref except main", () => {
  assert.match(code, /refs\/heads\/main/);
  assert.match(code, /exit 1/);
});

// ── Permissions ───────────────────────────────────────────────────────────

test("permissions are the two it needs and nothing more", () => {
  const block = code.match(/^permissions:\n((?: {2}.*\n)+)/m);
  assert.ok(block, "no top-level permissions block");
  const lines = block[1]
    .split("\n")
    .map((l) => l.trim())
    .filter(Boolean);
  assert.deepEqual(lines.sort(), ["contents: read", "id-token: write"]);
});

test("it never asks for repository write access", () => {
  assert.equal(/contents:\s*write/.test(code), false);
  assert.equal(/packages:\s*write/.test(code), false);
  assert.equal(/deployments:\s*write/.test(code), false);
  assert.equal(/pull-requests:\s*write/.test(code), false);
});

// ── Approval ──────────────────────────────────────────────────────────────

test("it runs behind the protected read-only environment", () => {
  assert.match(code, /environment:\s*firebase-production-readonly/);
});

test("it does not borrow the staging or retirement environment", () => {
  assert.equal(code.includes("firebase-staging"), false);
  assert.equal(code.includes("firebase-legacy-retirement"), false);
});

// ── Identity ──────────────────────────────────────────────────────────────

test("it authenticates as the read-only account, not the staging one", () => {
  assert.match(
    code,
    /service_account:\s*\$\{\{\s*vars\.FIREBASE_PRODUCTION_READER_SERVICE_ACCOUNT\s*\}\}/,
  );
  assert.equal(
    /service_account:\s*\$\{\{\s*vars\.GCP_SERVICE_ACCOUNT\s*\}\}/.test(code),
    false,
    "the staging account can write",
  );
});

test("it refuses to run if the reader and staging accounts are the same", () => {
  assert.match(code, /READER_SERVICE_ACCOUNT.*=.*STAGING_SERVICE_ACCOUNT/s);
});

test("no key file is written and no credential is exported to the env", () => {
  assert.match(code, /create_credentials_file:\s*false/);
  assert.match(code, /export_environment_variables:\s*false/);
  assert.match(code, /token_format:\s*access_token/);
});

test("the token is short-lived", () => {
  const m = code.match(/access_token_lifetime:\s*(\d+)s/);
  assert.ok(m, "no access_token_lifetime");
  assert.ok(Number(m[1]) <= 600, `lifetime too long: ${m[1]}s`);
});

test("no JSON service-account key is referenced anywhere", () => {
  for (const token of [
    "credentials_json",
    "GOOGLE_APPLICATION_CREDENTIALS",
    "private_key",
    "secrets.GCP_SA_KEY",
  ]) {
    assert.equal(code.includes(token), false, `${token} must not appear`);
  }
});

// ── It cannot write ───────────────────────────────────────────────────────

test("no write, delete or deploy verb reaches the script", () => {
  for (const flag of ["--write", "--execute", "--prune", "--revoke", "--only"]) {
    assert.equal(code.includes(flag), false, `${flag} must not appear`);
  }
  assert.equal(/firebase\s+deploy/.test(code), false);
  assert.equal(code.includes("gcloud firestore"), false);
});

test("the only script it runs is the inspection tool", () => {
  const runs = [...code.matchAll(/node\s+(\S+)/g)].map((m) => m[1]);
  assert.deepEqual([...new Set(runs)], ["scripts/inspect_groups.mjs"]);
});

test("it never touches the retirement or import tooling", () => {
  assert.equal(code.includes("retire_legacy_records"), false);
  assert.equal(code.includes("import_source_pack"), false);
});

test("it asserts in-run that the report claims no write", () => {
  assert.match(code, /grep -q "READ ONLY, nothing is written"/);
  assert.match(code, /grep -q "No document was written, created or deleted\."/);
});

// ── It cannot leak a join code ────────────────────────────────────────────

test("the run fails if a join code ever reaches the log", () => {
  // The strongest gate here. A summary is read by more people than the
  // database is, so a leak into it is worse than a leak in place.
  assert.match(code, /grep -qE 'HAJJ-\[0-9\]\+' inspect\.log/);
  assert.match(code, /a join code appeared in the report/);
});

test("the summary is built from a filter, not from the whole log", () => {
  assert.match(code, /grep -E '\^\(groups:\|group_codes:/);
  assert.equal(
    /cat inspect\.log >> "\$GITHUB_STEP_SUMMARY"/.test(code),
    false,
    "the raw log must not be pasted into the summary",
  );
});

// ── Confirmations ─────────────────────────────────────────────────────────

test("four confirmations are required, and checked before authentication", () => {
  for (const input of [
    "confirm_project",
    "confirm_database",
    "confirm_collection",
    "confirm_mode",
  ]) {
    assert.match(code, new RegExp(`^ {6}${input}:`, "m"));
  }
  const confirmAt = code.indexOf("Verify manual confirmations");
  const authAt = code.indexOf("google-github-actions/auth@");
  assert.ok(confirmAt > -1 && authAt > -1);
  assert.ok(
    confirmAt < authAt,
    "confirmations must be checked before a credential exists",
  );
});

test("the confirmations pin the collection to groups", () => {
  assert.match(code, /CONFIRM_COLLECTION" != "groups"/);
  assert.match(code, /CONFIRM_MODE" != "INSPECT_READ_ONLY"/);
  // It must not be possible to point this at the content collections.
  assert.equal(code.includes('"supplications"'), false);
});

// ── Pinning ───────────────────────────────────────────────────────────────

test("every action is pinned to a full commit SHA", () => {
  const uses = [...code.matchAll(/uses:\s*(\S+)/g)].map((m) => m[1]);
  assert.ok(uses.length >= 3, "expected at least three actions");
  for (const u of uses) {
    assert.match(u, /@[0-9a-f]{40}$/, `${u} is not pinned to a SHA`);
  }
});

test("the pinned SHAs are the ones the rest of the repository already uses", () => {
  // A different SHA here would mean a second, unreviewed version of the same
  // action in the same repository.
  const reconcile = readFileSync(
    ".github/workflows/production-reconcile.yml",
    "utf8",
  );
  const shas = (text) =>
    new Set([...text.matchAll(/uses:\s*\S+@([0-9a-f]{40})/g)].map((m) => m[1]));
  for (const sha of shas(code)) {
    assert.ok(shas(reconcile).has(sha), `unfamiliar action SHA: ${sha}`);
  }
});

// ── Concurrency ───────────────────────────────────────────────────────────

test("it has its own concurrency group and is not cancelled mid-read", () => {
  assert.match(code, /group:\s*groups-inspect/);
  assert.match(code, /cancel-in-progress:\s*false/);
});

test("checkout does not persist credentials", () => {
  assert.match(code, /persist-credentials:\s*false/);
});
