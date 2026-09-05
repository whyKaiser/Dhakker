// Guard tests for the source-pack importer's CLI.
//
// These are the tests that matter most in this script: `buildRecords` being
// wrong produces a bad document, but the CLI being wrong writes to the wrong
// COLLECTION — or writes at all when the operator meant to look. Every case
// below runs entirely in-process; none of them can reach a network, because
// resolvePlan/assertConfirmations do not perform I/O.

import { test } from "node:test";
import assert from "node:assert/strict";
import childProcess from "node:child_process";

import {
  CREATE_ONLY_DEFAULT_FIELDS,
  PACK_OWNED_FIELDS,
  PRODUCTION_BLOCKING_CASES,
  PRODUCTION_COLLECTION,
  STAGING_COLLECTION,
  UPDATE_MASK_FIELDS,
  VERIFICATION_RESET_FIELDS,
  buildWriteRequest,
  canonical,
  changedPackFields,
  normalisedTextHash,
  safeDecodeId,
  assertConfirmations,
  assertReconciledForProduction,
  listCollection,
  printReconcile,
  reconcile,
  resolvePlan,
  verifyWritten,
  writeRecords,
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

// ── usageQualifier ──────────────────────────────────────────────────────
//
// The field exists so an optional addition can be labelled as one. It must
// survive import intact, and — just as importantly — its ABSENCE must
// survive too: a record the source did not qualify may not acquire a
// default that reads as an obligation.

import { SUPPORTED_USAGE_QUALIFIERS } from "./import_source_pack.mjs";

const TALBIYAH = "moia-mukhtasar-1446-umrah-talbiyah";
const ZIYADAH = "moia-mukhtasar-1446-umrah-talbiyah-ziyadah";

test("usageQualifier reaches the imported document", () => {
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));
  assert.equal(built.get(ZIYADAH).usageQualifier, "optional_addition");
});

test("an unqualified record imports as null, never as a mandatory value", () => {
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));
  const base = built.get(TALBIYAH);
  assert.ok("usageQualifier" in base, "the key must be written explicitly");
  assert.equal(base.usageQualifier, null);

  // Nothing anywhere in the pipeline may invent an opposing value.
  for (const doc of built.values()) {
    assert.ok(
      doc.usageQualifier === null ||
        SUPPORTED_USAGE_QUALIFIERS.includes(doc.usageQualifier),
      `${doc.duaId} carries an unsupported qualifier`,
    );
  }
});

test("mandatory is not a supported qualifier, and must not become one", () => {
  assert.deepEqual(SUPPORTED_USAGE_QUALIFIERS, ["optional_addition"]);
  for (const bad of ["mandatory", "required", "obligatory"]) {
    assert.throws(
      () => buildRecords({
        entries: [{ ...realPack.entries[0], usageQualifier: bad }],
      }),
      /unknown usageQualifier/,
      `${bad} must be refused`,
    );
  }
});

test("a non-string qualifier is refused rather than coerced", () => {
  assert.throws(
    () => buildRecords({
      entries: [{ ...realPack.entries[0], usageQualifier: true }],
    }),
    /must be a string or null/,
  );
});

test("an explicit null qualifier is preserved, not defaulted away", () => {
  const [doc] = buildRecords({
    entries: [{ ...realPack.entries[0], usageQualifier: null }],
  });
  assert.equal(doc.usageQualifier, null);
});

test("the Talbiyah keeps its ritual scope and its empty zoneKey", () => {
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));
  for (const id of [TALBIYAH, ZIYADAH]) {
    const doc = built.get(id);
    // Pinning it to one miqat would hide it from the other two; this is the
    // pairing that keeps it reachable from all three without being tied to
    // any of them.
    assert.equal(doc.zoneKey, "", `${id} must not be pinned to a place`);
    assert.equal(doc.ritualKey, "ihram");
    assert.deepEqual(doc.appliesToZoneKeys, [
      "miqat_dhul_hulayfah",
      "miqat_yalamlam",
      "miqat_qarn_manazil",
    ]);
  }
});

// ── The ledger as an operational gate ───────────────────────────────────
//
// Until this existed the ledger was documentation: it recorded that a record
// must not ship, and nothing stopped an import from shipping it. These tests
// pin the enforcement, because a hold nobody enforces expires the first time
// someone runs an import in a hurry.

import {
  applyLedger,
  assertLedgerMatchesPack,
  contentHashOf,
  loadLedger,
  LEDGER_PATH,
} from "./import_source_pack.mjs";

const G009 = "moia-mukhtasar-1446-general-009";

test("the real ledger holds back exactly what it says it holds back", () => {
  const ledger = loadLedger();
  const { included, excluded } = applyLedger(buildRecords(realPack), ledger);
  const excludedIds = excluded.map((e) => e.duaId).sort();

  // Derived from the ledger rather than pinned to a snapshot: this set grows
  // as records are reviewed, and a test that had to be edited on every review
  // would soon be edited without being read.
  const expected = ledger.reviews
    .filter(
      (r) =>
        r.reviewStatus === "blocked" ||
        r.deploymentBlocked === true ||
        r.excludedFromImport === true,
    )
    .map((r) => r.recordId)
    .sort();
  assert.deepEqual(excludedIds, expected);

  // The two that must never silently drop off it.
  assert.ok(excludedIds.includes(G009));
  assert.ok(excludedIds.includes(ZIYADAH));
  for (const id of [G009, ZIYADAH]) {
    assert.ok(
      !included.some((r) => r.duaId === id),
      `${id} must not be writable while the ledger holds it back`,
    );
  }
  // Every exclusion states why — an unexplained hold outlives its cause.
  for (const e of excluded) assert.ok(e.reasons.length > 0);
});

test("each of the three grounds excludes on its own", () => {
  const records = buildRecords(realPack);
  const one = records[0];
  for (const review of [
    { recordId: one.duaId, reviewStatus: "blocked", blockReason: "x" },
    { recordId: one.duaId, deploymentBlocked: true, deploymentBlockReason: "y" },
    { recordId: one.duaId, excludedFromImport: true },
  ]) {
    const { included, excluded } = applyLedger([one], { reviews: [review] });
    assert.equal(included.length, 0);
    assert.equal(excluded.length, 1);
  }
});

test("a passed record with no hold is still included", () => {
  const one = buildRecords(realPack)[0];
  const { included } = applyLedger([one], {
    reviews: [{ recordId: one.duaId, reviewStatus: "passed" }],
  });
  assert.equal(included.length, 1);
});

test("an unreviewed record is not blocked by the ledger's silence", () => {
  // The ledger says which records must NOT ship. Absence from it is not a
  // hold — otherwise every import would be empty until all 85 are reviewed.
  const one = buildRecords(realPack)[0];
  const { included } = applyLedger([one], { reviews: [] });
  assert.equal(included.length, 1);
});

test("staging --limit 1 still selects the base Talbiyah, not the addition", () => {
  // Exclusion must run BEFORE the slice. If --limit were applied first, the
  // single staging slot could be handed to a record the ledger holds back.
  const { included } = applyLedger(buildRecords(realPack), loadLedger());
  assert.equal(included.slice(0, 1)[0].duaId, "moia-mukhtasar-1446-umrah-talbiyah");
});

test("production refuses to run without a ledger", () => {
  assert.throws(
    () => assertLedgerMatchesPack(null, buildRecords(realPack), { strict: true }),
    new RegExp(LEDGER_PATH.replace(/\//g, "\\/")),
  );
});

test("a dry run tolerates a missing ledger, since it writes nothing", () => {
  assert.doesNotThrow(() =>
    assertLedgerMatchesPack(null, buildRecords(realPack), { strict: false }),
  );
});

test("production refuses a ledger whose hashes no longer match the pack", () => {
  const records = buildRecords(realPack);
  assert.throws(
    () =>
      assertLedgerMatchesPack(
        { reviews: [{ recordId: records[0].duaId, reviewedTextHash: "b".repeat(64) }] },
        records,
        { strict: true },
      ),
    /text changed since review/,
  );
});

test("production refuses a ledger naming a record the pack does not have", () => {
  assert.throws(
    () =>
      assertLedgerMatchesPack(
        { reviews: [{ recordId: "ghost-record", reviewedTextHash: "a".repeat(64) }] },
        buildRecords(realPack),
        { strict: true },
      ),
    /absent from the pack/,
  );
});

test("the real ledger matches the real pack today", () => {
  assert.doesNotThrow(() =>
    assertLedgerMatchesPack(loadLedger(), buildRecords(realPack), { strict: true }),
  );
});

test("contentHashOf agrees with the hashes recorded in the ledger", () => {
  // The same sha256(ar + NUL + en) the admin screen and the Dart suite use.
  // If these three ever diverge, the production gate would reject a pack
  // that is in fact unchanged.
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));
  for (const review of loadLedger().reviews) {
    assert.equal(
      contentHashOf(built.get(review.recordId)),
      review.reviewedTextHash,
      `${review.recordId} hash mismatch`,
    );
  }
});

// ── Production is fail-closed ───────────────────────────────────────────
//
// Staging may write a record nobody has read yet — that is what a trial is
// for. Production may not. The difference is that absence from the ledger
// counts as `unreviewed`, not as `fine`: 83 of 85 records passing the
// staging filter was never a statement that 83 records had been reviewed.

import {
  classifyForProduction,
  assertProductionSetIsClean,
} from "./import_source_pack.mjs";

