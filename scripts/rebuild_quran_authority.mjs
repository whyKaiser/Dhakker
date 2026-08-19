#!/usr/bin/env node
/**
 * Rebuilds `source_packs/quran_authority_hafs_uthmani.json` (and the Quranic
 * text of the 23 records in the MOIA source pack) from the OFFICIAL DATA
 * PINNED IN THIS REPOSITORY at `third_party/kfgqpc/hafsData_v2-0.json`.
 *
 * This reads only that local file. There is no network path: the official
 * archive (UthmanicHafs_v2-0.zip, KFGQPC Hafs Uthmanic Data v2.0, 2022-09-07)
 * was supplied by the project owner and committed, so the authority travels
 * with the repository and the comparison is reproducible offline.
 *
 * ── Rules it enforces ───────────────────────────────────────────────────
 *
 * 1. Text comes from `aya_text` — the display field. `aya_text_emlaey` is
 *    used ONLY to align a quoted portion to its position; it is never
 *    stored or displayed.
 * 2. The āyah-number marker is removed on storage, together with the space
 *    that introduces it — including the marker BETWEEN two āyāt of a
 *    multi-āyah record. Nothing else is normalised: waqf marks and every
 *    diacritic stay exactly as published.
 * 3. A quoted portion is located by aligning consonantal skeletons and then
 *    SLICED from the official string. If a record does not align uniquely
 *    the script aborts rather than guess — no character is ever typed,
 *    patched, or assembled by hand.
 * 4. It never sets `verificationStatus`. Verification stays a human act.
 *
 * ── Usage ───────────────────────────────────────────────────────────────
 *   node scripts/rebuild_quran_authority.mjs --check   # verify, write nothing
 *   node scripts/rebuild_quran_authority.mjs           # rebuild in place
 *
 * `test/quran_text_authority_test.dart` asserts the same invariants against
 * the pinned file, so CI fails if the committed text ever drifts from it.
 */

import { readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";

const OFFICIAL = "third_party/kfgqpc/hafsData_v2-0.json";
const MANIFEST = "source_packs/quran_authority_hafs_uthmani.json";
const PACK = "source_packs/moia_mukhtasar_1446_umrah.json";

// The exact file this project was built against. A different edition is not
// automatically wrong, but it is a different authority — so it must be an
// explicit, reviewed change, never a silent swap.
const EXPECTED_SHA256 =
  "d2960b3217962e7e4252abdcece67bea3d6b48271e4cd3af45bbbb2dd5c872ca";

const isMarker = (c) => {
  const n = c.codePointAt(0);
  return (n >= 0xfb50 && n <= 0xfdff) || (n >= 0xfe70 && n <= 0xfeff);
};

function dropAyahMarkers(text) {
  let out = "";
  for (const c of text) {
    if (isMarker(c)) {
      out = out.replace(/[  ]+$/, "");
      continue;
    }
    out += c;
  }
  return out.replace(/ {2,}/g, " ").trim();
}

// Alignment only — never stored. Folds the carrier variants the two texts
// spell differently so a quoted portion can be located inside the āyah.
const FOLD = { "أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا", "ى": "ي", "ة": "ه" };
const isLetter = (c) => /[ء-يٱـ]/.test(c);

function skeleton(text) {
  let s = "";
  const pos = [];
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (!isLetter(c)) continue;
    s += FOLD[c] ?? c;
    pos.push(i);
  }
  return { s, pos };
}

function main() {
  const check = process.argv.includes("--check");

  const raw = readFileSync(OFFICIAL);
  const sha = createHash("sha256").update(raw).digest("hex");
  if (sha !== EXPECTED_SHA256) {
    console.error(
      `${OFFICIAL} does not match the pinned KFGQPC v2.0 file.\n` +
        `  expected ${EXPECTED_SHA256}\n  actual   ${sha}\n` +
        "Refusing to rebuild: the text authority must be an explicit change.",
    );
    process.exit(1);
  }

  const official = JSON.parse(raw.toString("utf8"));
  const byRef = new Map(
    official.map((r) => [`${r.sura_no}:${r.aya_no}`, r]),
  );

  const manifest = JSON.parse(readFileSync(MANIFEST, "utf8"));
  const pack = JSON.parse(readFileSync(PACK, "utf8"));
  const entries = new Map(pack.entries.map((e) => [e.duaId, e]));

  let rebuilt = 0;
  for (const a of manifest.ayat) {
    const parts = a.ayahNumbers.map((n) => {
      const row = byRef.get(`${a.surahNumber}:${n}`);
      if (!row) {
        console.error(`${a.duaId}: ${a.surahNumber}:${n} not in ${OFFICIAL}`);
        process.exit(1);
      }
      return row.aya_text.trim();
    });
    const full = dropAyahMarkers(parts.join(" "));

    const recorded = entries.get(a.duaId).text.ar.trim();
    const off = skeleton(full);
    const rec = skeleton(recorded);
    const at = off.s.indexOf(rec.s);
    if (at === -1 || off.s.indexOf(rec.s, at + 1) !== -1) {
      console.error(
        `${a.duaId}: cannot locate the quoted text uniquely inside the ` +
          "official āyah. Aborting rather than guessing.",
      );
      process.exit(1);
    }

    const start = off.pos[at];
    let end = off.pos[at + rec.s.length - 1] + 1;
    // extend over the diacritics attached to the final letter
    while (end < full.length && /\p{Mn}/u.test(full[end])) end++;
    const span = full.slice(start, end);

    a.officialText = span;
    a.officialFullAyahText = full;
    a.isPortionOfAyah = span !== full;
    a.fetched = true;
    entries.get(a.duaId).text.ar = span;
    entries.get(a.duaId).isPortionOfAyah = a.isPortionOfAyah;
    rebuilt++;
  }

  console.log(`Official file: ${OFFICIAL} (sha256 ok, ${official.length} āyāt)`);
  console.log(`Edition:       ${manifest.editionLabel} · ${manifest.editionDate}`);
  console.log(`Rebuilt:       ${rebuilt} records`);
  console.log("verificationStatus untouched — verification stays a human act.");

  if (check) {
    console.log("--check: nothing written.");
    return;
  }
  writeFileSync(MANIFEST, `${JSON.stringify(manifest, null, 2)}\n`);
  writeFileSync(PACK, `${JSON.stringify(pack, null, 2)}\n`);
}

main();
