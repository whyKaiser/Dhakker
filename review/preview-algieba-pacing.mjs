/** Two local samples after the user rejected excessively long vowels.
 * Uses only the existing Cloud TTS endpoint; no remote writes or IAM changes.
 */
import assert from "node:assert/strict";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { spawnSync } from "node:child_process";
import { SYNTHESIS_ENDPOINT } from "../scripts/generate_dua_audio.mjs";
import { sha256, validateMp3, PROJECT } from "./publish-algieba-audio.mjs";
import { deriveSpeechText } from "./dua-speech-text.mjs";

export const TEXT = "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً، وَفِي الْآخِرَةِ حَسَنَةً، وَقِنَا عَذَابَ النَّارِ.";
export const PROMPT = "Read the provided Arabic text verbatim in clear Modern Standard Arabic. Use a composed, deep male speaking voice and connected, natural prose delivery at a normal conversational pace. This is spoken supplication, not a melodic recitation: do not chant, sing, stretch vowels, or elongate syllables for dramatic effect. Preserve the normal linguistic long vowels without dragging them. Especially keep rabbana and atina concise and connected. Make only brief natural pauses at commas. Do not add, repeat, omit, paraphrase or translate any words. Speak only the text, never these directions.";
export function requestBody(mode) {
  assert.ok(["--chirp", "--directed"].includes(mode));
  return mode === "--chirp" ? {
    input: { text: TEXT },
    voice: { languageCode: "ar-XA", name: "ar-XA-Chirp3-HD-Algieba" },
    audioConfig: { audioEncoding: "MP3", speakingRate: 1.15 },
  } : {
    input: { text: TEXT, prompt: PROMPT },
    voice: { languageCode: "ar-001", name: "Algieba", modelName: "gemini-2.5-flash-tts" },
    audioConfig: { audioEncoding: "MP3" },
  };
}
export async function main(args) {
  assert.equal(args.length, 1);
  const body = requestBody(args[0]);
  const source = JSON.parse(await readFile(new URL("algieba-pronunciation-fix-2026-09-10/speech-plan.json", import.meta.url), "utf8"));
  const row = source.records.find(r => r.id === "moia-mukhtasar-1446-general-001");
  // Normal vowels and punctuation are the only additions to official spelling.
  const plain = TEXT.replace(/\p{M}/gu, "").replace(/[،.]/gu, "");
  assert.equal(plain, deriveSpeechText(row.id, row.canonicalText).speechText);
  const dir = fileURLToPath(new URL("algieba-pacing-preview-2026-09-10/", import.meta.url));
  await mkdir(dir, { recursive: true });
  const name = args[0] === "--chirp" ? "01-algieba-paced" : "02-algieba-directed";
  const path = resolve(dir, name + ".mp3");
  try { await readFile(path); throw new Error("Sample already exists; refusing paid regeneration"); }
  catch (e) { if (e.code !== "ENOENT") throw e; }
  const token = process.env.GOOGLE_ACCESS_TOKEN;
  assert.ok(token, "Short-lived Google token required");
  const response = await fetch(SYNTHESIS_ENDPOINT, { method: "POST", redirect: "error",
    headers: { Authorization: `Bearer ${token}`, "x-goog-user-project": PROJECT, "Content-Type": "application/json" },
    body: JSON.stringify(body), signal: AbortSignal.timeout(45000) });
  if (!response.ok) {
    const error = await response.json();
    console.error(JSON.stringify({ status: response.status, code: error.error?.status, message: error.error?.message }));
    throw new Error("Sample synthesis failed; no service or permission was changed");
  }
  const result = await response.json();
  assert.ok(result.audioContent);
  const bytes = Buffer.from(result.audioContent, "base64");
  validateMp3(bytes);
  await writeFile(path, bytes, { flag: "wx" });
  const probe = spawnSync("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "json", path], { encoding: "utf8" });
  assert.equal(probe.status, 0);
  const durationSeconds = Number(JSON.parse(probe.stdout).format.duration);
  assert.ok(durationSeconds > 0 && Number.isFinite(durationSeconds));
  const manifest = { project: PROJECT, sourceId: row.id, canonicalTextSha256: row.canonicalTextSha256,
    request: body, audioSha256: sha256(bytes), bytes: bytes.length, durationSeconds,
    file: name + ".mp3", humanListeningStatus: "pending", published: false };
  await writeFile(resolve(dir, name + ".json"), JSON.stringify(manifest, null, 2), { flag: "wx" });
  console.log(JSON.stringify({ path, durationSeconds, audioSha256: manifest.audioSha256, published: false }));
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main(process.argv.slice(2)).catch(error => { console.error(error.message); process.exitCode = 1; });
}