const prodClass = () => classifyForProduction(buildRecords(realPack), loadLedger());

test("production includes only records the ledger positively cleared", () => {
  const c = prodClass();
  const ledger = loadLedger();
  const cleared = new Set(
    ledger.reviews
      .filter(
        (r) =>
          (r.reviewStatus === "passed" || r.textReviewStatus === "passed") &&
          r.deploymentBlocked !== true &&
          r.excludedFromImport !== true,
      )
      .map((r) => r.recordId),
  );
  assert.deepEqual(
    c.reviewedIncluded.map((r) => r.duaId).sort(),
    [...cleared].sort(),
  );
});

test("every record is accounted for in exactly one bucket", () => {
  const c = prodClass();
  const total =
    c.reviewedIncluded.length +
    c.unreviewedExcluded.length +
    c.blockedExcluded.length +
    c.deploymentHeld.length;
  assert.equal(total, realPack.entries.length);

  const ids = [
    ...c.reviewedIncluded.map((r) => r.duaId),
    ...c.unreviewedExcluded,
    ...c.blockedExcluded,
    ...c.deploymentHeld,
  ];
  assert.equal(new Set(ids).size, ids.length, "a record appears twice");
});

test("general-009 is excluded from production as blocked", () => {
  const c = prodClass();
  assert.ok(c.blockedExcluded.includes(G009));
  assert.ok(!c.reviewedIncluded.some((r) => r.duaId === G009));
});

test("the ziyadah is excluded from production by its deployment hold", () => {
  const c = prodClass();
  // Its TEXT passed. It is held for a product reason, and must be reported
  // in its own bucket rather than lumped in with a text defect.
  assert.ok(c.deploymentHeld.includes(ZIYADAH));
  assert.ok(!c.blockedExcluded.includes(ZIYADAH));
  assert.ok(!c.reviewedIncluded.some((r) => r.duaId === ZIYADAH));
});

test("a record absent from the ledger is unreviewed, not importable", () => {
  const records = buildRecords(realPack);
  const c = classifyForProduction(records, { reviews: [] });
  assert.equal(c.reviewedIncluded.length, 0);
  assert.equal(c.unreviewedExcluded.length, records.length);
});

test("no ledger at all means nothing may be written to production", () => {
  const c = classifyForProduction(buildRecords(realPack), null);
  assert.equal(c.reviewedIncluded.length, 0);
});

test("a ledger entry that is neither passed nor blocked counts as unreviewed", () => {
  const one = buildRecords(realPack)[0];
  const c = classifyForProduction([one], {
    reviews: [{ recordId: one.duaId, reviewStatus: "in_progress" }],
  });
  assert.deepEqual(c.unreviewedExcluded, [one.duaId]);
  assert.equal(c.reviewedIncluded.length, 0);
});

test("no command-line flag can slip a held record past the final guard", () => {
  // Every filter can be bypassed by a flag nobody thought about. This
  // asserts on the final set instead of trusting the filter that built it.
  const records = buildRecords(realPack);
  const c = classifyForProduction(records, loadLedger());
  const smuggled = [
    ...c.reviewedIncluded,
    records.find((r) => r.duaId === G009),
  ];
  assert.throws(
    () => assertProductionSetIsClean(smuggled, c),
    /Refusing to write/,
  );
  assert.throws(
    () =>
      assertProductionSetIsClean(
        [...c.reviewedIncluded, records.find((r) => r.duaId === ZIYADAH)],
        c,
      ),
    new RegExp(ZIYADAH),
  );
  // The clean set passes, so the guard is not simply always throwing.
  assert.doesNotThrow(() => assertProductionSetIsClean(c.reviewedIncluded, c));
});

test("production halts on a page-provenance mismatch, not just a hash one", () => {
  const records = buildRecords(realPack);
  const target = records.find((r) => r.printedPage != null);
  assert.throws(
    () =>
      assertLedgerMatchesPack(
        {
          reviews: [
            {
              recordId: target.duaId,
              reviewedTextHash: contentHashOf(target),
              reviewedPage: target.printedPage + 7,
            },
          ],
        },
        records,
        { strict: true },
      ),
    /reviewed page .* but the record now cites page/,
  );
});

test("imported records are still written unverified", () => {
  // Being reviewed is not being verified. The ledger clears a record for
  // import; an admin verifies it afterwards, in the app.
  for (const r of prodClass().reviewedIncluded) {
    assert.equal(r.verificationStatus, "unverified");
    assert.equal(r.verifiedAt, null);
    assert.equal(r.verifiedBy, null);
  }
});

// ── contextual_evidence ─────────────────────────────────────────────────
//
// A narration cited to teach is neither a supplication nor an instruction.
// The importer must accept the kind and must not let it drift into the
// recitable set, which is what decides whether a play button appears.

import {
  KNOWN_CONTENT_KINDS,
  RECITABLE_CONTENT_KINDS,
} from "./import_source_pack.mjs";

test("contextual_evidence is a known kind but is not recitable", () => {
  assert.ok(KNOWN_CONTENT_KINDS.includes("contextual_evidence"));
  assert.ok(!RECITABLE_CONTENT_KINDS.includes("contextual_evidence"));
  assert.ok(!RECITABLE_CONTENT_KINDS.includes("procedural_guidance"));
  // Everything a pilgrim actually says stays recitable.
  for (const kind of ["specific_text", "general_dua", "general_dhikr", "mosque_entry"]) {
    assert.ok(RECITABLE_CONTENT_KINDS.includes(kind), kind);
  }
});

test("the recitable set is a strict subset of the known kinds", () => {
  for (const kind of RECITABLE_CONTENT_KINDS) {
    assert.ok(KNOWN_CONTENT_KINDS.includes(kind), `${kind} is not a known kind`);
  }
  assert.ok(RECITABLE_CONTENT_KINDS.length < KNOWN_CONTENT_KINDS.length);
});

test("the batch B records import with their reviewed classifications", () => {
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));
  assert.equal(built.get("moia-1446-hajar-tasmiya").contentKind, "specific_text");
  assert.equal(built.get("moia-1446-hajar-umar").contentKind, "contextual_evidence");
  assert.equal(
    built.get("moia-1446-hajar-crowding").contentKind,
    "procedural_guidance",
  );
});

test("B2 and B3 are held out of production; B1 is not", () => {
  const c = classifyForProduction(buildRecords(realPack), loadLedger());
  assert.ok(c.deploymentHeld.includes("moia-1446-hajar-umar"));
  assert.ok(c.deploymentHeld.includes("moia-1446-hajar-crowding"));
  assert.ok(
    c.reviewedIncluded.some((r) => r.duaId === "moia-1446-hajar-tasmiya"),
    "the recitable text of the batch is cleared",
  );
});

test("B1 keeps its full page range in sourceSection", () => {
  const b1 = realPack.entries.find((e) => e.duaId === "moia-1446-hajar-tasmiya");
  assert.match(b1.sourceSection, /65-67/);
  assert.equal(b1.printedPage, 65);
});

// ── sourceReferences validation ─────────────────────────────────────────

import {
  SUPPORTED_REFERENCE_TYPES,
  SUPPORTED_REFERENCE_KINDS,
  validateSourceReferences,
} from "./import_source_pack.mjs";

const goodRef = () => ({
  type: "hadith",
  collection: "صحيح البخاري",
  reference: "1597",
  referenceKind: "hadith_number",
  citedBy: "moia_1446",
  citedOnPage: 66,
});

test("a well-formed reference passes", () => {
  assert.doesNotThrow(() => validateSourceReferences([goodRef()], "e"));
  assert.doesNotThrow(() => validateSourceReferences([], "e"));
  assert.doesNotThrow(() => validateSourceReferences(undefined, "e"));
});

test("every required field is required", () => {
  for (const key of ["type", "collection", "referenceKind", "citedBy", "citedOnPage"]) {
    const r = goodRef();
    delete r[key];
    assert.throws(() => validateSourceReferences([r], "e"), new RegExp(`missing ${key}`));
  }
});

test("an empty reference string is refused outright", () => {
  // "" reads as "we looked and found none". Absent means "the page printed
  // no number". They are different claims.
  for (const bad of ["", "   "]) {
    const r = { ...goodRef(), reference: bad };
    assert.throws(() => validateSourceReferences([r], "e"), /non-empty string, or absent/);
  }
});

test("unspecified must not carry a reference, and vice versa", () => {
  const withBoth = { ...goodRef(), referenceKind: "unspecified" };
  assert.throws(() => validateSourceReferences([withBoth], "e"),
    /must not carry a reference/);

  const numberedButAbsent = goodRef();
  delete numberedButAbsent.reference;
  assert.throws(() => validateSourceReferences([numberedButAbsent], "e"),
    /requires a reference/);

  // The legitimate unnumbered shape.
  const ok = { ...goodRef(), referenceKind: "unspecified" };
  delete ok.reference;
  assert.doesNotThrow(() => validateSourceReferences([ok], "e"));
});

test("unknown types, kinds and fields are refused, never ignored", () => {
  assert.throws(() => validateSourceReferences([{ ...goodRef(), type: "tweet" }], "e"),
    /unknown type/);
  assert.throws(
    () => validateSourceReferences([{ ...goodRef(), referenceKind: "vibes" }], "e"),
    /unknown referenceKind/);
  assert.throws(
    () => validateSourceReferences([{ ...goodRef(), isAuthentic: true }], "e"),
    /unknown field "isAuthentic"/);
});

