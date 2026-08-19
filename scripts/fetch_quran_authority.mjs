#!/usr/bin/env node
/**
 * Fills `source_packs/quran_authority_hafs_uthmani.json` with the Quranic
 * text for the 23 āyāt referenced by the MOIA source pack.
 *
 * NOTE: the manifest is already filled from the OFFICIAL ARCHIVE pinned at
 * `third_party/kfgqpc/hafsData_v2-0.json` (KFGQPC Hafs Uthmanic Data v2.0,
 * 2022-09-07), which the project owner supplied directly. That pinned file
 * is the authority the tests compare against, and it needs no network. This
 * script remains for refreshing the manifest against a future edition.
 *
 * ── The one rule this script exists to enforce ──────────────────────────
 *
 * The Quranic text MUST come from the official digital text published by
 * مجمع الملك فهد لطباعة المصحف الشريف (King Fahd Complex), Hafs ʿan ʿĀṣim,
 * Uthmani rasm. It may NOT come from OCR of a scanned page, from a model's
 * memory, from a third-party mirror, or from hand-assembly of characters.
 *
 * That is not a stylistic preference. A single wrong diacritic in a text a
 * pilgrim will recite is a defect no amount of review elsewhere compensates
 * for, and a model reproducing an āyah "from memory" produces text that
 * looks right and cannot be trusted. So this script refuses to write any
 * text it did not receive from an allow-listed official host, and it never
 * synthesises a character.
 *
 * ── Usage ───────────────────────────────────────────────────────────────
 *   node scripts/fetch_quran_authority.mjs            # fetch and fill
 *   node scripts/fetch_quran_authority.mjs --check    # report status only
 *
 * Run it from a network that can reach the official platform. In a sandbox
 * whose egress policy blocks that host the script exits non-zero WITHOUT
 * touching the file — a blocked fetch must never degrade into a guess.
 *
 * ── Endpoint ────────────────────────────────────────────────────────────
 * The official developer platform is at
 * <https://qurancomplex.gov.sa/techquran/dev/>. Set QURAN_AUTHORITY_ENDPOINT
 * to the concrete text/API endpoint that platform documents for your
 * access, and QURAN_AUTHORITY_EDITION to the edition/version label it
 * reports. Both are recorded in the output file so a reviewer can see
 * exactly which release the text came from.
 */

import { readFileSync, writeFileSync } from "node:fs";

const MANIFEST = "source_packs/quran_authority_hafs_uthmani.json";

// Only these hosts may supply Quranic text. A mirror — however accurate —
// is not the authority this project cites, so it is not accepted here.
const ALLOWED_HOSTS = ["qurancomplex.gov.sa", "api.qurancomplex.gov.sa"];

function assertOfficialHost(endpoint) {
  const host = new URL(endpoint).hostname.toLowerCase();
  const ok = ALLOWED_HOSTS.some((h) => host === h || host.endsWith(`.${h}`));
  if (!ok) {
    throw new Error(
      `Refusing to fetch Quranic text from "${host}". Only the official ` +
        `King Fahd Complex platform is accepted: ${ALLOWED_HOSTS.join(", ")}.`,
    );
  }
}

function report(manifest) {
  const filled = manifest.ayat.filter((a) => a.fetched && a.officialText).length;
  console.log(`Manifest: ${MANIFEST}`);
  console.log(`Status:   ${manifest.status}`);
  console.log(`Āyāt:     ${manifest.ayat.length} referenced, ${filled} fetched`);
  if (filled < manifest.ayat.length) {
    console.log(
      "\nThe official text has NOT been fetched. Until it is, no record may " +
        "claim مجمع الملك فهد as its text authority.",
    );
  }
}

async function main() {
  const manifest = JSON.parse(readFileSync(MANIFEST, "utf8"));

  if (process.argv.includes("--check")) {
    report(manifest);
    return;
  }

  const endpoint = process.env.QURAN_AUTHORITY_ENDPOINT;
  if (!endpoint) {
    console.error(
      "Set QURAN_AUTHORITY_ENDPOINT to the official King Fahd Complex text " +
        "endpoint (see https://qurancomplex.gov.sa/techquran/dev/).",
    );
    process.exit(1);
  }
  assertOfficialHost(endpoint);

  const edition = (process.env.QURAN_AUTHORITY_EDITION || "").trim();
  if (!edition) {
    console.error(
      "Set QURAN_AUTHORITY_EDITION to the edition/version label the official " +
        "platform reports. An unlabelled text cannot be cited.",
    );
    process.exit(1);
  }

  for (const ayah of manifest.ayat) {
    const parts = [];
    for (const number of ayah.ayahNumbers) {
      const url = `${endpoint}${endpoint.includes("?") ? "&" : "?"}` +
        `surah=${ayah.surahNumber}&ayah=${number}`;
      const res = await fetch(url);
      if (!res.ok) {
        console.error(
          `FAILED ${ayah.surahNumber}:${number} — HTTP ${res.status}. ` +
            "Nothing written; the manifest is unchanged.",
        );
        process.exit(1);
      }
      const body = await res.json();
      const text = (body.text || body.aya_text || body.ayah || "").trim();
      if (!text) {
        console.error(
          `EMPTY response for ${ayah.surahNumber}:${number}. Nothing written.`,
        );
        process.exit(1);
      }
      parts.push(text);
    }
    // Multi-āyah entries are joined by the verse separator the source itself
    // prints between them. No other transformation is applied — the text is
    // stored exactly as the authority returned it.
    ayah.officialText = parts.join(" ۝ ");
    ayah.fetched = true;
  }

  manifest.editionLabel = edition;
  manifest.fetchedAt = new Date().toISOString();
  manifest.status = "fetched";
  writeFileSync(MANIFEST, `${JSON.stringify(manifest, null, 2)}\n`);
  report(manifest);
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
