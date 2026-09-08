// Static validation of the rules-deploy workflow's safety gates.
//
// This workflow replaces the rules that decide who may read every pilgrim's
// data. Rules have no staged rollout and no undo: a mistake is live for
// everyone the moment it lands. Its claims are that it cannot deploy without
// the full emulator suite passing against the exact files being shipped, that
// it cannot deploy anything except rules and indexes, and that it cannot run
// without a human having dealt with the groups migration first.
//
// Assertions about the FILE, not YAML semantics: an edit that drops the test
// gate, widens the deploy targets, or removes the dry-run default must turn a
// test red rather than pass review on a skim.

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const PATH = ".github/workflows/rules-deploy.yml";
const wf = readFileSync(PATH, "utf8");

const code = wf
  .split("\n")
  .filter((l) => !l.trim().startsWith("#"))
  .join("\n");

test("the comment stripping the other tests rely on works", () => {
  assert.ok(wf.includes("no staged rollout and no undo"), "fixture comment missing");
  assert.equal(code.includes("no staged rollout and no undo"), false);
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
      `${trigger} must never trigger a rules deploy`,
    );
  }
});

test("it refuses to run from any ref except main", () => {
  assert.match(code, /refs\/heads\/main/);
});

// ── The test gate ─────────────────────────────────────────────────────────

test("the full rules suite runs before the deploy step", () => {
  // The single most important property here. Testing after deploying is
  // testing after the damage.
  const testAt = code.indexOf("Run the full rules suite");
  const deployAt = code.indexOf("firebase deploy");
  assert.ok(testAt > -1, "the rules suite does not run at all");
  assert.ok(deployAt > -1, "no deploy step");
  assert.ok(testAt < deployAt, "the suite must run before any deploy");
});

test("the suite runs the whole thing, not a subset", () => {
  // `npm test` in test_firestore_rules runs both the Firestore and the
  // Storage suites behind one emulator start.
  assert.match(code, /working-directory:\s*test_firestore_rules\n\s*run:\s*npm test/);
  assert.equal(code.includes("test:firestore"), false, "a partial suite was used");
  assert.equal(code.includes("test:storage"), false, "a partial suite was used");
});

test("the suite is not allowed to fail the job silently", () => {
  assert.equal(
    /continue-on-error:\s*true/.test(code),
    false,
    "no step here may continue on error",
  );
});

test("it records the hash of every file it deploys", () => {
  // A deploy must ship what was reviewed, and the summary must say what that
  // was.
  assert.match(code, /sha256sum firestore\.rules storage\.rules firestore\.indexes\.json/);
});

// ── Deploy scope ──────────────────────────────────────────────────────────

test("every deploy is scoped with an explicit --only", () => {
  const deploys = code.split("\n").filter((l) => l.includes("firebase deploy"));
  assert.ok(deploys.length > 0);
  // Each `firebase deploy` line is followed by its --only within the command.
  const commands = code.split("firebase deploy").slice(1);
  for (const c of commands) {
    const head = c.slice(0, 200);
    assert.match(head, /--only\s+\S+/, "a deploy had no --only");
  }
});

test("hosting is never a deploy target", () => {
  // `firebase deploy` with no --only also publishes hosting, whose public
  // directory is a build output that may be stale or absent.
  assert.equal(/--only[^\n]*hosting/.test(code), false);
  assert.equal(code.includes("deploy --only hosting"), false);
  assert.match(code, /Hosting was \*\*not\*\* deployed/);
});

test("functions and remote config are never deploy targets", () => {
  for (const target of ["functions", "remoteconfig", "extensions", "dataconnect"]) {
    assert.equal(
      new RegExp(`--only[^\\n]*${target}`).test(code),
      false,
      `${target} must not be deployable here`,
    );
  }
});

test("the confirmed targets are exactly the three deployed", () => {
  assert.match(
    code,
    /CONFIRM_TARGETS" != "firestore:rules,storage:rules,firestore:indexes"/,
  );
  assert.match(code, /--only firestore:indexes/);
  assert.match(code, /--only firestore:rules,storage:rules/);
});

test("indexes are deployed before rules", () => {
  // Index builds are asynchronous; starting them first shortens the window
  // in which a query has rules but no index.
  const idx = code.indexOf("--only firestore:indexes");
  const rules = code.indexOf("--only firestore:rules,storage:rules");
  assert.ok(idx > -1 && rules > -1);
  assert.ok(idx < rules, "indexes must be deployed first");
});

test("it deletes nothing and touches no document", () => {
  for (const forbidden of [
    "firestore:delete",
    "--force",
    "gcloud firestore",
    "retire_legacy_records",
    "import_source_pack",
    "migrate_group_codes",
  ]) {
    assert.equal(code.includes(forbidden), false, `${forbidden} must not appear`);
  }
});

// ── Dry run is the default ────────────────────────────────────────────────

test("execute is an explicit boolean defaulting to false", () => {
  const block = code.match(/^ {6}execute:\n((?: {8}.*\n)+)/m);
  assert.ok(block, "no execute input");
  assert.match(block[1], /type:\s*boolean/);
  assert.match(block[1], /default:\s*false/);
  assert.match(block[1], /required:\s*true/);
});