test("the supported vocabularies are the documented ones", () => {
  assert.deepEqual(SUPPORTED_REFERENCE_TYPES,
    ["hadith", "athar", "quran", "book", "fatwa"]);
  assert.ok(SUPPORTED_REFERENCE_KINDS.includes("unspecified"));
});

test("citedOnPage must be a real page number", () => {
  for (const bad of [0, -1, "66", 66.5, null]) {
    assert.throws(
      () => validateSourceReferences([{ ...goodRef(), citedOnPage: bad }], "e"));
  }
});

test("the real pack's references all import intact", () => {
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));
  const umar = built.get("moia-1446-hajar-umar").sourceReferences;
  assert.equal(umar.length, 2);
  assert.ok(umar.every((r) => r.citedBy === "moia_1446"));

  // All four of hajar-crowding's sources are numbered. Two of them are
  // printed on page 68, as the continuation of footnote (٤) which opens at
  // the foot of 67 — so the importer must carry a citedOnPage that differs
  // from the record's own printedPage without rejecting or rewriting it.
  const crowding = built.get("moia-1446-hajar-crowding").sourceReferences;
  assert.equal(crowding.length, 4);
  assert.equal(crowding.filter((r) => "reference" in r).length, 4);
  assert.ok(crowding.every((r) => r.referenceKind !== "unspecified"));
  assert.deepEqual(
    [...new Set(crowding.map((r) => r.citedOnPage))].sort(),
    [67, 68],
  );

  // The two talbiyah records each carry the one hadith page 59 cites.
  for (const [id, num] of [
    ["moia-mukhtasar-1446-umrah-talbiyah", "1218"],
    ["moia-mukhtasar-1446-umrah-talbiyah-ziyadah", "1184"],
  ]) {
    const refs = built.get(id).sourceReferences;
    assert.equal(refs.length, 1, id);
    assert.equal(refs[0].reference, num, id);
    assert.equal(refs[0].collection, "صحيح مسلم", id);
    assert.equal(refs[0].citedOnPage, 59, id);
  }

  // A record nobody cited keeps an explicit empty array.
  assert.deepEqual(built.get("moia-mukhtasar-1446-tawaf-takbir-hajar").sourceReferences, []);
});

test("references do not make a record importable to production", () => {
  // Citations are provenance, not clearance.
  const c = classifyForProduction(buildRecords(realPack), loadLedger());
  for (const id of ["moia-1446-hajar-umar", "moia-1446-hajar-crowding"]) {
    assert.ok(c.deploymentHeld.includes(id), `${id} must still be held`);
  }
});

test("the two reclassified Batch C records are held out of production", () => {
  const c = classifyForProduction(buildRecords(realPack), loadLedger());
  for (const id of ["moia-1446-hijr-not-valid", "moia-1446-maqam-rakatayn"]) {
    assert.ok(c.deploymentHeld.includes(id));
  }
  // The one whose classification did not change is cleared.
  assert.ok(
    c.reviewedIncluded.some((r) => r.duaId === "moia-mukhtasar-1446-tawaf-takbir-hajar"),
  );
});

// ── recitationPolicy validation ─────────────────────────────────────────

import {
  SUPPORTED_FREQUENCIES,
  SUPPORTED_TRIGGERS,
  SUPPORTED_INTERLEAVES,
  validateRecitationPolicy,
} from "./import_source_pack.mjs";

const once = () => ({
  frequency: "once_per_ritual",
  trigger: "first_safa_approach",
  // Required alongside that trigger: the app has no event for it.
  autoPlayCapability: "manual_only_until_trigger_supported",
  autoRepeat: false,
});
const thrice = () => ({
  frequency: "repeat_count",
  repeatCount: 3,
  interleave: "personal_dua",
  autoPlayCapability: "manual_only_until_trigger_supported",
  autoRepeat: false,
});

test("the two real policies validate", () => {
  assert.doesNotThrow(() => validateRecitationPolicy(once(), "e"));
  assert.doesNotThrow(() => validateRecitationPolicy(thrice(), "e"));
  assert.doesNotThrow(() => validateRecitationPolicy(null, "e"));
  assert.doesNotThrow(() => validateRecitationPolicy(undefined, "e"));
});

test("there is no mandatory frequency", () => {
  assert.deepEqual(SUPPORTED_FREQUENCIES, ["once_per_ritual", "repeat_count"]);
  for (const bad of ["mandatory", "required", "always", ""]) {
    assert.throws(
      () => validateRecitationPolicy({ frequency: bad }, "e"),
      /frequency must be one of/,
    );
  }
});

test("repeatCount belongs only to repeat_count, and only 1-10", () => {
  assert.throws(
    () => validateRecitationPolicy({ ...once(), repeatCount: 3 }, "e"),
    /belongs only with/,
  );
  for (const n of [0, 11, -1, 2.5, "3", null, undefined]) {
    assert.throws(
      () => validateRecitationPolicy(
        { frequency: "repeat_count", repeatCount: n }, "e"),
      /repeatCount must be an integer 1-10/,
      `repeatCount ${n}`,
    );
  }
});

test("trigger and interleave accept only declared values", () => {
  assert.throws(
    () => validateRecitationPolicy({ ...once(), trigger: "whenever" }, "e"),
    /unknown recitationPolicy.trigger/,
  );
  assert.throws(
    () => validateRecitationPolicy({ ...thrice(), interleave: "a_song" }, "e"),
    /unknown recitationPolicy.interleave/,
  );
  assert.ok(SUPPORTED_TRIGGERS.includes("first_safa_approach"));
  assert.deepEqual(SUPPORTED_INTERLEAVES, ["personal_dua"]);
});

test("autoRepeat must stay false when an interleave is present", () => {
  // A repetition the pilgrim fills with their own dua cannot be performed
  // for them by a player.
  assert.throws(
    () => validateRecitationPolicy({ ...thrice(), autoRepeat: true }, "e"),
    /autoRepeat must stay false/,
  );
  // Without an interleave it is merely a boolean.
  assert.doesNotThrow(() => validateRecitationPolicy(
    { frequency: "repeat_count", repeatCount: 3, autoRepeat: true }, "e"));
});

test("unknown policy fields are refused, never ignored", () => {
  assert.throws(
    () => validateRecitationPolicy({ ...once(), mandatory: true }, "e"),
    /unknown field "mandatory"/,
  );
  assert.throws(
    () => validateRecitationPolicy([], "e"),
    /must be an object or null/,
  );
});

test("the pack's policies import intact", () => {
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));
  assert.deepEqual(built.get("moia-1446-safa-ayah").recitationPolicy, {
    frequency: "once_per_ritual",
    trigger: "first_safa_approach",
    autoPlayCapability: "manual_only_until_trigger_supported",
    autoRepeat: false,
  });
  assert.deepEqual(built.get("moia-1446-safa-dhikr").recitationPolicy, {
    frequency: "repeat_count",
    repeatCount: 3,
    interleave: "personal_dua",
    autoPlayCapability: "manual_only_until_trigger_supported",
    autoRepeat: false,
  });
  // A record the source did not qualify keeps an explicit null.
  assert.equal(built.get("moia-1446-return-hajar").recitationPolicy, null);
});

test("Batch D records stay out of production", () => {
  const c = classifyForProduction(buildRecords(realPack), loadLedger());
  for (const id of [
    "moia-1446-return-hajar",
    "moia-1446-safa-ayah",
    "moia-1446-safa-dhikr",
  ]) {
    assert.ok(c.deploymentHeld.includes(id), `${id} must be held`);
  }
});

test("a policy does not make a record importable", () => {
  // Provenance and performance are different axes; neither is clearance.
  const c = classifyForProduction(buildRecords(realPack), loadLedger());
  assert.ok(!c.reviewedIncluded.some((r) => r.duaId === "moia-1446-safa-dhikr"));
});

// ── autoPlayCapability: the importer is strict, clients are lenient ─────
//
// These two behaviours are deliberately different and must not be conflated:
//
//   IMPORTER — an unknown value is a HARD ERROR. A pack is authored by us;
//   a typo there is a mistake to surface now, not to ship.
//   CLIENT   — an unknown value is IGNORED. An older app must keep working
//   when a newer pack adds a value it has never heard of.
//
// "Unknown values are read as no policy" is true of clients ONLY.

import { SUPPORTED_AUTOPLAY_CAPABILITIES } from "./import_source_pack.mjs";

test("the importer rejects every unknown frequency, trigger and interleave", () => {
  for (const bad of ["mandatory", "sometimes", "ONCE_PER_RITUAL", " "]) {
    assert.throws(
      () => validateRecitationPolicy({ frequency: bad }, "e"),
      /frequency must be one of/,
      `frequency ${bad}`,
    );
  }
  for (const bad of ["on_arrival", "first_safa", "FIRST_SAFA_APPROACH"]) {
    assert.throws(
      () => validateRecitationPolicy(
        { frequency: "once_per_ritual", trigger: bad }, "e"),
      /unknown recitationPolicy.trigger/,
      `trigger ${bad}`,
    );
  }
  for (const bad of ["a_song", "silence", "PERSONAL_DUA"]) {
    assert.throws(
      () => validateRecitationPolicy(
        { frequency: "repeat_count", repeatCount: 3, interleave: bad }, "e"),
      /unknown recitationPolicy.interleave/,
      `interleave ${bad}`,
    );
  }
});

