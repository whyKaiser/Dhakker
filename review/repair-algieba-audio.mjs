/** Prepare pronunciation repairs locally. This command deliberately has NO
 * publication operation: a human must listen to the corrected sample first.
 * --prepare reads current records; --sample / --generate create local MP3s.
 */
import assert from "node:assert/strict";
import { readFile, writeFile, mkdir, rename } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { spawnSync } from "node:child_process";
import { fromFirestoreValue } from "../scripts/import_source_pack.mjs";
import { SYNTHESIS_ENDPOINT, ineligibilityReason } from "../scripts/generate_dua_audio.mjs";
import { deriveSpeechText } from "./dua-speech-text.mjs";
import { PROJECT, VOICE, sha256, validateMp3, synthesiseWithSentenceLimit, assertSnapshotUnchanged } from "./publish-algieba-audio.mjs";

const ROOT = fileURLToPath(new URL("../", import.meta.url));
export const OUTPUT = resolve(ROOT, "review/algieba-pronunciation-fix-2026-09-10");
const PRIVATE = resolve(ROOT, ".local/dua-pronunciation-fix-2026-09-10");
const SNAPSHOT = resolve(PRIVATE, "snapshot.json");
const MANIFEST = resolve(OUTPUT, "manifest.json");
const PREFIX = `projects/${PROJECT}/databases/(default)/documents/supplications/`;
const COLLECTION = `https://firestore.googleapis.com/v1/${PREFIX.slice(0, -1)}`;
export const SAMPLE_ID = "moia-mukhtasar-1446-general-001";
const load = async path => JSON.parse(await readFile(path, "utf8"));
async function save(path, value) {
  await mkdir(resolve(path, ".."), { recursive: true });
  await writeFile(path + ".tmp", JSON.stringify(value, null, 2));
  await rename(path + ".tmp", path);
}
async function optional(path) {
  try { return await load(path); } catch (e) { if (e.code === "ENOENT") return null; throw e; }
}
const plain = raw => Object.fromEntries(Object.entries(raw.fields ?? {}).map(([k, v]) => [k, fromFirestoreValue(v)]));

export function buildRepairPlan(documents, originals) {
  assert.equal(documents.length, 53, "Live record count changed");
  assert.equal(new Set(documents.map(r => r.name)).size, 53, "Duplicate record");
  const checked = documents.map(raw => {
    assert.ok(raw.name.startsWith(PREFIX));
    const id = raw.name.slice(PREFIX.length);
    assert.match(id, /^[a-zA-Z0-9_-]+$/u);
    assert.ok(raw.updateTime);
    const data = plain(raw);
    // Replacing known, owner-requested audio is the sole exception here;
    // all ordinary content/review eligibility gates still apply.
    assert.equal(ineligibilityReason({ ...data, documentId: id, audioUrl: "" }), null);
    assert.equal(data.verificationStatus, "verified");
    assert.equal(data.isActive, true);
    assert.equal(data.revokedAt, null);
    assert.notEqual(data.deploymentBlocked, true);
    assert.notEqual(data.excludedFromImport, true);
    assert.notEqual(data.reviewStatus, "blocked");
    assert.equal(data.audioMode, "file");
    assert.ok(data.audioUrl?.startsWith("https://firebasestorage.googleapis.com/v0/b/dhakker-160d0.firebasestorage.app/o/"));
    const original = originals.find(r => r.id === id);
    assert.ok(original, `${id}: unknown source`);
    const audioUrl = new URL(data.audioUrl);
    assert.equal(decodeURIComponent(audioUrl.pathname), `/v0/b/dhakker-160d0.firebasestorage.app/o/audio/duas/algieba-${original.audioSha256}.mp3`, `${id}: audio was replaced outside this repair`);
    assert.equal(data.text?.ar, original.text, `${id}: canonical text changed`);
    const derived = deriveSpeechText(id, data.text.ar);
    return { id, name: raw.name, updateTime: raw.updateTime, title: data.title?.ar ?? id,
      canonicalText: data.text.ar, canonicalTextSha256: sha256(data.text.ar), ...derived,
      speechTextSha256: sha256(derived.speechText), previousAudioSha256: original.audioSha256,
      file: `${id}.mp3` };
  }).sort((a, b) => a.id.localeCompare(b.id));
  const records = checked.filter(r => r.strategy !== "unchanged");
  assert.equal(records.length, 31, "Affected set changed; inspect before generating");
  const unique = [...new Map(records.map(r => [r.speechTextSha256, r])).values()];
  const characters = unique.reduce((n, r) => n + [...r.speechText].length, 0);
  assert.ok(characters < 12000, "Generation budget exceeded");
  return { project: PROJECT, voice: VOICE, checkedRecords: checked.length, records,
    unchangedIds: checked.filter(r => r.strategy === "unchanged").map(r => r.id),
    uniqueSpeechTexts: unique.length, characters,
    planHash: sha256(JSON.stringify(records.map(r => [r.id, r.updateTime, r.canonicalTextSha256, r.speechTextSha256]))) };
}

