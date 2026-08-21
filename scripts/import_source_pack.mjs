#!/usr/bin/env node
/**
 * Admin-only importer for a source pack (`source_packs/*.json`) into the
 * `supplications` collection.
 *
 * This is the ONLY supported path from a reviewed source pack into Firestore.
 * It is deliberately separate from `scripts/ingest_knowledge.mjs`, which
 * targets the `knowledge_chunks` collection.
 *
 * ── What this script guarantees ─────────────────────────────────────────
 *
 * 1. `zoneKey` and `contentKind` are written on EVERY record. These are not
 *    cosmetic: `contentKind` is what stops a procedural ruling from being
 *    rendered under a «دعاء» heading in the app, and `zoneKey` is the stable
 *    slug that survives an admin renaming a zone's `nameAr`.
 *
 * 2. Nothing is ever written as verified. `verificationStatus` is forced to
 *    "unverified" and `verifiedAt`/`verifiedBy` to null, whatever the input
 *    file says. Verification is a human act performed against the printed
 *    page — an import script must not be able to confer it. Consequently
 *    imported records are NOT retrievable by the assistant (the Worker's
 *    provenance gate rejects them) until a human verifies them.
 *
 * 3. A record whose `zoneKey` is non-empty must name a zone that exists in
 *    `lib/shared/data/hajj_zones_seed.dart`; an unknown slug aborts the run
 *    rather than silently orphaning the record.
 *
 * 4. An empty `zoneKey` is legitimate and means "not tied to any one place"
 *    (a general dua, a mosque-entry text, a text covering several miqats).
 *    Such a record must NOT be given a zone here — attributing a general
 *    text to a specific place is exactly the misattribution this pipeline
 *    exists to prevent. The app surfaces those via the coverage matrix,
 *    labelled as general.
 *
 * ── Usage ───────────────────────────────────────────────────────────────
 *
 * DRY RUN IS THE DEFAULT. Without `--write` the script validates the pack,
 * prints the plan, contacts nothing, and does not even read credentials:
 *
 *   node scripts/import_source_pack.mjs source_packs/<pack>.json
 *
 * A real write needs an explicit destination flag AND `--write`, plus
 * confirmations that must match the printed plan:
 *
 *   export FIREBASE_PROJECT_ID=your-project-id
 *   export FIREBASE_ADMIN_TOKEN=$(gcloud auth print-access-token)
 *
 *   # try a single record in staging first
 *   node scripts/import_source_pack.mjs source_packs/<pack>.json \
 *     --staging --limit 1 --write --confirm-project=<id> --confirm-count=1
 *
 *   # the real thing
 *   node scripts/import_source_pack.mjs source_packs/<pack>.json \
 *     --production --write --confirm-project=<id> --confirm-count=<n>
 *
 * `--staging` always means `supplications_staging` and `--production`
 * always means `supplications`; the collection is never taken from input.
 * `--limit` is refused against production. The script is idempotent: the
 * document id is the record's `duaId`, so re-running updates rather than
 * duplicates.
 */

import { readFileSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";

// The 19 zone slugs defined by `lib/shared/data/hajj_zones_seed.dart`.
// Kept in sync by `test/source_pack_integrity_test.dart`, which reads both
// files and fails if they diverge.
export const KNOWN_ZONE_KEYS = [
  "mataf",
  "kaaba",
  "maqam_ibrahim",
  "zamzam",
  "hajar_aswad",
  "hijr_ismail",
  "masaa",
  "mina",
  "jamrat_aqabah",
  "jamrat_wusta",
  "jamrat_sughra",
  "muzdalifah",
  "mashar_haram",
  "arafat",
  "jabal_rahmah",
  "masjid_namirah",
  "miqat_dhul_hulayfah",
  "miqat_yalamlam",
  "miqat_qarn_manazil",
];

export const KNOWN_CONTENT_KINDS = [
  "specific_text",
  "general_dua",
  "general_dhikr",
  "mosque_entry",
  "procedural_guidance",
];

// The only usage qualifiers a pack may name. `null`/absent is always
// allowed and means "unqualified". An unknown string is a hard error rather
// than a silent pass-through: a qualifier the app cannot render would
// display as nothing at all, which is indistinguishable from a text the
// source never qualified.
export const SUPPORTED_USAGE_QUALIFIERS = ["optional_addition"];

// ── The document schema ─────────────────────────────────────────────────
//
// Every field written to Firestore is listed here explicitly. This replaces
// an earlier hand-written object literal that silently dropped any field the
// packs gained later — `ritualKey` and `appliesToZoneKeys` (the two fields
// that stop the Talbiyah being pinned to one miqat) and the whole Quranic
// provenance block were being lost on import, so imported records were
// poorer than the reviewed pack and nothing said so.
//
// A whole-object spread would have "fixed" that while creating a worse
// problem: any typo or stray key in a pack would flow straight into
// production documents. So the schema is explicit in both directions —
// listed fields are copied, unlisted fields are a hard error.

/** Forced by the importer regardless of what the pack says. */
const FORCED_FIELDS = {
  // Verification is a human act performed against the printed page. An
  // import script must never be able to confer it.
  verificationStatus: "unverified",
  verifiedAt: null,
  verifiedBy: null,
  revokedAt: null,
  // Playback/analytics defaults owned by the app, not by the source.
  audioMode: "tts",
  audioUrl: "",
  usage_count: 0,
};

/** Must be present and non-empty in the pack. */
const REQUIRED_FIELDS = ["duaId", "contentKind", "zoneKey", "title", "text"];

/**
 * Copied when present. The default applies ONLY when the key is absent from
 * the pack entry — an explicit `null` or `""` is preserved as written,
 * because in this data those carry meaning: `zoneKey: ""` says "not tied to
 * any one place", and a null `contentHash` says "not yet computed". Coercing
 * either would turn a deliberate statement into a guess.
 */
const OPTIONAL_FIELDS = {
  zoneId: "",
  zoneNameAr: "",
  tagsAr: [],
  tagsEn: [],
  languageCodes: ["ar"],
  isActive: true,

  // Ministry (context) provenance.
  authority: "",
  sourceUrl: "",
  sourceVersion: "",
  sourceLanguage: "",
  sourceSection: "",
  printedPage: null,
  contentHash: null,
  contextAuthority: "",
  contextSourceUrl: "",

  // Ritual scope: a text the source ties to a rite spanning several zones
  // rather than to one spot. Dropping these two silently re-attached such a
  // text to a single place — the exact misattribution this pipeline exists
  // to prevent.
  ritualKey: "",
  appliesToZoneKeys: [],

  // How the source describes the text's USE, as opposed to what it is.
  // Default `null` means "the source described no usage" — deliberately
  // NOT "mandatory". There is no mandatory value and there will not be
  // one: most texts in the book carry no such description, and labelling
  // them obligatory merely for lacking one would assert a ruling nobody
  // made. See SUPPORTED_USAGE_QUALIFIERS.
  usageQualifier: null,

  // Quranic text authority (King Fahd Complex) — see
  // source_packs/QURAN_TEXT_AUTHORITY.md.
  quranRef: null,
  isPortionOfAyah: false,
  textAuthority: "",
  textAuthoritySourceUrl: "",
  textRiwayah: "",
  textRasm: "",
  textEdition: "",
  textEditionDate: "",

  // Classification and review aids the human verifier needs in the console.
  isGeneralSupplication: false,
  reviewNotes: "",
  visuallyUncertain: [],
};

/** Every key a pack entry may legitimately carry. */
export const KNOWN_PACK_FIELDS = new Set([
  ...REQUIRED_FIELDS,
  ...Object.keys(OPTIONAL_FIELDS),
  // A pack may restate a forced field (they all carry verificationStatus);
  // the value is ignored, but the key is not an error.
  ...Object.keys(FORCED_FIELDS),
]);

/**
 * Validates a pack and returns the Firestore-shaped records to write.
 * Throws on the first structural problem — a partial import is worse than
 * no import.
 */
export function buildRecords(pack) {
  const entries = pack?.entries;
  if (!Array.isArray(entries) || entries.length === 0) {
    throw new Error("Pack has no `entries` array.");
  }

  const seen = new Set();
  return entries.map((entry, index) => {
    const where = `entry #${index} (${entry?.duaId || "no duaId"})`;

    // Unknown keys are refused, never dropped. A field nobody planned for is
    // either a typo or a schema change; both need a human, and silently
    // discarding it is how the previous bug went unnoticed.
    for (const key of Object.keys(entry ?? {})) {
      if (!KNOWN_PACK_FIELDS.has(key)) {
        throw new Error(
          `${where}: unknown field "${key}". Add it to OPTIONAL_FIELDS in ` +
            "scripts/import_source_pack.mjs if it is meant to be imported.",
        );
      }
    }

    const duaId = String(entry?.duaId || "").trim();
    if (!duaId) throw new Error(`${where}: missing duaId.`);
    if (seen.has(duaId)) throw new Error(`${where}: duplicate duaId.`);
    seen.add(duaId);

    const contentKind = String(entry?.contentKind || "").trim();
    if (!KNOWN_CONTENT_KINDS.includes(contentKind)) {
      throw new Error(`${where}: unknown contentKind "${contentKind}".`);
    }

    // `zoneKey` must be present on every entry. Absent is an error, because
    // absence is ambiguous — we cannot tell "not tied to a place" from
    // "someone forgot". Empty string is the explicit way to say the former.
    if (!Object.prototype.hasOwnProperty.call(entry, "zoneKey")) {
      throw new Error(`${where}: missing zoneKey (use "" if not zone-tied).`);
    }
    const zoneKey = String(entry.zoneKey || "").trim();
    if (zoneKey && !KNOWN_ZONE_KEYS.includes(zoneKey)) {
      throw new Error(`${where}: unknown zoneKey "${zoneKey}".`);
    }

    // Every zone a ritual-scoped text claims must exist too, or the text
    // would surface at a place the seed does not define.
    const appliesTo = entry.appliesToZoneKeys;
    if (appliesTo !== undefined) {
      if (!Array.isArray(appliesTo)) {
        throw new Error(`${where}: appliesToZoneKeys must be an array.`);
      }
      for (const key of appliesTo) {
        if (!KNOWN_ZONE_KEYS.includes(String(key))) {
          throw new Error(`${where}: appliesToZoneKeys has unknown "${key}".`);
        }
      }
    }

    // A usage qualifier the app cannot render would show as no badge at
    // all — the same as a text the source never qualified. Refuse rather
    // than let the distinction disappear.
    const qualifier = entry.usageQualifier;
    if (qualifier !== undefined && qualifier !== null) {
      if (typeof qualifier !== "string") {
        throw new Error(`${where}: usageQualifier must be a string or null.`);
      }
      if (!SUPPORTED_USAGE_QUALIFIERS.includes(qualifier)) {
        throw new Error(
          `${where}: unknown usageQualifier "${qualifier}". ` +
            `Supported: ${SUPPORTED_USAGE_QUALIFIERS.join(", ")}.`,
        );
      }
    }

    const textAr = String(entry?.text?.ar || "").trim();
    if (!textAr) throw new Error(`${where}: empty Arabic text.`);

    const record = {
      duaId,
      contentKind,
      zoneKey,
      title: entry.title,
      text: entry.text,
    };

    for (const [key, fallback] of Object.entries(OPTIONAL_FIELDS)) {
      // hasOwnProperty, not `??` — an explicit null must survive as null.
      record[key] = Object.prototype.hasOwnProperty.call(entry, key)
        ? entry[key]
        : fallback;
    }

    for (const [key, value] of Object.entries(FORCED_FIELDS)) {
      record[key] = value;
    }

    return record;
  });
}

function toFirestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(toFirestoreValue) } };
  }
  if (typeof value === "object") {
    const fields = {};
    for (const [k, v] of Object.entries(value)) fields[k] = toFirestoreValue(v);
    return { mapValue: { fields } };
  }
  return { stringValue: String(value) };
}