test("the importer rejects an unknown autoPlayCapability", () => {
  assert.deepEqual(SUPPORTED_AUTOPLAY_CAPABILITIES,
    ["manual_only_until_trigger_supported"]);
  assert.throws(
    () => validateRecitationPolicy(
      { frequency: "once_per_ritual", autoPlayCapability: "always" }, "e"),
    /unknown recitationPolicy.autoPlayCapability/,
  );
});

test("a trigger with no supporting event must declare manual-only", () => {
  // The gap this closes: declaring `first_safa_approach` while leaving
  // auto-play enabled would have the app fire on the nearest coarse event it
  // has — entering the whole Sa'i corridor — and call that the trigger the
  // source named.
  assert.throws(
    () => validateRecitationPolicy(
      { frequency: "once_per_ritual", trigger: "first_safa_approach" }, "e"),
    /has no supporting event/,
  );
  assert.doesNotThrow(() => validateRecitationPolicy({
    frequency: "once_per_ritual",
    trigger: "first_safa_approach",
    autoPlayCapability: "manual_only_until_trigger_supported",
  }, "e"));
});

test("both Safa records declare manual-only in the real pack", () => {
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));
  for (const id of ["moia-1446-safa-ayah", "moia-1446-safa-dhikr"]) {
    assert.equal(
      built.get(id).recitationPolicy.autoPlayCapability,
      "manual_only_until_trigger_supported",
      id,
    );
  }
});

// ---------------------------------------------------------------------------
// relatedRecordIds — the Marwah guidance points at the canonical Safa dhikr
// rather than repeating it. The importer is STRICT about the pointer for one
// reason: a dangling reference would show the pilgrim an instruction to say
// something the app can no longer show them. Clients are lenient with unknown
// VALUES (a restriction they cannot honour reads as absent); they are never
// lenient about a pointer, and neither is this.
// ---------------------------------------------------------------------------

const marwahIndex = () =>
  realPack.entries.findIndex((e) => e.duaId === "moia-1446-marwah-same");

function packWithMarwah(patch) {
  const entries = realPack.entries.map((e) =>
    e.duaId === "moia-1446-marwah-same" ? { ...e, ...patch } : e,
  );
  return { ...realPack, entries };
}

test("the real pack's Marwah pointer resolves to the canonical dhikr", () => {
  assert.ok(marwahIndex() >= 0);
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));
  assert.deepEqual(built.get("moia-1446-marwah-same").relatedRecordIds, [
    "moia-1446-safa-dhikr",
  ]);
  // And the target really is in the pack, recitable, and unduplicated.
  assert.ok(built.has("moia-1446-safa-dhikr"));
  assert.equal(built.get("moia-1446-safa-dhikr").contentKind, "specific_text");
});

test("a relatedRecordId absent from the pack is refused", () => {
  assert.throws(
    () => buildRecords(packWithMarwah({ relatedRecordIds: ["no-such-record"] })),
    /relatedRecordId "no-such-record" is not present in this pack/,
  );
});

test("a self-reference is refused", () => {
  assert.throws(
    () =>
      buildRecords(
        packWithMarwah({ relatedRecordIds: ["moia-1446-marwah-same"] }),
      ),
    /must not reference itself/,
  );
});

test("a duplicated relatedRecordId is refused", () => {
  assert.throws(
    () =>
      buildRecords(
        packWithMarwah({
          relatedRecordIds: ["moia-1446-safa-dhikr", "moia-1446-safa-dhikr"],
        }),
      ),
    /duplicate relatedRecordId/,
  );
});

test("relatedRecordIds must be an array of non-empty strings", () => {
  assert.throws(
    () => buildRecords(packWithMarwah({ relatedRecordIds: "safa" })),
    /relatedRecordIds must be an array/,
  );
  assert.throws(
    () => buildRecords(packWithMarwah({ relatedRecordIds: ["  "] })),
    /must be non-empty strings/,
  );
});

test("a relationship does not make the pointing record recitable", () => {
  // The pointer is a display hint. Nothing about it may change what the
  // record IS — that is contentKind's job and stays contentKind's job.
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));
  const marwah = built.get("moia-1446-marwah-same");
  assert.equal(marwah.contentKind, "procedural_guidance");
  assert.equal(marwah.verificationStatus, "unverified");
});

test("an empty usageNoteAr is refused — omit the field instead", () => {
  assert.throws(
    () => buildRecords(packWithMarwah({ usageNoteAr: "   " })),
    /usageNoteAr must not be empty/,
  );
  assert.throws(
    () => buildRecords(packWithMarwah({ usageNoteAr: 7 })),
    /usageNoteAr must be a string/,
  );
});

test("omitting the optional fields entirely is fine", () => {
  const entry = { ...realPack.entries[marwahIndex()] };
  delete entry.relatedRecordIds;
  delete entry.usageNoteAr;
  const entries = realPack.entries.map((e) =>
    e.duaId === "moia-1446-marwah-same" ? entry : e,
  );
  const built = new Map(buildRecords({ ...realPack, entries }).map((r) => [r.duaId, r]));
  assert.deepEqual(built.get("moia-1446-marwah-same").relatedRecordIds, []);
  assert.equal(built.get("moia-1446-marwah-same").usageNoteAr, "");
});

test("every record in the real pack still imports as unverified", () => {
  const built = buildRecords(realPack);
  assert.equal(built.length, 85);
  for (const r of built) {
    assert.equal(r.verificationStatus, "unverified", r.duaId);
    assert.equal(r.verifiedAt, null, r.duaId);
    assert.equal(r.verifiedBy, null, r.duaId);
  }
});

// ---------------------------------------------------------------------------
// A recitation_link must land on something the pilgrim can actually say.
// Pointing one at guidance would put "say the like of what was said there"
// on a card that has no recitation and no play button — an arrow to a dead
// end, dressed as an instruction.
// ---------------------------------------------------------------------------

test("a recitation_link pointing at guidance is refused", () => {
  // moia-1446-sai-seven is procedural_guidance in the real pack.
  const guidance = realPack.entries.find(
    (e) => e.duaId === "moia-1446-sai-seven",
  );
  assert.equal(guidance.contentKind, "procedural_guidance");

  assert.throws(
    () =>
      buildRecords(
        packWithMarwah({
          relatedRecordIds: ["moia-1446-sai-seven"],
          relatedRecordRole: "recitation_link",
        }),
      ),
    /is not recitable — a recitation_link must point at a text the pilgrim may say/,
  );
});

test("a recitation_link pointing at contextual evidence is refused too", () => {
  const evidence = realPack.entries.find(
    (e) => e.contentKind === "contextual_evidence",
  );
  assert.ok(evidence, "the pack should contain contextual evidence");
  assert.throws(
    () =>
      buildRecords(
        packWithMarwah({
          relatedRecordIds: [evidence.duaId],
          relatedRecordRole: "recitation_link",
        }),
      ),
    /is not recitable/,
  );
});

test("the real pack's recitation_link points at a recitable target", () => {
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));
  const marwah = built.get("moia-1446-marwah-same");
  assert.equal(marwah.relatedRecordRole, "recitation_link");
  assert.deepEqual(marwah.relatedRecordIds, ["moia-1446-safa-dhikr"]);
  const target = built.get("moia-1446-safa-dhikr");
  assert.ok(RECITABLE_CONTENT_KINDS.includes(target.contentKind));
});

test("a pointer with no declared role is refused", () => {
  const entries = realPack.entries.map((e) =>
    e.duaId === "moia-1446-marwah-same"
      ? (() => {
          const copy = { ...e, relatedRecordIds: ["moia-1446-safa-dhikr"] };
          delete copy.relatedRecordRole;
          return copy;
        })()
      : e,
  );
  assert.throws(
    () => buildRecords({ ...realPack, entries }),
    /relatedRecordIds requires a relatedRecordRole/,
  );
});

test("an unknown relatedRecordRole is refused", () => {
  assert.throws(
    () => buildRecords(packWithMarwah({ relatedRecordRole: "teleport" })),
    /unknown relatedRecordRole "teleport"/,
  );
});

test("the link never changes the target's own policy", () => {
  // The pointer navigates. The target keeps its manual-only capability and
  // its repeat instruction — a guidance card cannot borrow a play button.
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));
  const target = built.get("moia-1446-safa-dhikr");
  assert.equal(
    target.recitationPolicy.autoPlayCapability,
    "manual_only_until_trigger_supported",
  );
  assert.equal(target.recitationPolicy.repeatCount, 3);
  assert.equal(target.recitationPolicy.autoRepeat, false);
  // And the pointing record gains nothing.
  assert.equal(built.get("moia-1446-marwah-same").contentKind, "procedural_guidance");
  assert.equal(built.get("moia-1446-marwah-same").recitationPolicy, null);
});

// ---------------------------------------------------------------------------
// sourceAssessment / attributionLevel / sourceReferencesCompleteness.
//
// These carry what the MINISTRY printed about a citation — never a grading we
// author. Three rules matter more than the rest: unknown values are refused,
// they may not attach to Qur'anic references, and absence is silence rather
// than a claim of authenticity.
// ---------------------------------------------------------------------------

function packWithRefs(refs, extra = {}) {
  const entries = realPack.entries.map((e) =>
    e.duaId === "moia-1446-tawaf-free-dhikr"
      ? { ...e, sourceReferences: refs, ...extra }
      : e,
  );
  return { ...realPack, entries };
}

