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

  const crowding = built.get("moia-1446-hajar-crowding").sourceReferences;
  assert.equal(crowding.length, 4);
  assert.equal(crowding.filter((r) => "reference" in r).length, 2);
  assert.ok(
    crowding.filter((r) => !("reference" in r))
      .every((r) => r.referenceKind === "unspecified"),
  );

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