// ── Destinations ────────────────────────────────────────────────────────
//
// The collection is NEVER taken from user input. Two fixed destinations
// exist, each behind its own explicit flag, so a typo can never invent a
// collection and `--staging` can never silently become production.

// ── The review ledger, as an operational gate ───────────────────────────
//
// `review/human_review_ledger.json` records what a human checked against the
// printed page, and which records must NOT be shipped. Until now that was
// documentation only: nothing stopped this script from writing a record the
// ledger had rejected. A hold nobody enforces is a hold that expires the
// first time someone runs an import in a hurry.
//
// Three independent grounds for exclusion, kept separate because they mean
// different things:
//
//   reviewStatus: "blocked"   → something is wrong with the TEXT.
//   excludedFromImport: true  → the explicit instruction, whatever the cause.
//   deploymentBlocked: true   → the text is fine; the APP cannot yet present
//                               it correctly.
//
// Any one of them is disqualifying.

export const LEDGER_PATH = "review/human_review_ledger.json";

export function loadLedger(pathOrNull = LEDGER_PATH) {
  if (!existsSync(pathOrNull)) return null;
  return JSON.parse(readFileSync(pathOrNull, "utf8"));
}

/** sha256(ar + NUL + en) — the same construction the admin screen uses. */
export function contentHashOf(record) {
  const ar = record?.text?.ar ?? "";
  const en = record?.text?.en ?? "";
  return createHash("sha256").update(`${ar}\u0000${en}`, "utf8").digest("hex");
}

