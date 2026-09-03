// Static validation of the legacy-retirement workflow's safety gates.
//
// This is the only workflow in the repository that can DELETE a production
// document. Its claims are: it deletes only what the manifest names, only
// after an archive copy has been made and verified, only by hand, and never
// anything in Cloud Storage.
//
// The ordering and allowlist claims are enforced by the tool and asserted in
// scripts/retire_legacy_records.test.mjs. The Storage claim is enforced by
// IAM. This suite is the layer that catches an edit to the FILE — one that
// adds a `push:` trigger, unpins an action, reaches for a Storage API, or
// arranges for `--execute` without the operator asking for it.

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const PATH = ".github/workflows/legacy-retirement.yml";
const wf = readFileSync(PATH, "utf8");

// Comments stripped: a rule that exists only in prose cannot satisfy a test
// about behaviour.
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
  ]) {
    assert.ok(
      !new RegExp(`^ {2}${trigger}:`, "m").test(code),
      `a ${trigger} trigger would let this delete without a person asking`,
    );
  }
});

test("it runs only from main", () => {
  assert.match(code, /github\.ref/);
  assert.match(code, /refs\/heads\/main/);
  assert.match(code, /exit 1/);
});

test("it runs in its own protected environment, not staging or read-only", () => {
  assert.match(code, /^ {4}environment: firebase-legacy-retirement$/m);
  assert.ok(!code.includes("environment: firebase-staging"));
  assert.ok(!code.includes("environment: firebase-production-readonly"));
});

test("all four confirmations are checked, and before authentication", () => {
  for (const literal of [
    "dhakker-160d0",
    "supplications",
    "16",
    "RETIRE_LEGACY_RECORDS",
  ]) {
    assert.ok(code.includes(literal), `confirmation literal missing: ${literal}`);
  }
  const confirmAt = code.indexOf("Verify manual confirmations");
  const authAt = code.indexOf("google-github-actions/auth@");
  assert.ok(confirmAt > 0 && authAt > 0);
  assert.ok(confirmAt < authAt, "confirmations must be checked before a token exists");
});

test("the guard tests and the manifest check run before authentication", () => {
  const guardAt = code.indexOf("scripts/retire_legacy_records.test.mjs");
  const manifestAt = code.indexOf("loadManifest");
  const authAt = code.indexOf("google-github-actions/auth@");
  assert.ok(guardAt > 0, "the tool's guard tests are not re-run");
  assert.ok(manifestAt > 0, "the manifest is not validated");
  assert.ok(guardAt < authAt, "guard tests must pass before a credential is minted");
  assert.ok(manifestAt < authAt, "the manifest must be validated before a credential is minted");
});

test("dry run is the default and --execute is gated on the operator's input", () => {
  assert.match(code, /default: false/);
  // The tool's own confirmation is only supplied when execute is true, so a
  // dry run cannot silently become a real one.
  assert.match(code, /CONFIRM_RETIREMENT: \$\{\{ inputs\.execute && 'RETIRE_LEGACY_RECORDS' \|\| '' \}\}/);
  assert.match(code, /if \[ "\$EXECUTE" = "true" \]; then/);
});

test("archive and delete are separate dispatches, never one run", () => {
  assert.match(code, /^ {6}phase:/m);
  assert.match(code, /- archive/m);
  assert.match(code, /- delete/m);
  // One --phase flag, built from the input. No step runs both.
  const phaseFlags = [...code.matchAll(/--phase=/g)];
  assert.equal(phaseFlags.length, 1, "the workflow builds more than one phase flag");
  assert.ok(!code.includes("--phase=archive --phase=delete"));
});

test("it never names Cloud Storage in any form", () => {
  // Hosts and client libraries must not appear anywhere at all, comments
  // included — there is no legitimate reason to write one down here.
  for (const token of [
    "storage.googleapis.com",
    "firebasestorage",
    "gsutil",
    "@google-cloud/storage",
    "firebase-admin/storage",
  ]) {
    assert.ok(!wf.includes(token), `the workflow references ${token}`);
  }
  // These may be DISCUSSED in the comments — the auth block explains that
  // the account deliberately holds no Storage role — but must never appear
  // in an executable line.
  for (const token of ["roles/storage", "gcloud storage"]) {
    assert.ok(!code.includes(token), `an executable line references ${token}`);
  }
});

test("it deploys nothing and touches no other collection", () => {
  for (const token of [
    "firebase deploy",
    "firestore:rules",
    "firestore:indexes",
    "wrangler",
    "supplications_staging",
    "import_source_pack",
    "--write",
    "--production",
  ]) {
    assert.ok(!code.includes(token), `the workflow references ${token}`);
  }
});

test("the workflow cannot name a destination collection at all", () => {
  // `supplications` appears once, as the literal the operator must type to
  // confirm the SOURCE. The archive is never named in an executable line:
  // it is a frozen constant in the tool and a declared field in the
  // manifest, both of which loadManifest cross-checks. So there is no line
  // here to edit in order to send the copies somewhere else — or to point
  // the deletion at a different collection.
  const collections = new Set(
    [...code.matchAll(/supplications[a-z_]*/g)].map((m) => m[0]),
  );
  assert.deepEqual([...collections], ["supplications"]);
  assert.ok(
    !code.includes("supplications_legacy_archive"),
    "the archive collection became editable from the workflow file",
  );
});