const HADITH_REF = {
  type: "hadith",
  collection: "سنن أبي داود",
  reference: "1888",
  referenceKind: "hadith_number",
  citedBy: "moia_1446",
  citedOnPage: 70,
};

test("the real pack carries page 70's four citations with its qualifiers", () => {
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));
  const refs = built.get("moia-1446-tawaf-free-dhikr").sourceReferences;
  assert.equal(refs.length, 4);

  const weak = refs.filter((r) => r.sourceAssessment === "weak_isnad");
  assert.equal(weak.length, 3);
  assert.deepEqual(
    weak.map((r) => r.reference).sort(),
    ["1888", "24351", "902"],
  );
  for (const r of weak) {
    assert.equal(r.type, "hadith");
    assert.equal(r.referenceKind, "hadith_number");
    assert.equal(r.attributionLevel, undefined, "weakness is not a stopping point");
  }

  const athar = refs.find((r) => r.type === "athar");
  assert.equal(athar.collection, "مصنف عبدالرزاق");
  assert.equal(athar.reference, "5/49");
  assert.equal(athar.referenceKind, "volume_page");
  assert.equal(athar.attributionLevel, "mawquf");
  assert.equal(athar.attributedTo, "عائشة رضي الله عنها");
  assert.equal(
    athar.sourceAssessment,
    undefined,
    "mawquf says where a chain stops, NOT how sound it is",
  );

  for (const r of refs) {
    assert.equal(r.citedBy, "moia_1446");
    assert.equal(r.citedOnPage, 70);
  }
  assert.equal(
    built.get("moia-1446-tawaf-free-dhikr").sourceReferencesCompleteness,
    "named_references_plus_unnamed_others",
  );
});

test("an unknown sourceAssessment is refused", () => {
  assert.throws(
    () => buildRecords(packWithRefs([{ ...HADITH_REF, sourceAssessment: "sahih" }])),
    /unknown sourceAssessment "sahih"/,
  );
});

test("an unknown attributionLevel is refused", () => {
  assert.throws(
    () => buildRecords(packWithRefs([{ ...HADITH_REF, attributionLevel: "marfu" }])),
    /unknown attributionLevel "marfu"/,
  );
});

test("an unknown sourceReferencesCompleteness is refused", () => {
  assert.throws(
    () =>
      buildRecords(
        packWithRefs([HADITH_REF], { sourceReferencesCompleteness: "all_of_them" }),
      ),
    /unknown sourceReferencesCompleteness "all_of_them"/,
  );
});

test("neither qualifier may attach to a Qur'anic reference", () => {
  const quran = {
    type: "quran",
    collection: "القرآن الكريم",
    reference: "البقرة: 201",
    referenceKind: "surah_ayah",
    citedBy: "moia_1446",
    citedOnPage: 70,
  };
  assert.throws(
    () => buildRecords(packWithRefs([{ ...quran, sourceAssessment: "weak_isnad" }])),
    /sourceAssessment is not valid on a quran reference/,
  );
  assert.throws(
    () => buildRecords(packWithRefs([{ ...quran, attributionLevel: "mawquf" }])),
    /attributionLevel is not valid on a quran reference/,
  );
});

test("attributedTo without an attributionLevel is refused", () => {
  assert.throws(
    () => buildRecords(packWithRefs([{ ...HADITH_REF, attributedTo: "عائشة" }])),
    /attributedTo requires an attributionLevel/,
  );
  assert.throws(
    () =>
      buildRecords(
        packWithRefs([{ ...HADITH_REF, attributionLevel: "mawquf", attributedTo: "  " }]),
      ),
    /attributedTo must be a non-empty string/,
  );
});

test("declaring completeness with no references at all is refused", () => {
  assert.throws(
    () =>
      buildRecords(
        packWithRefs([], {
          sourceReferencesCompleteness: "named_references_plus_unnamed_others",
        }),
      ),
    /needs at least one reference/,
  );
});

test("the new qualifiers change no import decision", () => {
  // The record is included or excluded by the review ledger and its
  // contentKind. A weak-isnad citation must not alter either.
  const built = new Map(buildRecords(realPack).map((r) => [r.duaId, r]));
  const r = built.get("moia-1446-tawaf-free-dhikr");
  assert.equal(r.contentKind, "procedural_guidance");
  assert.equal(r.verificationStatus, "unverified");
  assert.equal(r.verifiedAt, null);
  // And the same record with the qualifiers stripped builds identically
  // apart from those fields.
  const stripped = buildRecords(
    packWithRefs(
      r.sourceReferences.map(({ sourceAssessment, attributionLevel, attributedTo, ...rest }) => rest),
    ),
  ).find((x) => x.duaId === "moia-1446-tawaf-free-dhikr");
  assert.equal(stripped.contentKind, r.contentKind);
  assert.equal(stripped.verificationStatus, r.verificationStatus);
});


// ── Safe write, ownership, and post-write verification ─────────────────
//
// Everything below drives the real write path with a fake `fetch`. No
// network, no credential, no Firebase.
//
// Two faults these guard against were real. A PATCH with no updateMask
// REPLACES the document, so the importer silently deleted usage_count, a
// hand-set audioUrl and every admin field it had never heard of. And
// rewriting the verification fields unconditionally meant an identical
// re-import withdrew an approval nobody had reason to withdraw.

const PLAN = {
  projectId: "test-project",
  database: "(default)",
  collection: "supplications_staging",
  token: "FAKE-TOKEN-NEVER-LOGGED",
};

function encodeValue(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === "boolean") return { booleanValue: v };
  if (typeof v === "number") {
    return Number.isInteger(v)
      ? { integerValue: String(v) }
      : { doubleValue: v };
  }
  if (Array.isArray(v)) return { arrayValue: { values: v.map(encodeValue) } };
  if (typeof v === "object") {
    const f = {};
    for (const [k, x] of Object.entries(v)) f[k] = encodeValue(x);
    return { mapValue: { fields: f } };
  }
  return { stringValue: String(v) };
}
function decodeValue(v) {
  if ("nullValue" in v) return null;
  if ("booleanValue" in v) return v.booleanValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return v.doubleValue;
  if ("stringValue" in v) return v.stringValue;
  if ("timestampValue" in v) return v.timestampValue;
  if ("arrayValue" in v) return (v.arrayValue.values ?? []).map(decodeValue);
  if ("mapValue" in v) {
    const o = {};
    for (const [k, x] of Object.entries(v.mapValue.fields ?? {})) {
      o[k] = decodeValue(x);
    }
    return o;
  }
  return null;
}

/** A fake Firestore honouring real PATCH/updateMask semantics. */
function fakeFirestore(docs = {}) {
  const calls = [];
  const store = { ...docs };
  const encode = (o) => {
    const f = {};
    for (const [k, v] of Object.entries(o)) {
      f[k] = typeof v === "string" && /^\d{4}-\d\d-\d\dT/.test(v)
        ? { timestampValue: v }
        : encodeValue(v);
    }
    return f;
  };

  const doFetch = async (url, init = {}) => {
    const method = init.method ?? "GET";
    const [path, query] = url.split("?");
    const id = decodeURIComponent(path.split("/").pop());
    calls.push({ method, url, id });

    if (method === "GET") {
      if (path.endsWith("/documents/" + PLAN.collection)) {
        return {
          ok: true, status: 200,
          json: async () => ({
            documents: Object.entries(store).map(([k, v]) => ({
              name: `projects/p/databases/(default)/documents/${PLAN.collection}/${k}`,
              fields: encode(v),
            })),
          }),
        };
      }
      if (!(id in store)) return { ok: false, status: 404 };
      return { ok: true, status: 200, json: async () => ({ fields: encode(store[id]) }) };
    }

    if (method === "PATCH") {
      const sent = JSON.parse(init.body);
      const incoming = {};
      for (const [k, v] of Object.entries(sent.fields)) incoming[k] = decodeValue(v);
      const mask = new URLSearchParams(query ?? "").getAll("updateMask.fieldPaths");
      if (mask.length === 0) {
        store[id] = incoming; // no mask: Firestore REPLACES
      } else {
        const next = { ...(store[id] ?? {}) };
        for (const f of mask) {
          if (f in incoming) next[f] = incoming[f];
          else delete next[f];
        }
        store[id] = next;
      }
      return { ok: true, status: 200, json: async () => ({}) };
    }
    return { ok: false, status: 405 };
  };
  return { fetch: doFetch, calls, store };
}

const REC = () =>
  new Map(buildRecords(realPack).map((r) => [r.duaId, r])).get(
    "moia-mukhtasar-1446-umrah-talbiyah",
  );
const patches = (fs) => fs.calls.filter((c) => c.method === "PATCH");