/**
 * Classifies every record for a PRODUCTION write. Fail-closed: a record is
 * included only if the ledger positively says a human passed its text and
 * nothing holds it back. Everything else lands in one of three excluded
 * buckets, each reported separately because they need different actions.
 *
 * Absence from the ledger is `unreviewed`, not `fine`. That is the whole
 * difference between this and the staging path: staging may write a record
 * nobody has read yet (that is what a trial is for), production may not.
 */
export function classifyForProduction(records, ledger) {
  const byId = new Map();
  for (const r of ledger?.reviews ?? []) byId.set(r.recordId, r);

  const reviewedIncluded = [];
  const unreviewedExcluded = [];
  const blockedExcluded = [];
  const deploymentHeld = [];

  for (const record of records) {
    const review = byId.get(record.duaId);
    if (!review) {
      unreviewedExcluded.push(record.duaId);
      continue;
    }
    if (review.reviewStatus === "blocked" || review.reviewStatus === "failed") {
      blockedExcluded.push(record.duaId);
      continue;
    }
    if (review.deploymentBlocked === true) {
      deploymentHeld.push(record.duaId);
      continue;
    }
    if (review.excludedFromImport === true) {
      // Excluded without either specific flag — treat as blocked rather than
      // guessing which bucket it belongs to.
      blockedExcluded.push(record.duaId);
      continue;
    }
    const passed =
      review.reviewStatus === "passed" || review.textReviewStatus === "passed";
    if (!passed) {
      unreviewedExcluded.push(record.duaId);
      continue;
    }
    reviewedIncluded.push(record);
  }

  return {
    reviewedIncluded,
    unreviewedExcluded,
    blockedExcluded,
    deploymentHeld,
  };
}

/**
 * Splits built records into what may be written and what may not.
 * Pure: takes the ledger as data so tests need no filesystem.
 */
export function applyLedger(records, ledger) {
  const byId = new Map();
  for (const r of ledger?.reviews ?? []) byId.set(r.recordId, r);

  const included = [];
  const excluded = [];
  for (const record of records) {
    const review = byId.get(record.duaId);
    const reasons = [];
    if (review) {
      if (review.reviewStatus === "blocked") {
        reasons.push(
          `review blocked (${review.blockReason || "no reason recorded"})`,
        );
      }
      if (review.deploymentBlocked === true) {
        reasons.push(
          `deployment blocked (${review.deploymentBlockReason || "no reason recorded"})`,
        );
      }
      if (review.excludedFromImport === true) {
        reasons.push("excludedFromImport");
      }
    }
    if (reasons.length) {
      excluded.push({ duaId: record.duaId, reasons });
    } else {
      included.push(record);
    }
  }
  return { included, excluded };
}

/**
 * Production refuses to guess. A missing ledger, an entry naming a record the
 * pack does not contain, or a recorded hash that no longer matches the text
 * all mean the reviews on file no longer describe what is about to be
 * written — and a review that does not describe the text is not a review.
 */