export function requestFor(token, mode) {
  assert.ok(token, "GOOGLE_ACCESS_TOKEN required");
  return async (url, options = {}) => {
    const method = options.method ?? "GET";
    const read = method === "GET" && url.startsWith(COLLECTION + "?");
    const generate = ["--sample", "--generate"].includes(mode) && method === "POST" && url === SYNTHESIS_ENDPOINT;
    assert.ok(read || generate, "Out-of-scope request: repairs cannot publish or alter backend data");
    const response = await fetch(url, { ...options, redirect: "error",
      headers: { ...options.headers, Authorization: `Bearer ${token}`, "x-goog-user-project": PROJECT },
      signal: AbortSignal.timeout(45000) });
    if (!response.ok) {
      const detail = await response.text();
      await save(resolve(PRIVATE, "last-api-error.json"), { status: response.status, detail });
      throw new Error(`Audio repair API: HTTP ${response.status}; detail saved privately`);
    }
    return response;
  };
}
async function list(request) {
  const docs = [];
  let page = "";
  do {
    const data = await (await request(`${COLLECTION}?pageSize=300${page ? `&pageToken=${encodeURIComponent(page)}` : ""}`)).json();
    docs.push(...(data.documents ?? []));
    page = data.nextPageToken ?? "";
  } while (page);
  return docs;
}

async function generate(plan, request, token, sampleOnly) {
  await mkdir(OUTPUT, { recursive: true });
  const existing = await optional(MANIFEST);
  if (existing) assert.equal(existing.planHash, plan.planHash);
  assert.ok(!existing?.pronunciationReviewStatus?.startsWith("rejected"), "This generation profile was rejected by the listener; use a new reviewed profile");
  const manifest = existing ?? { project: PROJECT, voice: VOICE, planHash: plan.planHash,
    pronunciationReviewStatus: "awaiting-human-listening", published: false, records: [] };
  const cache = new Map();
  for (const row of manifest.records) {
    const bytes = await readFile(resolve(OUTPUT, row.file));
    assert.equal(sha256(bytes), row.audioSha256);
    validateMp3(bytes);
    cache.set(row.speechTextSha256, bytes);
  }
  for (const row of plan.records.filter(r => !sampleOnly || r.id === SAMPLE_ID)) {
    if (manifest.records.some(r => r.id === row.id)) continue;
    let bytes = cache.get(row.speechTextSha256);
    if (!bytes) bytes = await synthesiseWithSentenceLimit(row.speechText, request, token);
    validateMp3(bytes);
    assert.notEqual(sha256(bytes), row.previousAudioSha256, "Repair unexpectedly reused old audio");
    const path = resolve(OUTPUT, row.file);
    await writeFile(path, bytes, { flag: "wx" });
    const probe = spawnSync("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "json", path], { encoding: "utf8" });
    assert.equal(probe.status, 0);
    const durationSeconds = Number(JSON.parse(probe.stdout).format.duration);
    assert.ok(durationSeconds > 0 && Number.isFinite(durationSeconds));
    cache.set(row.speechTextSha256, bytes);
    manifest.records.push({ ...row, audioSha256: sha256(bytes), bytes: bytes.length, durationSeconds });
    await save(MANIFEST, manifest);
    console.log(`${manifest.records.length}/${plan.records.length}: ${row.id} (${durationSeconds.toFixed(1)}s)`);
  }
  const sample = manifest.records.find(r => r.id === SAMPLE_ID);
  console.log(JSON.stringify({ prepared: manifest.records.length, total: plan.records.length,
    sampleFile: sample ? resolve(OUTPUT, sample.file) : null, sampleSha256: sample?.audioSha256,
    published: false, pronunciationReviewStatus: manifest.pronunciationReviewStatus }));
}

export async function main(args) {
  assert.equal(args.length, 1);
  const mode = args[0];
  assert.ok(["--prepare", "--sample", "--generate"].includes(mode));
  const token = process.env.GOOGLE_ACCESS_TOKEN;
  const request = requestFor(token, mode);
  const original = await load(resolve(ROOT, "review/algieba-audio-2026-09-10/manifest.json"));
  assert.equal(original.voice, VOICE);
  if (mode === "--prepare") {
    const documents = await list(request);
    const plan = buildRepairPlan(documents, original.records);
    const saved = await optional(SNAPSHOT);
    if (saved) assert.equal(saved.plan.planHash, plan.planHash, "Saved source snapshot changed");
    else await save(SNAPSHOT, { documents, plan });
    await save(resolve(OUTPUT, "speech-plan.json"), plan);
    const lines = ["# مراجعة تصحيح النطق — Algieba", "", "نص العرض محفوظ دون تعديل. الملفات الجديدة تنتظر مراجعة السماع قبل النشر.", ""];
    for (const row of plan.records) lines.push(`## ${row.title}`, "", `المعرّف: ${row.id}`, "", "نص العرض الأصلي:", row.canonicalText, "", "نص النطق:", row.speechText, "", `[العينة الصوتية](${row.file})`, "");
    await mkdir(OUTPUT, { recursive: true });
    await writeFile(resolve(OUTPUT, "TEXT_AND_LISTENING_REVIEW.md"), lines.join("\n"));
    console.log(JSON.stringify({ checked: plan.checkedRecords, affected: plan.records.length,
      unchanged: plan.unchangedIds.length, uniqueSpeechTexts: plan.uniqueSpeechTexts, characters: plan.characters,
      planHash: plan.planHash, published: false }));
    return;
  }
  const snapshot = await load(SNAPSHOT);
  const plan = buildRepairPlan(snapshot.documents, original.records);
  assert.equal(plan.planHash, snapshot.plan.planHash);
  assertSnapshotUnchanged(snapshot.documents, await list(request));
  await generate(plan, request, token, mode === "--sample");
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main(process.argv.slice(2)).catch(error => {
    console.error(error.code === "ERR_ASSERTION" ? "Repair safety check failed; inspect source and local plan before continuing." : error.message);
    process.exitCode = 1;
  });
}
