// Static validation of the group_codes migration workflow's safety gates.
//
// This workflow WRITES to production. Its claim is that it can only create
// documents in one collection, only after two explicit human acts, and only
// as an identity that is neither the read-only reconciler nor the
// write-everything staging account.
//
// Assertions about the FILE, not YAML semantics: the point is that an edit
// which quietly widens the target collection, drops the dry-run default,
// swaps the identity, unpins an action or slips in a `push:` trigger turns a
// test red rather than passing review on a skim.

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const PATH = ".github/workflows/group-codes-migration.yml";
const wf = readFileSync(PATH, "utf8");

const code = wf
  .split("\n")
  .filter((l) => !l.trim().startsWith("#"))
  .join("\n");

test("the comment stripping the other tests rely on works", () => {
  assert.ok(wf.includes("dry run by default"), "fixture comment missing");
  assert.equal(code.includes("dry run by default"), false);
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
      `${trigger} must never trigger a production write`,
    );
  }
});

test("it refuses to run from any ref except main", () => {
  assert.match(code, /refs\/heads\/main/);
});

// ── Dry run is the default ────────────────────────────────────────────────

test("execute is an explicit boolean input defaulting to false", () => {
  const block = code.match(/^ {6}execute:\n((?: {8}.*\n)+)/m);
  assert.ok(block, "no execute input");
  assert.match(block[1], /type:\s*boolean/);
  assert.match(block[1], /default:\s*false/);
  assert.match(block[1], /required:\s*true/);
});

test("--execute reaches the tool only on the true branch", () => {
  // If --execute appeared unconditionally, the dry run would write.
  const executeLines = code
    .split("\n")
    .filter((l) => l.includes("--execute"));
  assert.equal(executeLines.length, 1, "expected exactly one --execute call");
  const at = code.indexOf("--execute");
  const branchAt = code.indexOf('if [ "$EXECUTE" = "true" ]');
  const elseAt = code.indexOf("else", branchAt);
  assert.ok(branchAt > -1 && branchAt < at && at < elseAt,
    "--execute is not inside the true branch");
});

test("a dry run that reports a creation fails the run", () => {
  assert.match(code, /a dry run reported a creation/);
});

// ── Permissions and approval ──────────────────────────────────────────────

test("permissions are the two it needs and nothing more", () => {
  const block = code.match(/^permissions:\n((?: {2}.*\n)+)/m);
  assert.ok(block);
  const lines = block[1].split("\n").map((l) => l.trim()).filter(Boolean);
  assert.deepEqual(lines.sort(), ["contents: read", "id-token: write"]);
});

test("it runs behind its own protected environment", () => {
  assert.match(code, /environment:\s*firebase-group-codes-migration/);
});

test("it does not borrow the read-only or staging environment", () => {
  // Approval to read production is not approval to write to it.
  assert.equal(code.includes("environment: firebase-production-readonly"), false);
  assert.equal(code.includes("environment: firebase-staging"), false);
  assert.equal(code.includes("environment: firebase-legacy-retirement"), false);
});

// ── Identity ──────────────────────────────────────────────────────────────

test("it authenticates as its own migration account", () => {
  assert.match(
    code,
    /service_account:\s*\$\{\{\s*vars\.FIREBASE_GROUP_CODES_SERVICE_ACCOUNT\s*\}\}/,
  );
});

test("it refuses the staging and the read-only identities", () => {
  assert.match(code, /MIGRATION_SERVICE_ACCOUNT.*=.*STAGING_SERVICE_ACCOUNT/s);
  assert.match(code, /MIGRATION_SERVICE_ACCOUNT.*=.*READER_SERVICE_ACCOUNT/s);
  assert.equal(
    /service_account:\s*\$\{\{\s*vars\.GCP_SERVICE_ACCOUNT\s*\}\}/.test(code),
    false,
  );
});

test("no key file, no ambient credential, short-lived token", () => {
  assert.match(code, /create_credentials_file:\s*false/);
  assert.match(code, /export_environment_variables:\s*false/);
  assert.match(code, /token_format:\s*access_token/);
  const m = code.match(/access_token_lifetime:\s*(\d+)s/);
  assert.ok(m && Number(m[1]) <= 600, "token lifetime missing or too long");
});