export function assertLedgerMatchesPack(ledger, records, { strict }) {
  if (!strict) return;
  if (!ledger) {
    throw new Error(
      `A production write requires ${LEDGER_PATH}, and it was not found. ` +
        "Writing records nobody has reviewed is exactly what the ledger exists to prevent.",
    );
  }
  const byId = new Map(records.map((r) => [r.duaId, r]));
  const problems = [];
  for (const review of ledger.reviews ?? []) {
    const record = byId.get(review.recordId);
    if (!record) {
      problems.push(`${review.recordId}: reviewed but absent from the pack`);
      continue;
    }
    const actual = contentHashOf(record);
    if (review.reviewedTextHash && review.reviewedTextHash !== actual) {
      problems.push(
        `${review.recordId}: text changed since review ` +
          `(reviewed ${review.reviewedTextHash.slice(0, 12)}…, ` +
          `pack now ${actual.slice(0, 12)}…)`,
      );
    }
    // Page provenance: a reviewer who read page 71 has not vouched for a
    // record that now cites page 94. The citation and the review must
    // describe the same page.
    const reviewedPages = review.reviewedPages ?? [review.reviewedPage];
    if (review.reviewedPage != null && record.printedPage != null) {
      if (reviewedPages[0] !== record.printedPage) {
        problems.push(
          `${review.recordId}: reviewed page ${reviewedPages[0]} but the ` +
            `record now cites page ${record.printedPage}`,
        );
      }
    }
  }
  if (problems.length) {
    throw new Error(
      "The review ledger no longer matches the pack:\n  " +
        problems.join("\n  "),
    );
  }
}

export const STAGING_COLLECTION = "supplications_staging";
export const PRODUCTION_COLLECTION = "supplications";

/**
 * Turns argv into a validated plan, or throws with the reason.
 *
 * The safety rules, in one place so they can be tested without touching a
 * network:
 *
 *   1. Dry-run is the DEFAULT. Without `--write` nothing is ever sent, and
 *      no credentials are even read. `--dry-run` is accepted as an explicit
 *      spelling of the default.
 *   2. `--write` demands exactly one destination: `--staging` or
 *      `--production`. "Write somewhere sensible by default" is how the
 *      wrong collection gets filled.
 *   3. `--limit` is a staging-only affordance for trying one record. It is
 *      REFUSED against production: a partial production import leaves a
 *      collection that is neither empty nor complete, which is the worst of
 *      both.
 *   4. A real write must restate what it is about to do:
 *      `--confirm-project` must equal FIREBASE_PROJECT_ID and
 *      `--confirm-count` must equal the number of records to be written.
 *      A confirmation the operator has to type from the printed plan is the
 *      point — it cannot be satisfied by muscle memory.
 */