test("16) the ownership classes are disjoint and cover every field once", () => {
  const all = [
    ...PACK_OWNED_FIELDS,
    ...CREATE_ONLY_DEFAULT_FIELDS,
    ...VERIFICATION_RESET_FIELDS,
  ];
  assert.equal(new Set(all).size, all.length, "a field is claimed twice");
  assert.equal(PACK_OWNED_FIELDS.length, 39);
  assert.equal(CREATE_ONLY_DEFAULT_FIELDS.length, 7);
  assert.equal(VERIFICATION_RESET_FIELDS.length, 3);
  assert.equal(UPDATE_MASK_FIELDS.length, 42);

  // Every field the importer produces is classified exactly once. The two
  // timestamps are created at write time, so they are not record keys.
  const rec = REC();
  assert.equal(Object.keys(rec).length, 47);
  for (const f of Object.keys(rec)) {
    assert.ok(all.includes(f), `${f} belongs to no ownership class`);
  }
  assert.deepEqual(
    all.filter((f) => !(f in rec)).sort(),
    ["createdAt", "updatedAt"],
  );
  // isActive and revokedAt moved OUT of pack-owned/verification.
  assert.ok(!PACK_OWNED_FIELDS.includes("isActive"));
  assert.ok(!VERIFICATION_RESET_FIELDS.includes("revokedAt"));
  assert.ok(CREATE_ONLY_DEFAULT_FIELDS.includes("isActive"));
  assert.ok(CREATE_ONLY_DEFAULT_FIELDS.includes("revokedAt"));
  // Nothing create-only is ever masked.
  for (const f of CREATE_ONLY_DEFAULT_FIELDS) {
    assert.ok(!UPDATE_MASK_FIELDS.includes(f), `${f} must not be masked`);
  }
});

test("1) a new document carries createdAt and updatedAt as timestamps", async () => {
  const fs = fakeFirestore();
  const rec = REC();
  const out = await writeRecords([rec], PLAN, { fetch: fs.fetch });
  assert.equal(out.created, 1);
  assert.equal(out.writes, 1);

  const doc = fs.store[rec.duaId];
  for (const f of ["createdAt", "updatedAt"]) {
    assert.ok(doc[f], `${f} missing — the record would be invisible in the ` +
      `admin console, which orders by updatedAt`);
    assert.ok(!Number.isNaN(Date.parse(doc[f])), `${f} is not a timestamp`);
  }
  // Firestore's orderBy excludes documents lacking the ordered field, so
  // "has updatedAt" is exactly the condition for appearing in that list.
  const wouldAppearInOrderBy = (d) => "updatedAt" in d && d.updatedAt != null;
  assert.ok(wouldAppearInOrderBy(doc));

  // It is a real timestampValue on the wire, not a plain string.
  assert.ok(
    fs.calls.some((c) => c.method === "PATCH"),
    "expected a PATCH to have been issued",
  );
  const req = buildWriteRequest(rec, null, PLAN, new Date("2026-01-02T03:04:05Z"));
  assert.deepEqual(req.fields.createdAt, { timestampValue: "2026-01-02T03:04:05.000Z" });
  assert.deepEqual(req.fields.updatedAt, { timestampValue: "2026-01-02T03:04:05.000Z" });
  assert.ok(!req.url.includes("updateMask"), "a create must carry no mask");
});

test("11) a created document starts unverified with the right defaults", async () => {
  const fs = fakeFirestore();
  const rec = REC();
  await writeRecords([rec], PLAN, { fetch: fs.fetch });
  const d = fs.store[rec.duaId];
  assert.equal(d.verificationStatus, "unverified");
  assert.equal(d.verifiedAt, null);
  assert.equal(d.verifiedBy, null);
  assert.equal(d.audioMode, "tts");
  assert.equal(d.audioUrl, "");
  assert.equal(d.usage_count, 0);
  assert.equal(d.isActive, true);
  assert.equal(d.revokedAt, null);
});

test("2) isActive false on a live document stays false", async () => {
  const rec = REC();
  const fs = fakeFirestore({
    [rec.duaId]: { duaId: rec.duaId, isActive: false, text: { ar: "old", en: "" } },
  });
  await writeRecords([rec], PLAN, { fetch: fs.fetch });
  assert.equal(fs.store[rec.duaId].isActive, false,
    "an import re-published a record an admin had hidden");
});

test("3) a non-null revokedAt survives an update", async () => {
  const rec = REC();
  const fs = fakeFirestore({
    [rec.duaId]: {
      duaId: rec.duaId,
      revokedAt: "2026-02-02T00:00:00.000Z",
      isActive: false,
      text: { ar: "old", en: "" },
    },
  });
  await writeRecords([rec], PLAN, { fetch: fs.fetch });
  assert.equal(fs.store[rec.duaId].revokedAt, "2026-02-02T00:00:00.000Z",
    "an import un-revoked a record an admin had withdrawn");
  assert.equal(fs.store[rec.duaId].isActive, false);
});

test("4) audio and usage_count survive an update", async () => {
  const rec = REC();
  const fs = fakeFirestore({
    [rec.duaId]: {
      duaId: rec.duaId,
      audioMode: "file",
      audioUrl: "https://storage.example/x.mp3?token=SECRET",
      usage_count: 412,
      text: { ar: "old", en: "" },
    },
  });
  await writeRecords([rec], PLAN, { fetch: fs.fetch });
  const d = fs.store[rec.duaId];
  assert.equal(d.audioMode, "file");
  assert.equal(d.audioUrl, "https://storage.example/x.mp3?token=SECRET");
  assert.equal(d.usage_count, 412);
  assert.equal(d.text.ar, rec.text.ar, "pack content really was refreshed");
});

test("5) createdAt and updatedAt are untouched by an update", async () => {
  const rec = REC();
  const fs = fakeFirestore({
    [rec.duaId]: {
      duaId: rec.duaId,
      createdAt: "2025-01-01T00:00:00.000Z",
      updatedAt: "2025-06-06T00:00:00.000Z",
      text: { ar: "old", en: "" },
    },
  });
  await writeRecords([rec], PLAN, { fetch: fs.fetch });
  const d = fs.store[rec.duaId];
  assert.equal(d.createdAt, "2025-01-01T00:00:00.000Z");
  assert.equal(d.updatedAt, "2025-06-06T00:00:00.000Z",
    "the admin console owns updatedAt; an import must not bump it");
});

test("6) an unknown admin field survives an update", async () => {
  const rec = REC();
  const fs = fakeFirestore({
    [rec.duaId]: {
      duaId: rec.duaId,
      someFutureField: { nested: true },
      anotherOne: [1, 2, 3],
      text: { ar: "old", en: "" },
    },
  });
  await writeRecords([rec], PLAN, { fetch: fs.fetch });
  assert.deepEqual(fs.store[rec.duaId].someFutureField, { nested: true });
  assert.deepEqual(fs.store[rec.duaId].anotherOne, [1, 2, 3]);
});

test("7) an identical re-import of a VERIFIED record writes nothing", async () => {
  const rec = REC();
  const live = {
    ...rec,
    verificationStatus: "verified",
    verifiedBy: "admin@example.com",
    verifiedAt: "2026-01-01T00:00:00.000Z",
    audioMode: "file",
    audioUrl: "https://x/y.mp3",
    usage_count: 77,
    isActive: true,
    revokedAt: null,
    createdAt: "2025-01-01T00:00:00.000Z",
    updatedAt: "2025-06-06T00:00:00.000Z",
  };
  const fs = fakeFirestore({ [rec.duaId]: live });
  const out = await writeRecords([rec], PLAN, { fetch: fs.fetch });

  assert.equal(out.unchanged, 1);
  assert.equal(out.writes, 0, "an identical import must not PATCH");
  assert.equal(patches(fs).length, 0);
  assert.equal(fs.store[rec.duaId].verificationStatus, "verified",
    "an approval was withdrawn for no reason");
  assert.equal(fs.store[rec.duaId].verifiedBy, "admin@example.com");
  assert.equal(fs.store[rec.duaId].verifiedAt, "2026-01-01T00:00:00.000Z");
});

test("8) any pack-field change writes and drops verification", async () => {
  const base = REC();
  const cases = {
    "text.ar": { ...base, text: { ...base.text, ar: base.text.ar + " ز" } },
    contentKind: { ...base, contentKind: "general_dua" },
    sourceReferences: {
      ...base,
      sourceReferences: [
        ...base.sourceReferences,
        { type: "hadith", collection: "x", reference: "1", referenceKind: "hadith_number", citedBy: "moia_1446", citedOnPage: 9 },
      ],
    },
    reviewNotes: { ...base, reviewNotes: "changed" },
  };
  for (const [label, rec] of Object.entries(cases)) {
    const fs = fakeFirestore({
      [base.duaId]: {
        ...base,
        verificationStatus: "verified",
        verifiedBy: "a@b",
        verifiedAt: "2026-01-01T00:00:00.000Z",
        usage_count: 5,
        revokedAt: "2026-02-02T00:00:00.000Z",
        isActive: false,
      },
    });
    const out = await writeRecords([rec], PLAN, { fetch: fs.fetch });
    assert.equal(out.writes, 1, label);
    const d = fs.store[base.duaId];
    assert.equal(d.verificationStatus, "unverified", label);
    assert.equal(d.verifiedBy, null, label);
    assert.equal(d.verifiedAt, null, label);
    assert.ok("verifiedAt" in d, `${label}: the key must exist, not vanish`);
    // …and the human's own decisions still survive.
    assert.equal(d.revokedAt, "2026-02-02T00:00:00.000Z", label);
    assert.equal(d.isActive, false, label);
    assert.equal(d.usage_count, 5, label);
  }
});

test("9) map key order alone is not a change", () => {
  const rec = REC();
  const reordered = { ...rec, text: { en: rec.text.en, ar: rec.text.ar } };
  assert.deepEqual(changedPackFields(reordered, rec), []);
  assert.ok(sameCanonical({ a: 1, b: 2 }, { b: 2, a: 1 }));
});

function sameCanonical(a, b) {
  return JSON.stringify(canonical(a)) === JSON.stringify(canonical(b));
}

