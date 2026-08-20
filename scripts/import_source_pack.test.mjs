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

// ── Field-schema tests ─────────────────────────────────────────────────
//
// The importer used to build its document from a hand-written literal, so
// every field a pack gained later was dropped in silence: `ritualKey` and
// `appliesToZoneKeys` (which stop the Talbiyah being pinned to one miqat)
// and the whole Quranic provenance block. These tests compare the real pack
// against the real output, field by field, so the same class of loss cannot
// recur without a red test.

import { readFileSync } from "node:fs";
import { KNOWN_PACK_FIELDS, buildRecords } from "./import_source_pack.mjs";

const realPack = JSON.parse(
  readFileSync("source_packs/moia_mukhtasar_1446_umrah.json", "utf8"),
);

// Fields the pack carries but the importer deliberately overrides.
const FORCED = new Set([
  "verificationStatus", "verifiedAt", "verifiedBy", "revokedAt",
  "audioMode", "audioUrl", "usage_count",
]);

test("no known field of any record is dropped on import", () => {
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));

  const missing = [];
  for (const entry of realPack.entries) {
    const doc = built.get(entry.duaId);
    for (const key of Object.keys(entry)) {
      if (!(key in doc)) missing.push(`${entry.duaId}.${key}`);
    }
  }
  assert.deepEqual(missing, []);
});

test("every non-forced field keeps its exact value, nulls and empties included", () => {
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));

  const changed = [];
  for (const entry of realPack.entries) {
    const doc = built.get(entry.duaId);
    for (const [key, value] of Object.entries(entry)) {
      if (FORCED.has(key)) continue;
      // zoneKey/contentKind/duaId are trimmed strings; compare trimmed.
      const expected = typeof value === "string" ? value.trim() : value;
      const actual = typeof doc[key] === "string" ? doc[key].trim() : doc[key];
      try {
        assert.deepEqual(actual, expected);
      } catch {
        changed.push(`${entry.duaId}.${key}`);
      }
    }
  }
  assert.deepEqual(changed, []);
});

test("the fields that were being dropped are actually present now", () => {
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));

  const talbiyah = built.get("moia-mukhtasar-1446-umrah-talbiyah");
  assert.equal(talbiyah.ritualKey, "ihram");
  assert.deepEqual(talbiyah.appliesToZoneKeys, [
    "miqat_dhul_hulayfah", "miqat_yalamlam", "miqat_qarn_manazil",
  ]);

  const ayah = built.get("moia-1446-maqam-ayah");
  assert.equal(ayah.textAuthority, "مجمع الملك فهد لطباعة المصحف الشريف");
  assert.equal(ayah.textRiwayah, "حفص عن عاصم");
  assert.equal(ayah.textRasm, "الرسم العثماني");
  assert.equal(ayah.textEdition, "KFGQPC Hafs Uthmanic Data v2.0");
  assert.deepEqual(ayah.quranRef, { surah: 2, ayat: [125] });
  assert.equal(ayah.isPortionOfAyah, true);
});

test("an unknown field is refused, not dropped", () => {
  const pack = { entries: [{ ...realPack.entries[0], surpriseField: "x" }] };
  assert.throws(() => buildRecords(pack), /unknown field "surpriseField"/);
});

test("an explicit null survives; a default only applies when absent", () => {
  const base = realPack.entries[0];

  const withNull = buildRecords({
    entries: [{ ...base, contentHash: null, ritualKey: "" }],
  })[0];
  assert.equal(withNull.contentHash, null);
  assert.equal(withNull.ritualKey, "");

  const absent = { ...base };
  delete absent.contentHash;
  delete absent.ritualKey;
  const withDefaults = buildRecords({ entries: [absent] })[0];
  assert.equal(withDefaults.contentHash, null);
  assert.equal(withDefaults.ritualKey, "");
});

test("an empty array is preserved rather than replaced by a default", () => {
  const base = { ...realPack.entries[0], tagsEn: [], appliesToZoneKeys: [] };
  const doc = buildRecords({ entries: [base] })[0];
  assert.deepEqual(doc.tagsEn, []);
  assert.deepEqual(doc.appliesToZoneKeys, []);
});

test("verification fields are forced no matter what the pack claims", () => {
  const doc = buildRecords({
    entries: [{
      ...realPack.entries[0],
      verificationStatus: "verified",
      verifiedBy: "someone",
      verifiedAt: "2026-01-01",
    }],
  })[0];
  assert.equal(doc.verificationStatus, "unverified");
  assert.equal(doc.verifiedBy, null);
  assert.equal(doc.verifiedAt, null);
});

test("appliesToZoneKeys is validated against the known zones", () => {
  assert.throws(
    () => buildRecords({
      entries: [{ ...realPack.entries[0], appliesToZoneKeys: ["nowhere"] }],
    }),
    /unknown "nowhere"/,
  );
  assert.throws(
    () => buildRecords({
      entries: [{ ...realPack.entries[0], appliesToZoneKeys: "mina" }],
    }),
    /must be an array/,
  );
});

test("every field the real pack uses is in the known set", () => {
  const used = new Set(realPack.entries.flatMap((e) => Object.keys(e)));
  const unknown = [...used].filter((k) => !KNOWN_PACK_FIELDS.has(k));
  assert.deepEqual(unknown, []);
});