export function resolvePlan(argv, env = {}) {
  const flags = argv.filter((a) => a.startsWith("--"));
  const positional = argv.filter((a) => !a.startsWith("--"));

  const known = new Set([
    "--dry-run", "--write", "--staging", "--production", "--limit",
    "--confirm-project", "--confirm-count", "--database",
  ]);
  for (const f of flags) {
    const name = f.split("=")[0];
    if (!known.has(name)) throw new Error(`Unknown flag: ${name}`);
  }

  const has = (n) => flags.some((f) => f === n || f.startsWith(`${n}=`));
  const valueOf = (n) => {
    const hit = flags.find((f) => f.startsWith(`${n}=`));
    if (hit) return hit.slice(n.length + 1);
    const i = argv.indexOf(n);
    return i !== -1 ? argv[i + 1] : undefined;
  };

  const inputPath = positional.find((a) => a.endsWith(".json"));
  if (!inputPath) throw new Error("No source pack given.");

  const write = has("--write");
  const staging = has("--staging");
  const production = has("--production");

  if (staging && production) {
    throw new Error("--staging and --production are mutually exclusive.");
  }

  let limit;
  if (has("--limit")) {
    const raw = valueOf("--limit");
    limit = Number(raw);
    if (!Number.isInteger(limit) || limit < 1) {
      throw new Error(`--limit must be a positive integer, got "${raw}".`);
    }
    if (production) {
      throw new Error(
        "--limit cannot be used with --production. A partial production " +
          "import leaves the collection neither empty nor complete.",
      );
    }
    if (!staging) {
      throw new Error("--limit is only meaningful with --staging.");
    }
  }

  if (!write) {
    // Dry run: destination is only informational, credentials are not read.
    return {
      mode: "dry-run",
      inputPath,
      limit,
      collection: production
        ? PRODUCTION_COLLECTION
        : staging
          ? STAGING_COLLECTION
          : null,
    };
  }

  if (!staging && !production) {
    throw new Error(
      "--write requires an explicit destination: --staging or --production.",
    );
  }

  const collection = production ? PRODUCTION_COLLECTION : STAGING_COLLECTION;
  const projectId = (env.FIREBASE_PROJECT_ID || "").trim();
  const token = (env.FIREBASE_ADMIN_TOKEN || "").trim();
  if (!projectId || !token) {
    throw new Error("Set FIREBASE_PROJECT_ID and FIREBASE_ADMIN_TOKEN.");
  }

  // Firestore database id. Defaults to the only database most projects
  // have. Constrained to Firestore's own id grammar so a stray value cannot
  // be spliced into the REST path.
  const database = (valueOf("--database") || "(default)").trim();
  if (database !== "(default)" && !/^[a-z][a-z0-9-]{2,62}$/.test(database)) {
    throw new Error(
      `--database "${database}" is not a valid Firestore database id.`,
    );
  }

  return {
    mode: "write",
    inputPath,
    limit,
    collection,
    projectId,
    token,
    database,
    confirmProject: valueOf("--confirm-project"),
    confirmCount: valueOf("--confirm-count"),
  };
}

/** Checks the operator's confirmations against the resolved plan. */
export function assertConfirmations(plan, recordCount) {
  if (plan.confirmProject !== plan.projectId) {
    throw new Error(
      `--confirm-project must equal FIREBASE_PROJECT_ID ("${plan.projectId}"), ` +
        `got "${plan.confirmProject ?? "nothing"}".`,
    );
  }
  if (String(plan.confirmCount) !== String(recordCount)) {
    throw new Error(
      `--confirm-count must equal the number of records to write ` +
        `(${recordCount}), got "${plan.confirmCount ?? "nothing"}".`,
    );
  }
}

function printProductionPlan(plan, c) {
  console.log(`Pack:       ${plan.inputPath}`);
  console.log(`Collection: ${plan.collection}`);
  console.log("");
  console.log(`reviewedIncluded:    ${c.reviewedIncluded.length}`);
  for (const r of c.reviewedIncluded) console.log(`  + ${r.duaId}`);
  console.log(`unreviewedExcluded:  ${c.unreviewedExcluded.length}`);
  for (const id of c.unreviewedExcluded) console.log(`  - ${id}`);
  console.log(`blockedExcluded:     ${c.blockedExcluded.length}`);
  for (const id of c.blockedExcluded) console.log(`  - ${id}`);
  console.log(`deploymentHeld:      ${c.deploymentHeld.length}`);
  for (const id of c.deploymentHeld) console.log(`  - ${id}`);
  console.log("");
  console.log("verificationStatus: unverified for every record written.");
  console.log("A reviewed record is imported unverified; an admin verifies it");
  console.log("afterwards in the app. Import never confers verification.");
}

/**
 * The last thing standing between a held-back record and production.
 *
 * Everything above is a filter, and a filter can be bypassed by a flag
 * nobody thought about. This is an assertion on the final set: if any id in
 * it is one the classifier excluded, the run dies rather than writes.
 */
export function assertProductionSetIsClean(records, classification) {
  const forbidden = new Set([
    ...classification.unreviewedExcluded,
    ...classification.blockedExcluded,
    ...classification.deploymentHeld,
  ]);
  const leaked = records.map((r) => r.duaId).filter((id) => forbidden.has(id));
  if (leaked.length) {
    throw new Error(
      "Refusing to write: records the ledger holds back reached the " +
        `production set: ${leaked.join(", ")}`,
    );
  }
}