test("a non-execute run exits before any deploy command", () => {
  const guardAt = code.indexOf('if [ "$EXECUTE" != "true" ]');
  const exitAt = code.indexOf("exit 0", guardAt);
  const deployAt = code.indexOf("firebase deploy");
  assert.ok(guardAt > -1, "no execute guard");
  assert.ok(exitAt > -1 && exitAt < deployAt, "the guard does not exit before deploying");
});

// ── The groups ordering ───────────────────────────────────────────────────

test("it refuses to run until the groups question has been answered", () => {
  // Deploying the #33 rules before the pointers exist breaks joining for
  // every pre-existing group.
  assert.match(code, /confirm_groups_checked:/);
  assert.match(code, /GROUPS_EMPTY/);
  assert.match(code, /GROUPS_MIGRATED/);
  assert.match(code, /CONFIRM_GROUPS" != "GROUPS_EMPTY"/);
});

test("GROUPS_PRESENT alone is not an accepted answer", () => {
  // "There are groups" is a finding, not a resolution. Only "empty" or
  // "migrated" may proceed.
  const guard = code.slice(code.indexOf("CONFIRM_GROUPS"));
  assert.equal(
    /CONFIRM_GROUPS"\s*=\s*"GROUPS_PRESENT"/.test(guard),
    false,
    "GROUPS_PRESENT must not be accepted",
  );
});

// ── Identity and permissions ──────────────────────────────────────────────

test("permissions are the two it needs and nothing more", () => {
  const block = code.match(/^permissions:\n((?: {2}.*\n)+)/m);
  assert.ok(block);
  const lines = block[1].split("\n").map((l) => l.trim()).filter(Boolean);
  assert.deepEqual(lines.sort(), ["contents: read", "id-token: write"]);
});

test("it runs behind its own protected environment", () => {
  assert.match(code, /environment:\s*firebase-rules-deploy/);
  for (const other of [
    "firebase-production-readonly",
    "firebase-staging",
    "firebase-group-codes-migration",
    "firebase-legacy-retirement",
  ]) {
    assert.equal(
      code.includes(`environment: ${other}`),
      false,
      `must not borrow ${other}`,
    );
  }
});

test("it authenticates as its own deploy account", () => {
  assert.match(
    code,
    /service_account:\s*\$\{\{\s*vars\.FIREBASE_RULES_DEPLOY_SERVICE_ACCOUNT\s*\}\}/,
  );
  assert.match(code, /DEPLOY_SERVICE_ACCOUNT.*=.*READER_SERVICE_ACCOUNT/s);
  assert.match(code, /DEPLOY_SERVICE_ACCOUNT.*=.*STAGING_SERVICE_ACCOUNT/s);
});

test("the credential is a WIF config, never a downloaded key", () => {
  // This workflow DOES write a credentials file, unlike the read and
  // migration ones: firebase-tools authenticates through Application Default
  // Credentials and has no supported path for a bare access token. What is
  // written is a short-lived external-account config pointing at the
  // runner's OIDC token — no private key, useless off the runner, gone with
  // the job. What must never appear is an actual service-account key.
  assert.match(code, /create_credentials_file:\s*true/);
  assert.match(code, /workload_identity_provider:/);
  assert.equal(
    /access_token_lifetime:/.test(code),
    false,
    "an access token is not how firebase-tools authenticates",
  );
});

test("no JSON service-account key or CI token is referenced", () => {
  for (const token of [
    "credentials_json",
    "GOOGLE_APPLICATION_CREDENTIALS",
    "private_key",
    "secrets.GCP_SA_KEY",
    "secrets.FIREBASE_TOKEN",
  ]) {
    assert.equal(code.includes(token), false, `${token} must not appear`);
  }
});

// ── Pinning and concurrency ───────────────────────────────────────────────

test("every action is pinned to a full commit SHA", () => {
  const uses = [...code.matchAll(/uses:\s*(\S+)/g)].map((m) => m[1]);
  assert.ok(uses.length >= 4);
  for (const u of uses) {
    assert.match(u, /@[0-9a-f]{40}$/, `${u} is not pinned to a SHA`);
  }
});

test("the pinned SHAs are ones the repository already uses", () => {
  const known =
    readFileSync(".github/workflows/production-reconcile.yml", "utf8") +
    readFileSync(".github/workflows/flutter-ci.yml", "utf8");
  const shas = (t) =>
    new Set([...t.matchAll(/uses:\s*\S+@([0-9a-f]{40})/g)].map((m) => m[1]));
  for (const sha of shas(code)) {
    assert.ok(shas(known).has(sha), `unfamiliar action SHA: ${sha}`);
  }
});

test("dependencies are installed with npm ci, not npm install", () => {
  // `npm ci` fails loudly if package.json and the lockfile disagree, so the
  // emulator that gates this deploy is the reviewed one.
  assert.match(code, /npm ci --no-audit --no-fund/);
  assert.equal(/run:\s*npm install/.test(code), false);
});

test("it has its own concurrency group and is not cancelled mid-deploy", () => {
  assert.match(code, /group:\s*rules-deploy/);
  assert.match(code, /cancel-in-progress:\s*false/);
});

test("checkout does not persist credentials", () => {
  assert.match(code, /persist-credentials:\s*false/);
});
