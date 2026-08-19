// Guard tests for the source-pack importer's CLI.
//
// These are the tests that matter most in this script: `buildRecords` being
// wrong produces a bad document, but the CLI being wrong writes to the wrong
// COLLECTION — or writes at all when the operator meant to look. Every case
// below runs entirely in-process; none of them can reach a network, because
// resolvePlan/assertConfirmations do not perform I/O.

import { test } from "node:test";
import assert from "node:assert/strict";

import {
  PRODUCTION_COLLECTION,
  STAGING_COLLECTION,
  assertConfirmations,
  resolvePlan,
} from "./import_source_pack.mjs";

const PACK = "source_packs/moia_mukhtasar_1446_umrah.json";
const ENV = {
  FIREBASE_PROJECT_ID: "dhakker-test",
  FIREBASE_ADMIN_TOKEN: "token-abc",
};

test("dry run is the default — no flags means no write", () => {
  const plan = resolvePlan([PACK], ENV);
  assert.equal(plan.mode, "dry-run");
});

test("dry run does not read credentials at all", () => {
  // No env passed: a dry run must still work, proving it needs no secrets.
  const plan = resolvePlan([PACK], {});
  assert.equal(plan.mode, "dry-run");
  assert.equal(plan.projectId, undefined);
  assert.equal(plan.token, undefined);
});

test("--dry-run is just an explicit spelling of the default", () => {
  assert.equal(resolvePlan([PACK, "--dry-run"], ENV).mode, "dry-run");
});

test("naming a destination without --write still does not write", () => {
  for (const dest of ["--staging", "--production"]) {
    const plan = resolvePlan([PACK, dest], ENV);
    assert.equal(plan.mode, "dry-run", dest);
  }
});

test("--write demands an explicit destination", () => {
  assert.throws(
    () => resolvePlan([PACK, "--write"], ENV),
    /explicit destination/,
  );
});

test("destinations are fixed constants, never taken from input", () => {
  assert.equal(
    resolvePlan([PACK, "--staging", "--write", "--confirm-project=x"], ENV)
      .collection,
    STAGING_COLLECTION,
  );
  assert.equal(
    resolvePlan([PACK, "--production", "--write", "--confirm-project=x"], ENV)
      .collection,
    PRODUCTION_COLLECTION,
  );
  assert.equal(STAGING_COLLECTION, "supplications_staging");
  assert.equal(PRODUCTION_COLLECTION, "supplications");
});

test("the two destinations are mutually exclusive", () => {
  assert.throws(
    () => resolvePlan([PACK, "--staging", "--production", "--write"], ENV),
    /mutually exclusive/,
  );
});

test("--limit is refused against production", () => {
  assert.throws(
    () => resolvePlan([PACK, "--production", "--limit", "1", "--write"], ENV),
    /--limit cannot be used with --production/,
  );
});

test("--limit requires staging, not just the absence of production", () => {
  assert.throws(
    () => resolvePlan([PACK, "--limit", "1"], ENV),
    /only meaningful with --staging/,
  );
});

test("--limit must be a positive integer", () => {
  for (const bad of ["0", "-1", "abc", "1.5"]) {
    assert.throws(
      () => resolvePlan([PACK, "--staging", "--limit", bad], ENV),
      /positive integer/,
      bad,
    );
  }
});

test("staging with --limit 1 is the intended single-record trial", () => {
  const plan = resolvePlan(
    [PACK, "--staging", "--limit", "1", "--write", "--confirm-project=x"],
    ENV,
  );
  assert.equal(plan.mode, "write");
  assert.equal(plan.collection, STAGING_COLLECTION);
  assert.equal(plan.limit, 1);
});

test("a write without credentials is refused", () => {
  assert.throws(
    () => resolvePlan([PACK, "--staging", "--write"], {}),
    /FIREBASE_PROJECT_ID and FIREBASE_ADMIN_TOKEN/,
  );
});

test("an unknown flag is refused rather than ignored", () => {
  // A typo'd guard flag must not silently degrade into a permissive run.
  assert.throws(() => resolvePlan([PACK, "--stagin"], ENV), /Unknown flag/);
  assert.throws(() => resolvePlan([PACK, "--force"], ENV), /Unknown flag/);
});

test("the database is always the default one", () => {
  const plan = resolvePlan(
    [PACK, "--staging", "--write", "--confirm-project=x"],
    ENV,
  );
  assert.equal(plan.database, "(default)");
});

test("confirmations must match the project and the record count", () => {
  const base = [PACK, "--staging", "--write"];

  const wrongProject = resolvePlan(
    [...base, "--confirm-project=other", "--confirm-count=5"],
    ENV,
  );
  assert.throws(() => assertConfirmations(wrongProject, 5), /confirm-project/);

  const wrongCount = resolvePlan(
    [...base, "--confirm-project=dhakker-test", "--confirm-count=4"],
    ENV,
  );
  assert.throws(() => assertConfirmations(wrongCount, 5), /confirm-count/);

  const missing = resolvePlan([...base, "--confirm-project=dhakker-test"], ENV);
  assert.throws(() => assertConfirmations(missing, 5), /confirm-count/);

  const ok = resolvePlan(
    [...base, "--confirm-project=dhakker-test", "--confirm-count=5"],
    ENV,
  );
  assert.doesNotThrow(() => assertConfirmations(ok, 5));
});

test("confirmations are checked against the LIMITED count, not the pack", () => {
  // --limit 1 means one record is written, so the operator confirms 1.
  const plan = resolvePlan(
    [
      PACK,
      "--staging",
      "--limit",
      "1",
      "--write",
      "--confirm-project=dhakker-test",
      "--confirm-count=1",
    ],
    ENV,
  );
  assert.doesNotThrow(() => assertConfirmations(plan, 1));
  assert.throws(() => assertConfirmations(plan, 85), /confirm-count/);
});