test("10) array order IS a change — these are sequences, not sets", () => {
  const rec = REC();
  const swapped = { ...rec, tagsAr: [...rec.tagsAr].reverse() };
  if (rec.tagsAr.length > 1) {
    assert.deepEqual(changedPackFields(swapped, rec), ["tagsAr"]);
  }
  assert.ok(!sameCanonical([1, 2], [2, 1]));
});

test("14) NFC normalisation prevents a false 'changed' and a false hash miss", () => {
  const rec = REC();
  // Same text, decomposed. Meaning identical; bytes are not.
  const nfd = { ...rec, text: { ...rec.text, ar: rec.text.ar.normalize("NFD") } };
  assert.deepEqual(changedPackFields(nfd, rec), [],
    "a pure normalisation difference must not withdraw an approval");
  assert.equal(normalisedTextHash(nfd), normalisedTextHash(rec));
  // And a real edit still differs.
  const edited = { ...rec, text: { ...rec.text, ar: rec.text.ar + "x" } };
  assert.notEqual(normalisedTextHash(edited), normalisedTextHash(rec));
});

test("15) document ids are percent-decoded, and a bad escape fails safe", () => {
  assert.equal(safeDecodeId("projects/p/documents/c/moia-1446-x"), "moia-1446-x");
  assert.equal(safeDecodeId("projects/p/documents/c/a%20b"), "a b");
  // A lone % is not a valid escape; it must be returned raw, not throw.
  assert.equal(safeDecodeId("projects/p/documents/c/100%"), "100%");
  assert.equal(safeDecodeId(""), "");
});

test("existence is read, never guessed, and a failed read aborts", async () => {
  const fs = fakeFirestore();
  await writeRecords([REC()], PLAN, { fetch: fs.fetch });
  assert.deepEqual(fs.calls.map((c) => c.method), ["GET", "PATCH"]);

  for (const status of [401, 403, 429, 500, 503]) {
    await assert.rejects(
      () => writeRecords([REC()], PLAN, { fetch: async () => ({ ok: false, status }) }),
      new RegExp(`read of .* failed: HTTP ${status}`),
    );
  }
});

// ── Post-write verification ───────────────────────────────────────────

test("12) verification checks every create default", async () => {
  const rec = REC();
  const fs = fakeFirestore();
  await writeRecords([rec], PLAN, { fetch: fs.fetch });
  assert.equal(
    await verifyWritten(rec, PLAN, { fetch: fs.fetch }, { isCreate: true }),
    true,
  );

  for (const [field, bad] of Object.entries({
    audioMode: "file", audioUrl: "https://x", usage_count: 3,
    isActive: false, revokedAt: "2026-01-01", verificationStatus: "verified",
  })) {
    const broken = fakeFirestore({ [rec.duaId]: { ...fs.store[rec.duaId], [field]: bad } });
    await assert.rejects(
      () => verifyWritten(rec, PLAN, { fetch: broken.fetch }, { isCreate: true }),
      new RegExp(`wrong "${field}"|verificationStatus`),
      field,
    );
  }
  // A create with no timestamps must fail: it would be invisible to admins.
  const noStamp = { ...fs.store[rec.duaId] };
  delete noStamp.updatedAt;
  const missing = fakeFirestore({ [rec.duaId]: noStamp });
  await assert.rejects(
    () => verifyWritten(rec, PLAN, { fetch: missing.fetch }, { isCreate: true }),
    /has no "updatedAt"/,
  );
});

test("13) verification checks the preserved fields after an update", async () => {
  const rec = REC();
  const before = {
    ...rec, text: { ar: "old", en: "" },
    audioMode: "file", audioUrl: "https://x/y.mp3", usage_count: 9,
    isActive: false, revokedAt: "2026-02-02T00:00:00.000Z",
    createdAt: "2025-01-01T00:00:00.000Z", updatedAt: "2025-06-06T00:00:00.000Z",
    adminNote: "keep me",
    verificationStatus: "verified", verifiedBy: "a@b", verifiedAt: "2026-01-01",
  };
  const fs = fakeFirestore({ [rec.duaId]: { ...before } });
  const out = await writeRecords([rec], PLAN, { fetch: fs.fetch });
  const o = out.outcomes[0];
  assert.equal(o.outcome, "updated");
  assert.equal(
    await verifyWritten(rec, PLAN, { fetch: fs.fetch },
      { isCreate: false, before, changed: o.changed }),
    true,
  );

  // Tamper with a preserved field and verification must catch it.
  for (const f of ["audioUrl", "usage_count", "isActive", "revokedAt",
    "createdAt", "updatedAt", "adminNote"]) {
    const tampered = fakeFirestore({
      [rec.duaId]: { ...fs.store[rec.duaId], [f]: "TAMPERED" },
    });
    await assert.rejects(
      () => verifyWritten(rec, PLAN, { fetch: tampered.fetch },
        { isCreate: false, before, changed: o.changed }),
      new RegExp(`"${f}" was modified|admin field "${f}"`),
      f,
    );
  }
  // And a content change that did NOT drop verification must fail.
  const stillVerified = fakeFirestore({
    [rec.duaId]: { ...fs.store[rec.duaId], verificationStatus: "verified" },
  });
  await assert.rejects(
    () => verifyWritten(rec, PLAN, { fetch: stillVerified.fetch },
      { isCreate: false, before, changed: o.changed }),
    /content changed but verificationStatus/,
  );
});

