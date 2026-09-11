/** Owner-approved Algieba cadence. Text and review metadata stay immutable.
 * 31 records get corrected speech; 22 retain their original spoken performance.
 * All receive pitch-preserving 0.90 tempo and longer existing internal pauses.
 * Publication is create-only Storage + a preconditioned atomic audio-only commit.
 */
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile, writeFile, mkdir, rename } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { spawnSync } from "node:child_process";
import { speechFor } from "./dua-speech-vowels.mjs";
import { buildRepairPlan } from "./repair-algieba-audio.mjs";
import { PROJECT, BUCKET, VOICE, sha256, validateMp3, splitForSynthesis,
  assertSnapshotUnchanged, buildCommit, assertOnlyAudioChanged, verifyPublicFile } from "./publish-algieba-audio.mjs";
import { SYNTHESIS_ENDPOINT, downloadUrl } from "../scripts/generate_dua_audio.mjs";

const ROOT = fileURLToPath(new URL("../", import.meta.url));
export const OUTPUT = resolve(ROOT, "review/algieba-final-2026-09-10");
const PRIVATE = resolve(ROOT, ".local/dua-algieba-final-2026-09-10");
const OLD = resolve(ROOT, "review/algieba-audio-2026-09-10");
const PREVIEW = resolve(ROOT, "review/algieba-pacing-preview-2026-09-10");
const SAMPLE_HASH = "8880b411f6946ccafb60dd1c0728eadae7c4d76fc578845e2fd2b4059517ba3f";
const PREFIX = `projects/${PROJECT}/databases/(default)/documents/supplications/`;
const COLLECTION = `https://firestore.googleapis.com/v1/${PREFIX.slice(0, -1)}`;
const COMMIT = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents:commit`;
const UPLOAD = `https://storage.googleapis.com/upload/storage/v1/b/${BUCKET}/o?uploadType=multipart&ifGenerationMatch=0`;
const load = async path => JSON.parse(await readFile(path, "utf8"));
async function optional(path) {
  try { return await load(path); } catch (e) { if (e.code === "ENOENT") return null; throw e; }
}
async function save(path, data) {
  await mkdir(resolve(path, ".."), { recursive: true });
  await writeFile(path + ".tmp", JSON.stringify(data, null, 2));
  await rename(path + ".tmp", path);
}
export const PROFILE = Object.freeze({ voice: VOICE, synthesisRate: 1.15, tempo: 0.9,
  extraInternalPauseSeconds: 0.8, approvedSampleSha256: SAMPLE_HASH, version: 1 });

export function validateApprovedSample(bytes, metadata) {
  assert.equal(metadata?.humanListeningStatus, "approved-by-user", "Sample needs recorded listening approval");
  assert.equal(metadata.audioSha256, SAMPLE_HASH, "Sample metadata does not match the approved recording");
  assert.equal(sha256(bytes), SAMPLE_HASH, "Sample bytes do not match the approved recording");
}

export function makePlan(documents, originals) {
  const repair = buildRepairPlan(documents, originals);
  const records = originals.map(old => {
    const raw = documents.find(d => d.name === PREFIX + old.id);
    const speech = speechFor(old.id, old.text);
    return { id: old.id, name: raw.name, updateTime: raw.updateTime, title: old.title,
      canonicalText: old.text, canonicalTextSha256: sha256(old.text), ...speech,
      speechTextSha256: sha256(speech.speechText), previousAudioSha256: old.audioSha256,
      regenerate: !repair.unchangedIds.includes(old.id), file: old.file };
  }).sort((a, b) => a.id.localeCompare(b.id));
  const unique = [...new Map(records.filter(r => r.regenerate).map(r => [r.speechTextSha256, r])).values()];
  const characters = unique.reduce((n, r) => n + [...r.speechText].length, 0);
  assert.ok(characters < 12000, "Bounded synthesis budget exceeded");
  return { project: PROJECT, profile: PROFILE, records, characters,
    planHash: sha256(JSON.stringify([PROFILE, records])) };
}