test("permissions are minimal", () => {
  assert.match(code, /^permissions:\s*$/m);
  assert.match(code, /^ {2}contents: read$/m);
  assert.match(code, /^ {2}id-token: write$/m);
  for (const perm of ["packages:", "deployments:", "issues:", "pull-requests:", "actions: write"]) {
    assert.ok(!code.includes(perm), `unnecessary permission: ${perm}`);
  }
  assert.ok(!code.includes("contents: write"));
});

test("it does not use the read-only reconcile account, and says so", () => {
  assert.match(code, /FIREBASE_RETIREMENT_SERVICE_ACCOUNT/);
  assert.match(code, /service_account: \$\{\{ vars\.FIREBASE_RETIREMENT_SERVICE_ACCOUNT \}\}/);
  // And it refuses at runtime if the two were configured to the same value.
  assert.match(code, /RETIREMENT_SERVICE_ACCOUNT" = "\$READER_SERVICE_ACCOUNT/);
});

test("no JSON service-account key is requested or written to disk", () => {
  assert.match(code, /create_credentials_file: false/);
  assert.match(code, /export_environment_variables: false/);
  for (const token of ["credentials_json", "GOOGLE_APPLICATION_CREDENTIALS", "private_key", "secrets.GCP_SA_KEY"]) {
    assert.ok(!code.includes(token), `the workflow references ${token}`);
  }
});

test("the access token is short-lived", () => {
  const m = code.match(/access_token_lifetime: (\d+)s/);
  assert.ok(m, "no token lifetime is set");
  assert.ok(Number(m[1]) <= 900, `token lifetime ${m[1]}s is too long`);
});

test("every third-party action is pinned to a commit SHA", () => {
  const uses = [...code.matchAll(/uses: (\S+)/g)].map((m) => m[1]);
  assert.ok(uses.length >= 3, "expected checkout, setup-node and auth");
  for (const u of uses) {
    assert.match(u, /@[0-9a-f]{40}$/, `${u} is not pinned to a full commit SHA`);
  }
});

test("the job summary filter cannot carry a field value", () => {
  // The tool logs ids, actions and field NAMES. The filter must not widen
  // that: no line of raw document content may reach a public summary.
  assert.match(code, /grep -E '\^\(Legacy\|Mode:\|Source:\|Archive:\|Manifest:\|Storage:\|Verifying\|Re-verifying\|  \[a-z\]\|\[0-9\]\+ document\|No document\|Every one\|Dry run\)'/);
});

test("the run asserts the tool declared Storage untouched", () => {
  assert.match(code, /grep -q "Storage:   NOT CONTACTED" retirement\.log/);
});

test("it has its own concurrency group and does not cancel itself", () => {
  assert.match(code, /^ {2}group: legacy-retirement$/m);
  assert.match(code, /^ {2}cancel-in-progress: false$/m);
});

test("no automatic retry of a delete", () => {
  for (const token of ["retry", "continue-on-error: true", "max-attempts", "|| node scripts/retire"]) {
    assert.ok(!code.includes(token), `the workflow contains ${token}`);
  }
});

// The tool and the workflow must agree about the collections, or the file's
// confirmations are guarding something other than what runs.
test("the workflow's collections are the ones the tool is compiled with", async () => {
  const { SOURCE_COLLECTION, ARCHIVE_COLLECTION, PHASES } = await import(
    "../../scripts/retire_legacy_records.mjs"
  );
  assert.equal(SOURCE_COLLECTION, "supplications");
  assert.equal(ARCHIVE_COLLECTION, "supplications_legacy_archive");
  // The source is what the operator confirms by typing; the archive is
  // documented here and fixed in the tool.
  assert.ok(code.includes(SOURCE_COLLECTION));
  assert.ok(wf.includes(ARCHIVE_COLLECTION));
  for (const p of PHASES) assert.ok(code.includes(`- ${p}`), `phase ${p} is not offered`);

  // And the manifest declares the same pair, which loadManifest enforces.
  const manifest = JSON.parse(readFileSync("review/legacy_retirement_manifest.json", "utf8"));
  assert.equal(manifest.sourceCollection, SOURCE_COLLECTION);
  assert.equal(manifest.archiveCollection, ARCHIVE_COLLECTION);
});

test("the archive collection is denied to every client in firestore.rules", () => {
  const rules = readFileSync("firestore.rules", "utf8");
  assert.match(
    rules,
    /match \/supplications_legacy_archive\/\{document=\*\*\} \{\s*\n\s*allow read, write: if false;/,
  );
});

test("the workflow passes only arguments the tool accepts", async () => {
  const { KNOWN_ARGUMENTS } = await import("../../scripts/retire_legacy_records.mjs");
  // The tool now exits 1 on any unrecognised argument, so a workflow that
  // built one would fail every run. Catch it here instead of at 3am.
  const flagLines = code
    .split("\n")
    .filter((l) => l.includes('FLAGS+=("') || l.includes('FLAGS=("'));
  assert.ok(flagLines.length > 0, "no flag construction found");
  for (const line of flagLines) {
    const flag = line.match(/FLAGS\+?=\("([^"]+)"\)/)?.[1];
    assert.ok(flag, `could not read the flag from: ${line.trim()}`);
    const accepted =
      flag === "--execute" || /^--phase=\$?[A-Za-z_{}]+$/.test(flag);
    assert.ok(accepted, `the workflow builds an argument the tool rejects: ${flag}`);
  }
  assert.deepEqual([...KNOWN_ARGUMENTS], ["--phase=<archive|delete>", "--execute"]);
});