test("no JSON service-account key is referenced", () => {
  for (const token of [
    "credentials_json",
    "GOOGLE_APPLICATION_CREDENTIALS",
    "private_key",
    "secrets.GCP_SA_KEY",
  ]) {
    assert.equal(code.includes(token), false, `${token} must not appear`);
  }
});

// ── Scope of the write ────────────────────────────────────────────────────

test("the confirmations pin the write target to group_codes", () => {
  assert.match(code, /CONFIRM_COLLECTION" != "group_codes"/);
  assert.match(code, /CONFIRM_MODE" != "MIGRATE_GROUP_CODES"/);
});

test("no other collection is named anywhere in the run", () => {
  for (const other of [
    "supplications",
    "supplications_staging",
    "supplications_legacy_archive",
    "/members",
  ]) {
    assert.equal(code.includes(other), false, `${other} must not appear`);
  }
});

test("the only script it runs is the migration tool and its own tests", () => {
  const runs = [...code.matchAll(/node\s+(?:--test\s+)?(\S+)/g)].map((m) => m[1]);
  assert.deepEqual(
    [...new Set(runs)].sort(),
    [
      "scripts/migrate_group_codes.mjs",
      "scripts/migrate_group_codes.test.mjs",
    ],
  );
});

test("the tool's guard tests run before the credential is minted", () => {
  // A tool whose safety tests do not pass must not reach production.
  const testsAt = code.indexOf("scripts/migrate_group_codes.test.mjs");
  const authAt = code.indexOf("google-github-actions/auth@");
  assert.ok(testsAt > -1 && authAt > -1);
  assert.ok(testsAt < authAt, "guard tests must run before authentication");
});

test("no deploy, delete or retirement tooling is reachable", () => {
  assert.equal(/firebase\s+deploy/.test(code), false);
  assert.equal(code.includes("retire_legacy_records"), false);
  assert.equal(code.includes("import_source_pack"), false);
  assert.equal(code.includes("gcloud"), false);
});

// ── Assertions the run makes about itself ─────────────────────────────────

test("it asserts Storage was never contacted", () => {
  assert.match(code, /grep -q "Storage:   NOT CONTACTED"/);
});

test("it asserts nothing outside group_codes was modified on execute", () => {
  assert.match(
    code,
    /grep -q "No group, member or supplication document was modified\."/,
  );
});

test("the run fails if a join code ever reaches the log", () => {
  assert.match(code, /grep -qE 'HAJJ-\[0-9\]\+' migrate\.log/);
  assert.match(code, /a join code appeared in the report/);
});

test("the summary is built from a filter, not the whole log", () => {
  assert.equal(
    /cat migrate\.log >> "\$GITHUB_STEP_SUMMARY"/.test(code),
    false,
    "the raw log must not be pasted into the summary",
  );
});

// ── Pinning and concurrency ───────────────────────────────────────────────

test("every action is pinned to a full commit SHA", () => {
  const uses = [...code.matchAll(/uses:\s*(\S+)/g)].map((m) => m[1]);
  assert.ok(uses.length >= 3);
  for (const u of uses) {
    assert.match(u, /@[0-9a-f]{40}$/, `${u} is not pinned to a SHA`);
  }
});

test("the pinned SHAs are ones the repository already uses", () => {
  const known = readFileSync(
    ".github/workflows/production-reconcile.yml",
    "utf8",
  );
  const shas = (t) =>
    new Set([...t.matchAll(/uses:\s*\S+@([0-9a-f]{40})/g)].map((m) => m[1]));
  for (const sha of shas(code)) {
    assert.ok(shas(known).has(sha), `unfamiliar action SHA: ${sha}`);
  }
});

test("it has its own concurrency group and is not cancelled mid-write", () => {
  assert.match(code, /group:\s*group-codes-migration/);
  assert.match(code, /cancel-in-progress:\s*false/);
});

test("checkout does not persist credentials", () => {
  assert.match(code, /persist-credentials:\s*false/);
});