export function allowedRequest(mode, url, method = "GET") {
  return (method === "GET" && url.startsWith(COLLECTION + "?")) ||
    (mode === "--generate" && method === "POST" && url === SYNTHESIS_ENDPOINT) ||
    (mode === "--publish" && method === "POST" && [UPLOAD, COMMIT].includes(url));
}
function client(mode) {
  const token = process.env.GOOGLE_ACCESS_TOKEN;
  assert.ok(token, "GOOGLE_ACCESS_TOKEN required");
  return async (url, options = {}) => {
    assert.ok(allowedRequest(mode, url, options.method), "Out-of-scope request blocked");
    const response = await fetch(url, { ...options, redirect: "error",
      headers: { ...options.headers, Authorization: `Bearer ${token}`, "x-goog-user-project": PROJECT },
      signal: AbortSignal.timeout(45000) });
    if (!response.ok && !(url === UPLOAD && response.status === 412)) {
      await save(resolve(PRIVATE, "last-error.json"), { status: response.status, detail: await response.text() });
      throw new Error(`Audio ${mode}: HTTP ${response.status}; diagnostic saved privately`);
    }
    return response;
  };
}
async function list(request) {
  const docs = [];
  let page = "";
  do {
    const value = await (await request(`${COLLECTION}?pageSize=300${page ? `&pageToken=${encodeURIComponent(page)}` : ""}`)).json();
    docs.push(...(value.documents ?? []));
    page = value.nextPageToken ?? "";
  } while (page);
  return docs;
}
function run(program, args, bytes) {
  const result = spawnSync(program, args, { input: bytes, maxBuffer: 30_000_000 });
  assert.equal(result.status, 0, `${program} audio processing failed`);
  return result;
}
function duration(bytes) {
  const result = run("ffprobe", ["-v", "error", "-i", "pipe:0", "-show_entries", "format=duration", "-of", "json"], bytes);
  const value = Number(JSON.parse(result.stdout).format.duration);
  // Some streamed MP3s cannot be duration-probed without a seekable file.
  if (Number.isFinite(value) && value > 0) return value;
  return run("ffmpeg", ["-v", "error", "-i", "pipe:0", "-f", "s16le", "-ar", "24000", "-ac", "1", "pipe:1"], bytes).stdout.length / 48000;
}
export function internalPauses(log, seconds) {
  const ranges = [];
  let start = null;
  for (const match of log.matchAll(/silence_(start|end):\s*([\d.]+)/gu)) {
    if (match[1] === "start") start = Number(match[2]);
    else if (start !== null) {
      const end = Number(match[2]);
      if (start > 0.4 && end < seconds - 0.4 && end - start >= 0.2) ranges.push([start, end]);
      start = null;
    }
  }
  return ranges;
}
export function slowAudio(bytes) {
  validateMp3(bytes);
  const seconds = duration(bytes);
  const detected = run("ffmpeg", ["-hide_banner", "-i", "pipe:0", "-af", "silencedetect=noise=-35dB:d=0.20", "-f", "null", "-"], bytes);
  const pauses = internalPauses(detected.stderr.toString(), seconds);
  const splits = [0, ...pauses.map(([a, b]) => (a + b) / 2)];
  const n = splits.length;
  const filters = n > 1 ? [`[0:a]asplit=${n}${splits.map((_, i) => `[in${i}]`).join("")}`] : [];
  splits.forEach((start, i) => filters.push(`${n > 1 ? `[in${i}]` : "[0:a]"}atrim=start=${start}${i < n - 1 ? `:end=${splits[i + 1]}` : ""},asetpts=PTS-STARTPTS,atempo=${PROFILE.tempo}${i < n - 1 ? `,apad=pad_dur=${PROFILE.extraInternalPauseSeconds}` : ""}[out${i}]`));
  filters.push(`${splits.map((_, i) => `[out${i}]`).join("")}concat=n=${n}:v=0:a=1[out]`);
  const rendered = run("ffmpeg", ["-v", "error", "-i", "pipe:0", "-filter_complex", filters.join(";"), "-map", "[out]", "-codec:a", "libmp3lame", "-b:a", "64k", "-f", "mp3", "pipe:1"], bytes).stdout;
  validateMp3(rendered);
  return { bytes: rendered, transformation: { tempo: PROFILE.tempo, sourceDurationSeconds: seconds,
    sourceAudioSha256: sha256(bytes), extendedSilences: pauses, extraSecondsPerPause: PROFILE.extraInternalPauseSeconds } };
}
export const synthesisBody = text => ({ input: { text }, voice: { languageCode: "ar-XA", name: VOICE },
  audioConfig: { audioEncoding: "MP3", speakingRate: PROFILE.synthesisRate } });
