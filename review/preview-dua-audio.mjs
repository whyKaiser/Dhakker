/** Local listening samples only. Never writes Firestore or Cloud Storage. */
import { createHash } from "node:crypto";
import { access, mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { fromFirestoreValue } from "../scripts/import_source_pack.mjs";
import {
  ineligibilityReason,
  synthesise,
  SYNTHESIS_ENDPOINT,
  VOICES_ENDPOINT,
} from "../scripts/generate_dua_audio.mjs";

export const PROJECT = "dhakker-160d0";
export const VOICE = "ar-XA-Chirp3-HD-Charon";
export const SAMPLES = Object.freeze([
  { id: "moia-mukhtasar-1446-general-036", file: "01-short-charon.mp3" },
  { id: "moia-mukhtasar-1446-umrah-talbiyah", file: "02-talbiyah-charon.mp3" },
  { id: "moia-mukhtasar-1446-general-034", file: "03-long-charon.mp3" },
]);
export const COMPARISON_VOICES = Object.freeze(["Orus", "Alnilam", "Algenib"]);
export const ALTERNATIVE_VOICES = Object.freeze(["Sadaltager", "Algieba"]);
const COMPARISON_SAMPLES = COMPARISON_VOICES.map((name, index) => ({
  id: SAMPLES[1].id,
  file: `0${index + 1}-talbiyah-${name.toLowerCase()}.mp3`,
  voice: `ar-XA-Chirp3-HD-${name}`,
}));
const ALTERNATIVE_SAMPLES = ALTERNATIVE_VOICES.map((name, index) => ({
  id: SAMPLES[1].id,
  file: `0${index + 1}-talbiyah-${name.toLowerCase()}.mp3`,
  voice: `ar-XA-Chirp3-HD-${name}`,
}));
const DOCUMENT_BASE =
  `https://firestore.googleapis.com/v1/projects/${PROJECT}` +
  "/databases/(default)/documents/supplications/";
const OUTPUT = fileURLToPath(new URL("./audio-preview-2026-09-10/", import.meta.url));
const COMPARISON_OUTPUT = fileURLToPath(new URL("./audio-voice-comparison-2026-09-10/", import.meta.url));
const ALTERNATIVE_OUTPUT = fileURLToPath(new URL("./audio-voice-alternatives-2026-09-10/", import.meta.url));

export function assertRequestAllowed(url, method, generate) {
  const allowedRead = method === "GET" && (
    url === `${VOICES_ENDPOINT}?languageCode=ar-XA` ||
    SAMPLES.some(({ id }) => url === DOCUMENT_BASE + encodeURIComponent(id))
  );
  const allowedSynthesis = generate && method === "POST" && url === SYNTHESIS_ENDPOINT;
  if (!allowedRead && !allowedSynthesis) throw new Error("Preview request blocked");
}

export function validateSample(doc, id) {
  const reason = ineligibilityReason({ ...doc, documentId: id });
  if (reason || doc.isActive !== true || doc.deploymentBlocked === true ||
      doc.excludedFromImport === true || doc.reviewStatus === "blocked") {
    throw new Error(`${id}: not eligible for a listening sample (${reason ?? "held/inactive"})`);
  }
  const text = doc.text.ar;
  if (Buffer.byteLength(text, "utf8") > 5000) throw new Error(`${id}: exceeds input byte limit`);
  return text;
}

export async function runPreview({ token, generate = false, compare = false, more = false }, deps = {}) {
  if (!token) throw new Error("GOOGLE_ACCESS_TOKEN must contain a short-lived gcloud token");
  if (compare && more) throw new Error("Choose one comparison set per run");
  const samples = more ? ALTERNATIVE_SAMPLES : compare ? COMPARISON_SAMPLES : SAMPLES.map(s => ({ ...s, voice: VOICE }));
  const output = more ? ALTERNATIVE_OUTPUT : compare ? COMPARISON_OUTPUT : OUTPUT;
  const doFetch = deps.fetch ?? globalThis.fetch;
  const guardedFetch = async (url, options = {}) => {
    assertRequestAllowed(url, options.method ?? "GET", generate);
    const res = await doFetch(url, {
      ...options,
      headers: {
        ...options.headers,
        Authorization: `Bearer ${token}`,
        "x-goog-user-project": PROJECT,
      },
      signal: AbortSignal.timeout(45000),
    });
    if (!res.ok) {
      // Do not log response bodies, credentials, or signed URLs.
      throw new Error(`Google preview request failed: HTTP ${res.status}`);
    }
    return res;
  };

  const voices = await (await guardedFetch(`${VOICES_ENDPOINT}?languageCode=ar-XA`)).json();
  if (!samples.every(s => voices.voices?.some(v => v.name === s.voice && v.languageCodes?.includes("ar-XA")))) {
    throw new Error("Chosen Arabic Chirp 3 HD voice is unavailable; no automatic fallback");
  }
  const rows = [];
  const documents = new Map();
  for (const sample of samples) {
    if (!documents.has(sample.id)) {
      documents.set(sample.id, await (await guardedFetch(DOCUMENT_BASE + encodeURIComponent(sample.id))).json());
    }
    const raw = documents.get(sample.id);
    const doc = Object.fromEntries(Object.entries(raw.fields ?? {}).map(([k, v]) => [k, fromFirestoreValue(v)]));
    const text = validateSample(doc, sample.id);
    rows.push({
      ...sample,
      title: doc.title?.ar ?? sample.id,
      text,
      sourceUpdateTime: raw.updateTime,
      textSha256: createHash("sha256").update(text).digest("hex"),
    });
  }
  const characters = rows.reduce((sum, row) => sum + [...row.text].length, 0);
  if (characters > 2000) throw new Error("Preview exceeds the 2,000-character budget");
  const manifest = {
    project: PROJECT,
    voices: [...new Set(samples.map(s => s.voice))],
    syntheticVoice: true,
    listeningReviewPassed: false,
    published: false,
    generatedAt: generate ? new Date().toISOString() : null,
    characters,
    estimatedSynthesisUsdBeforeFreeTier: characters * 0.00003,
    samples: rows,
  };
  if (!generate) return manifest;

  // Refuse a second paid run over existing files. No overwrite or silent retry.
  const files = [...rows.map(r => r.file), "manifest.json"];
  for (const file of files) {
    try {
      await access(resolve(output, file));
    } catch (error) {
      if (error.code === "ENOENT") continue;
      throw error;
    }
    throw new Error(`Output already exists: ${file}`);
  }
  await mkdir(output, { recursive: true });
  for (const row of rows) {
    const bytes = await synthesise(row.text, row.voice, { token }, { fetch: guardedFetch });
    const hasMp3Header = bytes.subarray(0, 3).toString() === "ID3" ||
      (bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0);
    if (!hasMp3Header) throw new Error("Synthesis did not return an MP3 stream");
    await writeFile(resolve(output, row.file), bytes, { flag: "wx" });
    row.audioBytes = bytes.length;
    row.audioSha256 = createHash("sha256").update(bytes).digest("hex");
    console.log(`Generated local sample: ${row.file} (${bytes.length} bytes)`);
  }
  await writeFile(resolve(output, "manifest.json"), JSON.stringify(manifest, null, 2), { flag: "wx" });
  return manifest;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const args = process.argv.slice(2);
    if (args.length > 2 || new Set(args).size !== args.length || args.some(a => !["--generate", "--compare", "--compare-more"].includes(a))) {
      throw new Error("Usage: node review/preview-dua-audio.mjs [--generate] [--compare | --compare-more]");
    }
    const manifest = await runPreview({ token: process.env.GOOGLE_ACCESS_TOKEN, generate: args.includes("--generate"), compare: args.includes("--compare"), more: args.includes("--compare-more") });
    console.log(JSON.stringify(manifest, null, 2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
