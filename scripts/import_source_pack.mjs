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
 *   export FIREBASE_PROJECT_ID=your-project-id
 *   export FIREBASE_ADMIN_TOKEN=$(gcloud auth print-access-token)
 *   node scripts/import_source_pack.mjs source_packs/<pack>.json [--dry-run]
 *
 * `--dry-run` validates the pack and prints what would be written without
 * contacting Firestore. It needs no credentials, and is what CI/tests use.
 * The script is idempotent: the Firestore document id is the record's
 * `duaId`, so re-running updates rather than duplicates.
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

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes("--dry-run");
  const inputPath = args.find((a) => !a.startsWith("--"));

  if (!inputPath) {
    console.error(
      "Usage: node scripts/import_source_pack.mjs source_packs/<pack>.json [--dry-run]",
    );
    process.exit(1);
  }

  const pack = JSON.parse(readFileSync(inputPath, "utf8"));
  const records = buildRecords(pack);

  const zoneTied = records.filter((r) => r.zoneKey).length;
  console.log(`Pack: ${inputPath}`);
  console.log(`Records: ${records.length}  (zone-tied: ${zoneTied})`);
  console.log("All records will be written with verificationStatus=unverified.");

  if (dryRun) {
    console.log("--dry-run: validated only, nothing written.");
    return;
  }

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const token = process.env.FIREBASE_ADMIN_TOKEN;
  if (!projectId || !token) {
    console.error("Set FIREBASE_PROJECT_ID and FIREBASE_ADMIN_TOKEN.");
    process.exit(1);
  }

  for (const record of records) {
    const fields = {};
    for (const [k, v] of Object.entries(record)) fields[k] = toFirestoreValue(v);

    const url =
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)` +
      `/documents/supplications/${encodeURIComponent(record.duaId)}`;

    const res = await fetch(url, {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${token}`,
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