test("verification fails on a missing document or a text mismatch", async () => {
  const rec = REC();
  await assert.rejects(
    () => verifyWritten(rec, PLAN, { fetch: fakeFirestore().fetch }, { isCreate: true }),
    /not found after write/,
  );
  const wrongText = fakeFirestore({
    [rec.duaId]: { ...rec, text: { ar: "tampered", en: "" },
      audioMode: "tts", audioUrl: "", usage_count: 0, isActive: true,
      revokedAt: null, createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z" },
  });
  await assert.rejects(
    () => verifyWritten(rec, PLAN, { fetch: wrongText.fetch }, { isCreate: true }),
    /stored text does not match/,
  );
});

// ── Reconciliation ────────────────────────────────────────────────────

function reconcileFixture() {
  const all = buildRecords(realPack);
  const r = applyLedger(all, loadLedger());
  return { all, cleared: r.included, excluded: r.excluded };
}

test("17a) an excluded record that exists live blocks production", () => {
  const { all, cleared, excluded } = reconcileFixture();
  const held = excluded[0].duaId;
  const findings = reconcile({
    live: [{ documentId: held, verificationStatus: "verified", text: { ar: "x", en: "" } }],
    cleared, excluded, packIds: new Set(all.map((x) => x.duaId)),
  });
  const hit = findings.find((f) => f.documentId === held);
  assert.equal(hit.case, "present_but_excluded");
  assert.ok(hit.reason.length > 0);
  assert.throws(() => assertReconciledForProduction(findings),
    /Refusing to write to production/);
});

test("17b) a document no longer in the pack blocks production", () => {
  const { all, cleared, excluded } = reconcileFixture();
  const findings = reconcile({
    live: [{ documentId: "some-retired-record", verificationStatus: "verified" }],
    cleared, excluded, packIds: new Set(all.map((x) => x.duaId)),
  });
  assert.equal(
    findings.find((f) => f.documentId === "some-retired-record").case,
    "present_but_removed_from_pack",
  );
  assert.throws(() => assertReconciledForProduction(findings));
  assert.deepEqual([...PRODUCTION_BLOCKING_CASES].sort(),
    ["present_but_excluded", "present_but_removed_from_pack"]);
});

test("17c) missing is not a blocker, and drift is reported", () => {
  const { all, cleared, excluded } = reconcileFixture();
  const packIds = new Set(all.map((x) => x.duaId));
  const missing = reconcile({ live: [], cleared, excluded, packIds });
  assert.ok(missing.every((f) => f.case === "expected_missing"));
  assert.doesNotThrow(() => assertReconciledForProduction(missing));

  const one = cleared[0];
  assert.equal(
    reconcile({ live: [{ documentId: one.duaId, text: one.text }],
      cleared: [one], excluded, packIds })[0].case,
    "expected_and_present",
  );
  assert.equal(
    reconcile({ live: [{ documentId: one.duaId, text: { ar: "different", en: "" } }],
      cleared: [one], excluded, packIds })[0].case,
    "text_changed",
  );
});

test("17d) reconcile issues no write of any kind", async () => {
  const { all, cleared, excluded } = reconcileFixture();
  const fs = fakeFirestore({ "some-retired-record": { duaId: "x" } });
  const live = await listCollection(PLAN, { fetch: fs.fetch });
  reconcile({ live, cleared, excluded, packIds: new Set(all.map((x) => x.duaId)) });
  assert.ok(fs.calls.every((c) => c.method === "GET"),
    `reconcile performed: ${fs.calls.map((c) => c.method)}`);
});

test("18) no token, signed url or full text reaches a log line", async () => {
  const rec = REC();
  const fs = fakeFirestore({
    [rec.duaId]: {
      duaId: rec.duaId, text: { ar: "old", en: "" },
      audioUrl: "https://storage.example/x.mp3?token=SUPER-SECRET",
      audioMode: "file",
    },
  });
  const lines = [];
  const realLog = console.log;
  console.log = (...a) => lines.push(a.join(" "));
  try {
    const out = await writeRecords([rec], PLAN, { fetch: fs.fetch });
    await verifyWritten(rec, PLAN, { fetch: fs.fetch },
      { isCreate: false, before: fs.store[rec.duaId], changed: out.outcomes[0].changed });
    printReconcile(
      [{ documentId: rec.duaId, case: "present_but_excluded",
         verificationStatus: "verified", reason: "deployment hold" }],
      PLAN.collection,
    );
  } finally {
    console.log = realLog;
  }
  const all = lines.join("\n");
  assert.ok(!all.includes(PLAN.token), "the bearer token was logged");
  assert.ok(!all.includes("SUPER-SECRET"), "a signed audioUrl was logged");
  assert.ok(!all.includes("storage.example"), "an audio host was logged");
  assert.ok(!all.includes(rec.text.ar), "a full record text was logged");
});

test("the dry-run plan prints the count before AND after --limit", () => {
  const out = childProcess.execFileSync(
    process.execPath,
    ["scripts/import_source_pack.mjs", PACK, "--staging", "--limit", "1"],
    { encoding: "utf8" },
  );
  assert.match(out, /Cleared by ledger \(before --limit\): 73/);
  assert.match(out, /^Included:   1 /m);
  assert.match(out, /^Excluded:   12 /m);
  assert.match(out, /Limit:      1  \(73 cleared → 1 to write\)/);
});

// ---------------------------------------------------------------------------
// The stale-document inventory.
//
// `present_but_removed_from_pack` is the case a human has to act on: a live
// document nothing in the current pack accounts for. The report therefore
// carries enough to decide — is it still active, still verified, does it
// still hold audio — and nothing more. These tests fix both halves: that the
// facts are there, and that the text and the audio URL are not.

import { INVENTORY_FIELDS, inventoryOf } from "./import_source_pack.mjs";

const STALE_DOC = {
  documentId: "legacy-001",
  duaId: "legacy-001",
  verificationStatus: "verified",
  isActive: true,
  revokedAt: null,
  audioMode: "file",
  audioUrl:
    "https://firebasestorage.example/v0/b/x/o/a.mp3?token=SECRET-DOWNLOAD-TOKEN",
  contentKind: "dua",
  createdAt: "2025-01-01T00:00:00.000Z",
  updatedAt: null,
  text: { ar: "نص عربي لا يجوز طباعته", en: "text that must not be printed" },
  reviewNotes: "internal reviewer note",
};

function reconcileStale(docs) {
  return reconcile({
    live: docs,
    cleared: [],
    excluded: [],
    packIds: new Set(),
  }).filter((f) => f.case === "present_but_removed_from_pack");
}

function captureReconcile(findings) {
  const realLog = console.log;
  const lines = [];
  console.log = (...a) => lines.push(a.join(" "));
  try {
    printReconcile(findings, PLAN.collection);
  } finally {
    console.log = realLog;
  }
  return lines.join("\n");
}

test("an inventory row carries exactly the nine agreed keys, no more", () => {
  const inv = inventoryOf(STALE_DOC);
  assert.deepEqual(Object.keys(inv).sort(), [...INVENTORY_FIELDS].sort());
  for (const banned of ["text", "audioUrl", "reviewNotes", "duaId"]) {
    assert.ok(!(banned in inv), `${banned} leaked into the inventory object`);
  }
});

test("presence-only fields are booleans, never the underlying value", () => {
  const inv = inventoryOf(STALE_DOC);
  assert.equal(inv.hasAudioUrl, true);
  assert.equal(inv.hasCreatedAt, true);
  assert.equal(inv.hasUpdatedAt, false, "an explicit null is not presence");
  assert.equal(inv.hasRevokedAt, false);
  for (const k of ["hasAudioUrl", "hasCreatedAt", "hasUpdatedAt", "hasRevokedAt"]) {
    assert.equal(typeof inv[k], "boolean", `${k} is not a boolean`);
  }
});

test("an empty string counts as absent, not as a held value", () => {
  const inv = inventoryOf({ ...STALE_DOC, audioUrl: "   ", revokedAt: "" });
  assert.equal(inv.hasAudioUrl, false);
  assert.equal(inv.hasRevokedAt, false);
});

test("missing fields report as unset rather than crashing or inventing", () => {
  const inv = inventoryOf({ documentId: "bare-001" });
  assert.equal(inv.verificationStatus, null);
  assert.equal(inv.isActive, null);
  assert.equal(inv.audioMode, null);
  assert.equal(inv.contentKind, null);
  assert.equal(inv.hasAudioUrl, false);
  assert.equal(inv.hasCreatedAt, false);
  assert.equal(inv.hasUpdatedAt, false);
});

test("only present_but_removed_from_pack findings carry an inventory", () => {
  const record = { duaId: "kept-001", text: { ar: "ا", en: "a" } };
  const findings = reconcile({
    live: [
      { documentId: "kept-001", ...record, verificationStatus: "verified" },
      { documentId: "held-001", verificationStatus: "unverified" },
      STALE_DOC,
    ],
    cleared: [record],
    excluded: [{ duaId: "held-001", reasons: ["blocked"] }],
    packIds: new Set(["kept-001", "held-001"]),
  });
  for (const f of findings) {
    const expected = f.case === "present_but_removed_from_pack";
    assert.equal(
      Boolean(f.inventory),
      expected,
      `${f.case} inventory presence is wrong`,
    );
  }
});

test("the inventory works for any number of stale records, not a fixed count", () => {
  for (const n of [0, 1, 7, 16, 40]) {
    const docs = Array.from({ length: n }, (_, i) => ({
      ...STALE_DOC,
      documentId: `legacy-${i}`,
    }));
    const findings = reconcileStale(docs);
    assert.equal(findings.length, n);
    assert.equal(captureReconcile(findings).includes(`: ${n}`), true);
  }
});

test("the printed inventory never leaks text, audio URL or review notes", () => {
  const out = captureReconcile(reconcileStale([STALE_DOC]));
  for (const secret of [
    STALE_DOC.text.ar,
    STALE_DOC.text.en,
    STALE_DOC.audioUrl,
    "SECRET-DOWNLOAD-TOKEN",
    "firebasestorage.example",
    STALE_DOC.reviewNotes,
    PLAN.token,
  ]) {
    assert.ok(!out.includes(secret), `the report printed: ${secret}`);
  }
});

test("the printed inventory does report the facts a retraction decision needs", () => {
  const out = captureReconcile(reconcileStale([STALE_DOC]));
  assert.match(out, /legacy-001/);
  assert.match(out, /verification=verified/);
  assert.match(out, /isActive=true/);
  assert.match(out, /revokedAt=absent/);
  assert.match(out, /audioMode=file/);
  assert.match(out, /audioUrl=present/);
  assert.match(out, /contentKind=dua/);
  assert.match(out, /createdAt=present/);
  assert.match(out, /updatedAt=absent/);
});

test("every inventory line keeps the '  - ' prefix the job summary filters on", () => {
  const out = captureReconcile(reconcileStale([STALE_DOC, { documentId: "x" }]));
  const rows = out
    .split("\n")
    .filter((l) => l.includes("audioUrl=") || l.includes("contentKind="));
  assert.equal(rows.length, 2);
  for (const r of rows) assert.ok(r.startsWith("  - "), `unfiltered row: ${r}`);
});

test("the report still ends by stating that nothing was written", () => {
  const out = captureReconcile(reconcileStale([STALE_DOC]));
  assert.match(out, /READ ONLY, nothing is written\./);
  assert.match(out, /No document was written, deleted or revoked\./);
});

test("building and printing the inventory issues no HTTP call at all", async () => {
  const realFetch = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (url, init) => {
    calls.push(`${init?.method ?? "GET"} ${url}`);
    throw new Error("the inventory must not reach a network");
  };
  try {
    captureReconcile(reconcileStale([STALE_DOC]));
    inventoryOf(STALE_DOC);
  } finally {
    globalThis.fetch = realFetch;
  }
  assert.deepEqual(calls, []);
});

test("listing the collection for the inventory uses GET only, with no body", async () => {
  const calls = [];
  const fakeFetch = async (url, init) => {
    calls.push({ url, method: init?.method, body: init?.body });
    return {
      ok: true,
      json: async () => ({
        documents: [
          {
            name: `projects/p/databases/(default)/documents/c/legacy-001`,
            fields: { verificationStatus: { stringValue: "verified" } },
          },
        ],
      }),
    };
  };
  const docs = await listCollection(PLAN, { fetch: fakeFetch });
  assert.equal(docs.length, 1);
  assert.equal(calls.length, 1);
  // No method set at all is a GET; anything else would be a write.
  assert.ok(
    calls[0].method === undefined || calls[0].method === "GET",
    `the list path used ${calls[0].method}`,
  );
  assert.equal(calls[0].body, undefined, "the list path sent a body");
});

test("a stale document that is inactive and revoked is reported as such", () => {
  const out = captureReconcile(
    reconcileStale([
      {
        ...STALE_DOC,
        isActive: false,
        revokedAt: "2025-06-01T00:00:00.000Z",
        audioUrl: "",
        audioMode: "tts",
        updatedAt: "2025-06-01T00:00:00.000Z",
      },
    ]),
  );
  assert.match(out, /isActive=false/);
  assert.match(out, /revokedAt=present/);
  assert.match(out, /audioUrl=absent/);
  assert.match(out, /updatedAt=present/);
  // The timestamp value itself is operational detail the report withholds.
  assert.ok(!out.includes("2025-06-01"), "a raw timestamp was printed");
});