function printPlan(plan, records, excluded = []) {
  console.log(`Pack:       ${plan.inputPath}`);
  console.log(`Included:   ${records.length}  (zone-tied: ` +
    `${records.filter((r) => r.zoneKey).length})`);
  console.log(`Excluded:   ${excluded.length}  (held back by the review ledger)`);
  for (const e of excluded) {
    console.log(`  - ${e.duaId}: ${e.reasons.join("; ")}`);
  }
  console.log(`Project:    ${plan.projectId ?? "(not read in dry-run)"}`);
  console.log(`Database:   ${plan.database ?? "(not read in dry-run)"}`);
  console.log(`Collection: ${plan.collection ?? "(none — dry-run)"}`);
  if (plan.limit) console.log(`Limit:      ${plan.limit}`);
  console.log("verificationStatus: unverified for every record.");
}

async function main() {
  let plan;
  try {
    plan = resolvePlan(process.argv.slice(2), process.env);
  } catch (err) {
    console.error(err.message);
    console.error(
      "\nUsage:\n" +
        "  node scripts/import_source_pack.mjs <pack.json>            # dry run (default)\n" +
        "  ... --staging --limit 1 --write --confirm-project=<id> --confirm-count=1\n" +
        "  ... --production --write --confirm-project=<id> --confirm-count=<n>",
    );
    process.exit(1);
  }

  const pack = JSON.parse(readFileSync(plan.inputPath, "utf8"));
  const all = buildRecords(pack);

  // The ledger is applied BEFORE --limit. Slicing first could hand the one
  // staging slot to a record the ledger holds back, which is precisely the
  // accident the hold exists to prevent.
  const ledger = loadLedger();
  try {
    assertLedgerMatchesPack(ledger, all, {
      strict: plan.collection === PRODUCTION_COLLECTION && plan.mode === "write",
    });
  } catch (err) {
    console.error(`\n${err.message}`);
    process.exit(1);
  }
  const isProduction = plan.collection === PRODUCTION_COLLECTION;

  let records;
  let excluded;
  if (isProduction) {
    // Fail-closed. Anything the ledger does not positively clear stays out,
    // including every record nobody has read yet.
    const c = classifyForProduction(all, ledger);
    records = c.reviewedIncluded;
    excluded = [
      ...c.blockedExcluded.map((id) => ({ duaId: id, reasons: ["blocked"] })),
      ...c.deploymentHeld.map((id) => ({ duaId: id, reasons: ["deployment hold"] })),
      ...c.unreviewedExcluded.map((id) => ({ duaId: id, reasons: ["unreviewed"] })),
    ];
    printProductionPlan(plan, c);
    // Belt and braces: prove the set about to be written really is the
    // cleared set, whatever any flag above may have done to `records`.
    assertProductionSetIsClean(records, c);
  } else {
    const r = applyLedger(all, ledger);
    excluded = r.excluded;
    records = plan.limit ? r.included.slice(0, plan.limit) : r.included;
    if (!ledger) {
      console.log(`(no ${LEDGER_PATH} found — nothing is held back)`);
    }
    printPlan(plan, records, excluded);
  }

  if (plan.mode === "dry-run") {
    console.log("\nDRY RUN — validated only. Nothing was sent anywhere.");
    return;
  }

  try {
    assertConfirmations(plan, records.length);
  } catch (err) {
    console.error(`\n${err.message}`);
    process.exit(1);
  }

  console.log(`\nWriting ${records.length} record(s) to ${plan.collection}...`);
  for (const record of records) {
    const fields = {};
    for (const [k, v] of Object.entries(record)) fields[k] = toFirestoreValue(v);

    const url =
      `https://firestore.googleapis.com/v1/projects/${plan.projectId}` +
      `/databases/${plan.database}/documents/${plan.collection}` +
      `/${encodeURIComponent(record.duaId)}`;

    const res = await fetch(url, {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${plan.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ fields }),
    });

    if (!res.ok) {
      console.error(`FAILED ${record.duaId}: ${res.status} ${await res.text()}`);
      process.exit(1);
    }
    console.log(`upserted ${record.duaId}`);
  }
}

// Only run when invoked directly, so tests can import `buildRecords`.
if (process.argv[1] && process.argv[1].endsWith("import_source_pack.mjs")) {
  main().catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
}
