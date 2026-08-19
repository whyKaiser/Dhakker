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

import { readFileSync } from "node:fs";

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

    const textAr = String(entry?.text?.ar || "").trim();
    if (!textAr) throw new Error(`${where}: empty Arabic text.`);

    return {
      duaId,
      zoneKey,
      // `zoneId` stays whatever the pack carries (usually empty): binding a
      // record to this project's zone documents is a separate, deliberate
      // admin step, not something an importer guesses.
      zoneId: String(entry?.zoneId || ""),
      contentKind,
      title: entry?.title ?? {},
      text: entry?.text ?? {},
      tagsAr: entry?.tagsAr ?? [],
      tagsEn: entry?.tagsEn ?? [],
      languageCodes: entry?.languageCodes ?? ["ar"],
      isActive: entry?.isActive !== false,
      audioMode: "tts",
      audioUrl: "",
      usage_count: 0,

      // Provenance, carried through for the human verifier to check against.
      authority: String(entry?.authority || ""),
      sourceUrl: String(entry?.sourceUrl || ""),
      sourceVersion: String(entry?.sourceVersion || ""),
      sourceSection: String(entry?.sourceSection || ""),
      printedPage: entry?.printedPage ?? null,

      // Forced, regardless of input. See guarantee (2) above.
      verificationStatus: "unverified",
      verifiedAt: null,
      verifiedBy: null,
      revokedAt: null,
    };
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
    "--confirm-project", "--confirm-count",
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

  return {
    mode: "write",
    inputPath,
    limit,
    collection,
    projectId,
    token,
    database: "(default)",
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

function printPlan(plan, records) {
  console.log(`Pack:       ${plan.inputPath}`);
  console.log(`Records:    ${records.length}  (zone-tied: ` +
    `${records.filter((r) => r.zoneKey).length})`);
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
  const records = plan.limit ? all.slice(0, plan.limit) : all;

  printPlan(plan, records);

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