async function synthesize(text, request) {
  const parts = [];
  for (const chunk of splitForSynthesis(text)) {
    const body = synthesisBody(chunk);
    const path = resolve(PRIVATE, "chunks", sha256(JSON.stringify(body)) + ".mp3");
    let bytes;
    try { bytes = await readFile(path); } catch (e) {
      if (e.code !== "ENOENT") throw e;
      const result = await (await request(SYNTHESIS_ENDPOINT, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) })).json();
      assert.ok(result.audioContent, "No synthesis audio");
      bytes = Buffer.from(result.audioContent, "base64");
      validateMp3(bytes);
      await mkdir(resolve(path, ".."), { recursive: true });
      await writeFile(path, bytes, { flag: "wx" });
    }
    validateMp3(bytes);
    parts.push(bytes);
  }
  if (parts.length === 1) return parts[0];
  const pcm = parts.map(bytes => run("ffmpeg", ["-v", "error", "-i", "pipe:0", "-f", "s16le", "-ar", "24000", "-ac", "1", "pipe:1"], bytes).stdout);
  return run("ffmpeg", ["-v", "error", "-f", "s16le", "-ar", "24000", "-ac", "1", "-i", "pipe:0", "-codec:a", "libmp3lame", "-b:a", "64k", "-f", "mp3", "pipe:1"], Buffer.concat(pcm)).stdout;
}
async function generate(plan, request) {
  await mkdir(OUTPUT, { recursive: true });
  const manifest = await optional(resolve(OUTPUT, "manifest.json")) ?? { project: PROJECT, profile: PROFILE,
    planHash: plan.planHash, syntheticVoice: true, humanListeningStatus: "sample-approved; other-records-not-human-reviewed", published: false, records: [] };
  assert.equal(manifest.planHash, plan.planHash);
  const cache = new Map();
  for (const record of manifest.records) {
    const bytes = await readFile(resolve(OUTPUT, record.file));
    assert.equal(sha256(bytes), record.audioSha256);
    validateMp3(bytes);
    cache.set(record.speechTextSha256, { bytes, transformation: record.transformation });
  }
  for (const row of plan.records) {
    if (manifest.records.some(r => r.id === row.id)) continue;
    let audio = cache.get(row.speechTextSha256);
    const approved = ["moia-mukhtasar-1446-general-001", "moia-mukhtasar-1446-tawaf-between-corners"].includes(row.id);
    if (!audio && approved) {
      const bytes = await readFile(resolve(PREVIEW, "02-algieba-repeat-slower.mp3"));
      const metadata = await load(resolve(PREVIEW, "02-algieba-repeat-slower.json"));
      validateApprovedSample(bytes, metadata);
      audio = { bytes, transformation: metadata.transformation };
    }
    if (!audio) {
      let bytes;
      if (row.regenerate) bytes = await synthesize(row.speechText, request);
      else {
        bytes = await readFile(resolve(OLD, row.file));
        assert.equal(sha256(bytes), row.previousAudioSha256);
      }
      audio = slowAudio(bytes);
    }
    validateMp3(audio.bytes);
    cache.set(row.speechTextSha256, audio);
    const path = resolve(OUTPUT, row.file);
    await writeFile(path, audio.bytes, { flag: "wx" });
    const seconds = Number(JSON.parse(run("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "json", path]).stdout).format.duration);
    assert.ok(seconds > 0 && Number.isFinite(seconds));
    manifest.records.push({ ...row, audioSha256: sha256(audio.bytes), bytes: audio.bytes.length,
      durationSeconds: seconds, transformation: audio.transformation,
      humanListeningStatus: approved ? "approved-by-user" : "not-human-reviewed" });
    await save(resolve(OUTPUT, "manifest.json"), manifest);
    console.log(`${manifest.records.length}/53: ${row.id} (${seconds.toFixed(1)}s)`);
  }
}
async function validate(plan) {
  const manifest = await load(resolve(OUTPUT, "manifest.json"));
  assert.equal(manifest.planHash, plan.planHash);
  assert.equal(manifest.records.length, 53);
  assert.equal(new Set(manifest.records.map(r => r.id)).size, 53);
  for (const row of plan.records) {
    const record = manifest.records.find(r => r.id === row.id);
    for (const [key, value] of Object.entries(row)) assert.deepEqual(record[key], value, `Manifest source mismatch: ${key}`);
    const bytes = await readFile(resolve(OUTPUT, record.file));
    assert.equal(sha256(bytes), record.audioSha256);
    validateMp3(bytes);
  }
  return manifest;
}
async function upload(manifest, request) {
  const journal = await optional(resolve(PRIVATE, "uploads.json")) ?? { planHash: manifest.planHash, objects: {} };
  assert.equal(journal.planHash, manifest.planHash);
  const unique = [...new Map(manifest.records.map(r => [r.audioSha256, r])).values()];
  for (const row of unique) {
    let entry = journal.objects[row.audioSha256];
    if (!entry) {
      entry = { path: `audio/duas/algieba-${row.audioSha256}.mp3`, token: randomUUID(), uploaded: false };
      journal.objects[row.audioSha256] = entry;
      await save(resolve(PRIVATE, "uploads.json"), journal);
    }
    if (!entry.uploaded) {
      const boundary = `dhakker_${randomUUID()}`;
      const metadata = { name: entry.path, contentType: "audio/mpeg", contentLanguage: "ar", cacheControl: "public,max-age=31536000,immutable",
        metadata: { firebaseStorageDownloadTokens: entry.token, voice: VOICE, sourceTextSha256: row.canonicalTextSha256, audioSha256: row.audioSha256 } };
      const bytes = await readFile(resolve(OUTPUT, row.file));
      const body = Buffer.concat([Buffer.from(`--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${JSON.stringify(metadata)}\r\n--${boundary}\r\nContent-Type: audio/mpeg\r\n\r\n`), bytes, Buffer.from(`\r\n--${boundary}--\r\n`)]);
      const response = await request(UPLOAD, { method: "POST", headers: { "Content-Type": `multipart/related; boundary=${boundary}` }, body });
      if (response.status !== 412) {
        const result = await response.json();
        assert.equal(result.name, entry.path);
        assert.equal(Number(result.size), bytes.length);
      }
    }
    await verifyPublicFile(downloadUrl(BUCKET, entry.path, entry.token), row.audioSha256);
    entry.uploaded = true;
    await save(resolve(PRIVATE, "uploads.json"), journal);
    console.log(`Uploaded and verified ${Object.values(journal.objects).filter(x => x.uploaded).length}/${unique.length}`);
  }
  return journal;
}
function urlsFor(manifest, journal) {
  return new Map(manifest.records.map(row => {
    const entry = journal.objects[row.audioSha256];
    assert.ok(entry?.uploaded);
    return [row.id, downloadUrl(BUCKET, entry.path, entry.token)];
  }));
}
async function verify(snapshot, manifest, journal, request) {
  const documents = await list(request);
  assert.equal(documents.length, 53);
  const urls = urlsFor(manifest, journal);
  for (const before of snapshot.documents) {
    const after = documents.find(d => d.name === before.name);
    assert.ok(after);
    assertOnlyAudioChanged(before, after, urls.get(before.name.slice(PREFIX.length)));
  }
  for (const row of new Map(manifest.records.map(r => [r.audioSha256, r])).values()) await verifyPublicFile(urls.get(row.id), row.audioSha256);
  const result = { project: PROJECT, linkedRecords: 53, uniqueAudioFiles: new Set(manifest.records.map(r => r.audioSha256)).size,
    regeneratedRecords: 31, originalPerformancesSlowed: 22, approvedSampleReusedExactly: true,
    allDownloadsVerified: true, nonAudioFieldsUnchanged: true, verifiedAt: new Date().toISOString(),
    humanListeningStatus: manifest.humanListeningStatus, published: true };
  await save(resolve(OUTPUT, "publication.json"), result);
  manifest.published = true;
  await save(resolve(OUTPUT, "manifest.json"), manifest);
  console.log(JSON.stringify(result));
}
export async function main(args) {
  const mode = args[0];
  assert.ok(["--prepare", "--generate", "--publish", "--verify", "--validate"].includes(mode));
  assert.deepEqual(args.slice(1), mode === "--publish" ? [`--confirm-project=${PROJECT}`, "--confirm-count=53"] : []);
  const originals = (await load(resolve(OLD, "manifest.json"))).records;
  const request = mode === "--validate" ? null : client(mode);
  if (mode === "--prepare") {
    const documents = await list(request);
    const plan = makePlan(documents, originals);
    const saved = await optional(resolve(PRIVATE, "snapshot.json"));
    if (saved) assert.equal(saved.plan.planHash, plan.planHash);
    else await save(resolve(PRIVATE, "snapshot.json"), { documents, plan });
    await save(resolve(OUTPUT, "speech-plan.json"), plan);
    console.log(JSON.stringify({ records: 53, regenerate: 31, retainPerformance: 22, characters: plan.characters, planHash: plan.planHash }));
    return;
  }
  const snapshot = await load(resolve(PRIVATE, "snapshot.json"));
  const plan = makePlan(snapshot.documents, originals);
  assert.equal(plan.planHash, snapshot.plan.planHash);
  if (mode === "--generate") {
    assertSnapshotUnchanged(snapshot.documents, await list(request));
    return generate(plan, request);
  }
  const manifest = await validate(plan);
  if (mode === "--validate") { console.log("53 files passed source, hash, and complete MP3 decode validation"); return; }
  if (mode === "--verify") return verify(snapshot, manifest, await load(resolve(PRIVATE, "uploads.json")), request);
  // Recover a completed/uncertain commit without reapplying writes.
  const previousJournal = await optional(resolve(PRIVATE, "uploads.json"));
  const live = await list(request);
  const completeJournal = previousJournal && manifest.records.every(r => previousJournal.objects[r.audioSha256]?.uploaded);
  if (completeJournal && live.length === 53 && live.every(d => d.fields.audioUrl?.stringValue === urlsFor(manifest, previousJournal).get(d.name.slice(PREFIX.length)))) {
    return verify(snapshot, manifest, previousJournal, request);
  }
  assertSnapshotUnchanged(snapshot.documents, live);
  const journal = await upload(manifest, request);
  assertSnapshotUnchanged(snapshot.documents, await list(request));
  const result = await (await request(COMMIT, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(buildCommit(plan.records, urlsFor(manifest, journal))) })).json();
  assert.equal(result.writeResults?.length, 53);
  await save(resolve(PRIVATE, "commit.json"), result);
  return verify(snapshot, manifest, journal, request);
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main(process.argv.slice(2)).catch(error => {
    console.error(error.code === "ERR_ASSERTION" ? `Audio safety check failed: ${error.message.split("\n")[0]}` : error.message);
    process.exitCode = 1;
  });
}
