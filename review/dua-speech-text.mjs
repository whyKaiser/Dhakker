import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";

export const CORPUS_SHA256 = "d2960b3217962e7e4252abdcece67bea3d6b48271e4cd3af45bbbb2dd5c872ca";
const root = new URL("../", import.meta.url);
const bytes = readFileSync(new URL("third_party/kfgqpc/hafsData_v2-0.json", root));
// Git's Windows checkout adds CRLF to JSON formatting. Normalize only those
// file line endings before checking the pinned bytes; no Arabic is folded.
assert.equal(createHash("sha256").update(bytes.toString("utf8").replace(/\r\n/g, "\n")).digest("hex"), CORPUS_SHA256);
const corpus = JSON.parse(bytes);
const authority = JSON.parse(readFileSync(new URL("source_packs/quran_authority_hafs_uthmani.json", root)));
const refs = new Map(authority.ayat.map(a => [a.duaId, a]));
const byAyah = new Map(corpus.map(a => [`${a.sura_no}:${a.aya_no}`, a]));
const words = text => text.trim().split(/\s+/u);
const withoutMarkers = text => text.replace(/[\uFB50-\uFDFF\uFE70-\uFEFF]/gu, "").trim();
export const SPECIAL_SPEECH_MARKS = /(?:[\u0653-\u065F]|\u0670|\u0671|[\u06D6-\u06ED])/u;

/** The canonical/display text is NEVER changed. Quranic pronunciation uses
 * the same edition's spelling field, not a destructive mark-stripping guess.
 * Alignment must be exact, unique, whole-word and one-to-one or we stop.
 */
export function deriveSpeechText(id, canonicalText) {
  const ref = refs.get(id);
  if (!ref) {
    // The nine non-Quranic records only carry a redundant dagger alif after
    // an existing alif maqsura (علىٰ / إلىٰ / النوىٰ). Keep ordinary vowels.
    const text = canonicalText.replace(/ى\u0670/gu, "ى");
    assert.ok(!SPECIAL_SPEECH_MARKS.test(text), `${id}: unhandled speech symbol`);
    return { speechText: text, strategy: text === canonicalText ? "unchanged" : "redundant-dagger-alif", source: null };
  }
  assert.equal(canonicalText, ref.officialText, `${id}: canonical text differs from pinned authority`);
  const pairs = [];
  for (const ayah of ref.ayahNumbers) {
    const row = byAyah.get(`${ref.surahNumber}:${ayah}`);
    assert.ok(row, `${id}: missing official ayah`);
    const displayed = words(withoutMarkers(row.aya_text));
    const spoken = words(row.aya_text_emlaey);
    assert.equal(displayed.length, spoken.length, `${id}: word alignment needs manual review`);
    pairs.push(...displayed.map((word, i) => ({ word, spoken: spoken[i], ayah })));
  }
  const quote = words(canonicalText);
  const starts = pairs.flatMap((_, i) => quote.every((w, j) => pairs[i + j]?.word === w) ? [i] : []);
  assert.equal(starts.length, 1, `${id}: quote is not a unique whole-word official span`);
  const selected = pairs.slice(starts[0], starts[0] + quote.length);
  const speechText = selected.map((p, i) => {
    const next = selected[i + 1];
    const pause = next && (p.ayah !== next.ayah || /[\u06D6-\u06DC]/u.test(p.word));
    return p.spoken + (pause ? "،" : "");
  }).join(" ");
  assert.ok(!/\p{M}/u.test(speechText), `${id}: spelling field unexpectedly has marks`);
  assert.ok(!SPECIAL_SPEECH_MARKS.test(speechText));
  return { speechText, strategy: "official-emlaey-aligned", source: {
    authority: "KFGQPC Hafs Uthmanic Data v2.0", corpusSha256: CORPUS_SHA256,
    field: "aya_text_emlaey", surahNumber: ref.surahNumber, ayahNumbers: ref.ayahNumbers,
    firstWord: starts[0], wordCount: quote.length,
  } };
}
