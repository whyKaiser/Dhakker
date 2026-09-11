/** Publish the user-selected voice without changing devotional text or review metadata.
 * --plan saves an immutable local snapshot; --generate creates MP3s only;
 * --publish uploads new immutable objects, verifies bytes, then atomically links all records.
 * Backups and download tokens stay in ignored .local/, never logs or the distributable bundle.
 */
import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import { mkdir, readFile, writeFile, rename } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { fromFirestoreValue } from "../scripts/import_source_pack.mjs";
import { ineligibilityReason, synthesise, downloadUrl, SYNTHESIS_ENDPOINT, VOICES_ENDPOINT } from "../scripts/generate_dua_audio.mjs";

export const PROJECT = "dhakker-160d0";
export const BUCKET = "dhakker-160d0.firebasestorage.app";
export const VOICE = "ar-XA-Chirp3-HD-Algieba";
export const EXPECTED_COUNT = 53;
const DOCUMENT_ROOT = `projects/${PROJECT}/databases/(default)/documents/supplications/`;
const FIRESTORE = "https://firestore.googleapis.com/v1/";
const COLLECTION = FIRESTORE + DOCUMENT_ROOT.slice(0, -1);
const COMMIT = `${FIRESTORE}projects/${PROJECT}/databases/(default)/documents:commit`;
const ROOT = fileURLToPath(new URL("../", import.meta.url));
const PRIVATE = resolve(ROOT, ".local/dua-audio-algieba-2026-09-10");
export const OUTPUT = resolve(ROOT, "review/algieba-audio-2026-09-10");
const SNAPSHOT = resolve(PRIVATE, "snapshot.json");
const JOURNAL = resolve(PRIVATE, "uploads.json");
const MANIFEST = resolve(OUTPUT, "manifest.json");
export const sha256 = bytes => createHash("sha256").update(bytes).digest("hex");
const plain = raw => Object.fromEntries(Object.entries(raw.fields ?? {}).map(([k, v]) => [k, fromFirestoreValue(v)]));
const log = value => console.log(typeof value === "string" ? value : JSON.stringify(value));

export function buildPlan(documents) {
  assert.equal(documents.length, EXPECTED_COUNT, "Live document count changed; review before continuing");
  const records = documents.map(raw => {
    assert.ok(raw.name?.startsWith(DOCUMENT_ROOT), "Unexpected collection");
    const id = raw.name.slice(DOCUMENT_ROOT.length);
    assert.match(id, /^[a-zA-Z0-9_-]+$/);
    assert.ok(raw.updateTime, "Missing write precondition");
    const doc = plain(raw);
    const reason = ineligibilityReason({ ...doc, documentId: id });
    assert.equal(reason, null, `${id}: ${reason}`);
    assert.equal(doc.isActive, true, `${id}: inactive`);
    assert.notEqual(doc.deploymentBlocked, true);
    assert.notEqual(doc.excludedFromImport, true);
    assert.notEqual(doc.reviewStatus, "blocked");
    const text = doc.text.ar; // Preserve every character, including Quranic orthography.
    assert.ok(Buffer.byteLength(text, "utf8") <= 5000, `${id}: exceeds TTS byte limit`);
    return { id, name: raw.name, updateTime: raw.updateTime, title: doc.title?.ar ?? id,
      text, textSha256: sha256(text), file: `${id}.mp3` };
  }).sort((a, b) => a.id.localeCompare(b.id));
  assert.equal(new Set(records.map(r => r.id)).size, records.length);
  const unique = [...new Map(records.map(r => [r.textSha256, r])).values()];
  const characters = unique.reduce((sum, r) => sum + [...r.text].length, 0);
  assert.ok(characters <= 30000, "Exceeded the bounded generation budget");
  return { project: PROJECT, bucket: BUCKET, voice: VOICE, records, uniqueTexts: unique.length,
    characters, estimatedUsdBeforeFreeTier: characters * 0.00003,
    planHash: sha256(JSON.stringify(records.map(r => [r.id, r.updateTime, r.textSha256]))) };
}

export function assertSnapshotUnchanged(before, after) {
  const versions = documents => documents.map(d => [d.name, d.updateTime]).sort(([a], [b]) => a.localeCompare(b));
  assert.deepEqual(versions(after), versions(before), "Firestore changed since the saved plan; refusing to overwrite");
}

export function buildCommit(records, urls) {
  assert.equal(records.length, EXPECTED_COUNT);
  return { writes: records.map(row => {
    const url = urls.get(row.id);
    assert.ok(url?.startsWith(`https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/`), "Unexpected audio host/bucket");
    return {
      update: { name: row.name, fields: { audioMode: { stringValue: "file" }, audioUrl: { stringValue: url } } },
      updateMask: { fieldPaths: ["audioMode", "audioUrl"] },
      updateTransforms: [{ fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" }],
      currentDocument: { updateTime: row.updateTime },
    };
  }) };
}

export function assertOnlyAudioChanged(before, after, expectedUrl) {
  assert.equal(after.name, before.name);
  const fields = value => Object.fromEntries(Object.entries(value.fields ?? {}).filter(([k]) => !["audioMode", "audioUrl", "updatedAt"].includes(k)));
  assert.deepEqual(fields(after), fields(before), `Non-audio fields changed: ${before.name.split("/").at(-1)}`);
  assert.equal(after.fields.audioMode?.stringValue, "file");
  assert.equal(after.fields.audioUrl?.stringValue, expectedUrl);
}

async function readJson(path) { return JSON.parse(await readFile(path, "utf8")); }
async function saveJson(path, data) {
  await mkdir(resolve(path, ".."), { recursive: true });
  const temp = `${path}.tmp`;
  await writeFile(temp, JSON.stringify(data, null, 2));
  await rename(temp, path);
}
async function optionalJson(path) {
  try { return await readJson(path); } catch (error) { if (error.code === "ENOENT") return null; throw error; }
}

function client(token, phase) {
  if (!token) throw new Error("Short-lived GOOGLE_ACCESS_TOKEN required");
  return async (url, options = {}) => {
    const method = options.method ?? "GET";
    const read = method === "GET" && (url.startsWith(COLLECTION + "?") || url === `${VOICES_ENDPOINT}?languageCode=ar-XA`);
    const generate = phase === "--generate" && method === "POST" && url === SYNTHESIS_ENDPOINT;
    const upload = phase === "--publish" && method === "POST" && url === `https://storage.googleapis.com/upload/storage/v1/b/${BUCKET}/o?uploadType=multipart&ifGenerationMatch=0`;
    const commit = phase === "--publish" && method === "POST" && url === COMMIT;
    assert.ok(read || generate || upload || commit, "Out-of-scope request blocked");
    const response = await fetch(url, { ...options, redirect: "error",
      headers: { ...options.headers, Authorization: `Bearer ${token}`, "x-goog-user-project": PROJECT },
      signal: AbortSignal.timeout(45000) });
    if (!response.ok && !(upload && response.status === 412)) {
      let status = "";
      try {
        const error = (await response.json()).error;
        status = error?.status ?? "";
        await saveJson(resolve(PRIVATE, "last-api-error.json"), { phase, httpStatus: response.status, error });
      } catch { /* no body logging */ }
      throw new Error(`Google ${upload ? "upload" : commit ? "commit" : generate ? "synthesis" : "read"}: HTTP ${response.status} ${status}`);
    }
    return response;
  };
}

async function listDocuments(request) {
  const documents = [];
  let pageToken = "";
  do {
    const result = await (await request(`${COLLECTION}?pageSize=300${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ""}`)).json();
    documents.push(...(result.documents ?? []));
    pageToken = result.nextPageToken ?? "";
  } while (pageToken);
  return documents;
}

export function validateMp3(bytes) {
  assert.ok(bytes.length > 300 && bytes.length < 5_000_000, "Invalid audio size");
  assert.ok(bytes.subarray(0, 3).toString() === "ID3" || (bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0), "Invalid MP3 header");
  const decoded = spawnSync("ffmpeg", ["-v", "error", "-i", "pipe:0", "-f", "null", "-"], { input: bytes, maxBuffer: 1024 * 1024 });
  assert.equal(decoded.status, 0, "Audio failed the complete MP3 decode check");
}

/** Split only at existing punctuation/whitespace; never normalize or change the source. */
export function splitForSynthesis(text, limit = 300) {
  assert.ok(Number.isInteger(limit) && limit > 0);
  const parts = [];
  let rest = text;
  while (rest.length > limit) {
    const window = rest.slice(0, limit);
    const punctuation = [...window.matchAll(/[،,.;؛!?؟]\s*/gu)];
    const whitespace = [...window.matchAll(/\s+/gu)];
    const boundary = punctuation.at(-1) ?? whitespace.at(-1);
    assert.ok(boundary, "Cannot split a long token without changing source text");
    const end = boundary.index + boundary[0].length;
    parts.push(rest.slice(0, end));
    rest = rest.slice(end);
  }
  if (rest) parts.push(rest);
  assert.equal(parts.join(""), text);
  return parts;
}

export async function synthesiseWithSentenceLimit(text, request, token) {
  const parts = splitForSynthesis(text);
  if (parts.length === 1) return synthesise(text, VOICE, { token }, { fetch: request });
  const pcmParts = [];
  const chunkDir = resolve(PRIVATE, "chunks");
  await mkdir(chunkDir, { recursive: true });
  for (const part of parts) {
    const chunkPath = resolve(chunkDir, `${sha256(VOICE + "\0" + part)}.mp3`);
    let bytes;
    try { bytes = await readFile(chunkPath); } catch (error) {
      if (error.code !== "ENOENT") throw error;
      bytes = await synthesise(part, VOICE, { token }, { fetch: request });
      validateMp3(bytes);
      await writeFile(chunkPath, bytes, { flag: "wx" });
    }
    validateMp3(bytes);
    const decoded = spawnSync("ffmpeg", ["-v", "error", "-i", "pipe:0", "-f", "s16le", "-ar", "24000", "-ac", "1", "pipe:1"], { input: bytes, maxBuffer: 20_000_000 });
    assert.equal(decoded.status, 0, "Failed to decode an audio segment");
    pcmParts.push(decoded.stdout);
  }
  const joined = spawnSync("ffmpeg", ["-v", "error", "-f", "s16le", "-ar", "24000", "-ac", "1", "-i", "pipe:0", "-codec:a", "libmp3lame", "-b:a", "64k", "-f", "mp3", "pipe:1"], {
    input: Buffer.concat(pcmParts), maxBuffer: 10_000_000,
  });
  assert.equal(joined.status, 0, "Failed to join the spoken segments");
  return joined.stdout;
}

async function generateFiles(plan, request, token) {
  const voices = await (await request(`${VOICES_ENDPOINT}?languageCode=ar-XA`)).json();
  assert.ok(voices.voices?.some(v => v.name === VOICE && v.languageCodes?.includes("ar-XA")), "Selected Algieba voice unavailable");
  await mkdir(OUTPUT, { recursive: true });
  const existing = await optionalJson(MANIFEST);
  if (existing) assert.equal(existing.planHash, plan.planHash, "Local files belong to a different source snapshot");
  const sampleManifest = await readJson(resolve(ROOT, "review/audio-voice-alternatives-2026-09-10/manifest.json"));
  const reference = sampleManifest.samples.find(s => s.voice === VOICE);
  const cache = new Map();
  const manifest = { project: PROJECT, voice: VOICE, planHash: plan.planHash,
    syntheticVoice: true, pronunciationReviewStatus: "pending", published: false, records: [] };
  let generated = 0;
  for (const row of plan.records) {
    let bytes;
    try {
      bytes = await readFile(resolve(OUTPUT, row.file));
      const saved = existing?.records.find(r => r.id === row.id);
      assert.ok(saved, "Existing file has no provenance entry; manual inspection required");
      assert.equal(sha256(bytes), saved.audioSha256);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
      bytes = cache.get(row.textSha256);
      if (!bytes && reference?.textSha256 === row.textSha256) {
        bytes = await readFile(resolve(ROOT, "review/audio-voice-alternatives-2026-09-10", reference.file));
        assert.equal(sha256(bytes), reference.audioSha256);
      }
      if (!bytes) { bytes = await synthesiseWithSentenceLimit(row.text, request, token); generated++; }
      validateMp3(bytes);
      await writeFile(resolve(OUTPUT, row.file), bytes, { flag: "wx" });
    }
    validateMp3(bytes);
    cache.set(row.textSha256, bytes);
    const probe = spawnSync("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "json", resolve(OUTPUT, row.file)], { encoding: "utf8" });
    assert.equal(probe.status, 0, "Audio metadata check failed");
    const durationSeconds = Number(JSON.parse(probe.stdout).format.duration);
    assert.ok(Number.isFinite(durationSeconds) && durationSeconds > 0);
    manifest.records.push({ ...row, audioSha256: sha256(bytes), bytes: bytes.length, durationSeconds });
    await saveJson(MANIFEST, manifest);
    log(`${manifest.records.length}/${plan.records.length}: ${row.id} (${durationSeconds.toFixed(1)}s)`);
  }
  manifest.newlyGeneratedFilesInThisPass = generated;
  manifest.uniqueAudioFiles = new Set(manifest.records.map(r => r.audioSha256)).size;
  manifest.preparedAt = new Date().toISOString();
  await saveJson(MANIFEST, manifest);
  const lines = ["# أدعية ذكر بصوت Algieba", "", "صوت مولّد من Google. مراجعة النطق بالسماع لم تكتمل بعد.", ""];
  for (const row of manifest.records) lines.push(`## ${row.title}`, "", `[تشغيل الملف](${row.file}) — ${row.durationSeconds.toFixed(1)} ثانية`, "", row.text, "");
  await writeFile(resolve(OUTPUT, "LISTENING_REVIEW.md"), lines.join("\n"));
  return manifest;
}

async function validateBundle(plan) {
  const manifest = await readJson(MANIFEST);
  assert.equal(manifest.planHash, plan.planHash);
  assert.equal(manifest.voice, VOICE);
  assert.equal(manifest.records.length, plan.records.length);
  for (const row of plan.records) {
    const saved = manifest.records.find(r => r.id === row.id);
    assert.equal(saved?.textSha256, row.textSha256);
    const bytes = await readFile(resolve(OUTPUT, row.file));
    assert.equal(sha256(bytes), saved.audioSha256);
    validateMp3(bytes);
  }
  return manifest;
}

export async function verifyPublicFile(url, expectedSha) {
  assert.ok(url.startsWith(`https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/`));
  const origin = `https://${PROJECT}.web.app`;
  const response = await fetch(url, { headers: { Origin: origin }, redirect: "error", signal: AbortSignal.timeout(30000) });
  assert.equal(response.status, 200, "App download URL is inaccessible");
  assert.ok(response.headers.get("content-type")?.startsWith("audio/"), "Audio download has the wrong MIME type");
  assert.ok(["*", origin].includes(response.headers.get("access-control-allow-origin")), "Browser audio is blocked by CORS");
  const bytes = Buffer.from(await response.arrayBuffer());
  assert.equal(sha256(bytes), expectedSha, "Uploaded bytes differ from the tested local MP3");
}

async function uploadFiles(manifest, request) {
  let journal = await optionalJson(JOURNAL);
  if (journal) assert.equal(journal.planHash, manifest.planHash);
  else journal = { planHash: manifest.planHash, objects: {} };
  const unique = [...new Map(manifest.records.map(r => [r.audioSha256, r])).values()];
  for (const row of unique) {
    let entry = journal.objects[row.audioSha256];
    if (!entry) {
      entry = { path: `audio/duas/algieba-${row.audioSha256}.mp3`, token: randomUUID(), uploaded: false };
      journal.objects[row.audioSha256] = entry;
      await saveJson(JOURNAL, journal); // Journal the token BEFORE the upload for safe uncertain-response recovery.
    }
    if (!entry.uploaded) {
      const boundary = `dhakker_${randomUUID()}`;
      const metadata = { name: entry.path, contentType: "audio/mpeg", contentLanguage: "ar",
        cacheControl: "public,max-age=31536000,immutable", metadata: {
          firebaseStorageDownloadTokens: entry.token, voice: VOICE, sourceTextSha256: row.textSha256, audioSha256: row.audioSha256,
        } };
      const bytes = await readFile(resolve(OUTPUT, row.file));
      const body = Buffer.concat([
        Buffer.from(`--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${JSON.stringify(metadata)}\r\n--${boundary}\r\nContent-Type: audio/mpeg\r\n\r\n`),
        bytes, Buffer.from(`\r\n--${boundary}--\r\n`),
      ]);
      const response = await request(`https://storage.googleapis.com/upload/storage/v1/b/${BUCKET}/o?uploadType=multipart&ifGenerationMatch=0`, {
        method: "POST", headers: { "Content-Type": `multipart/related; boundary=${boundary}` }, body,
      });
      if (response.status !== 412) {
        const result = await response.json();
        assert.equal(result.name, entry.path);
        assert.equal(Number(result.size), bytes.length);
      }
    }
    await verifyPublicFile(downloadUrl(BUCKET, entry.path, entry.token), row.audioSha256);
    entry.uploaded = true;
    await saveJson(JOURNAL, journal);
    log(`Uploaded and download-verified: ${Object.values(journal.objects).filter(o => o.uploaded).length}/${unique.length}`);
  }
  return journal;
}

function urlsFor(manifest, journal) {
  return new Map(manifest.records.map(row => {
    const entry = journal.objects[row.audioSha256];
    assert.ok(entry?.uploaded, "Missing verified upload");
    return [row.id, downloadUrl(BUCKET, entry.path, entry.token)];
  }));
}

async function verifyPublication(snapshot, plan, manifest, journal, request) {
  const live = await listDocuments(request);
  assert.equal(live.length, snapshot.documents.length);
  const urls = urlsFor(manifest, journal);
  for (const original of snapshot.documents) {
    const current = live.find(d => d.name === original.name);
    assert.ok(current, "A source document disappeared");
    assertOnlyAudioChanged(original, current, urls.get(original.name.slice(DOCUMENT_ROOT.length)));
  }
  for (const [hash, entry] of Object.entries(journal.objects)) {
    await verifyPublicFile(downloadUrl(BUCKET, entry.path, entry.token), hash);
  }
  const result = { project: PROJECT, voice: VOICE, linkedRecords: live.length,
    uniqueAudioFiles: Object.keys(journal.objects).length, planHash: plan.planHash,
    allDownloadsVerified: true, nonAudioFieldsUnchanged: true, verifiedAt: new Date().toISOString(),
    pronunciationReviewStatus: "pending", published: true };
  await saveJson(resolve(OUTPUT, "publication.json"), result);
  manifest.published = true;
  await saveJson(MANIFEST, manifest);
  log(result);
  return result;
}

export async function main(args) {
  const phases = args.filter(a => ["--plan", "--generate", "--publish", "--verify"].includes(a));
  assert.equal(phases.length, 1, "Choose --plan, --generate, --publish or --verify");
  assert.ok(args.every(a => phases.includes(a) || a === `--confirm-project=${PROJECT}` || a === `--confirm-count=${EXPECTED_COUNT}`), "Unknown argument");
  const phase = phases[0];
  if (phase === "--publish") {
    assert.ok(args.includes(`--confirm-project=${PROJECT}`) && args.includes(`--confirm-count=${EXPECTED_COUNT}`), "Publication needs exact project/count confirmations");
  }
  const selection = await readJson(resolve(ROOT, "review/audio-voice-selection.json"));
  assert.equal(selection.voice, VOICE, "Voice no longer matches the user's selection");
  const token = process.env.GOOGLE_ACCESS_TOKEN;
  const request = client(token, phase);
  if (phase === "--plan") {
    const documents = await listDocuments(request);
    const plan = buildPlan(documents);
    const previous = await optionalJson(SNAPSHOT);
    if (previous) assert.equal(previous.plan.planHash, plan.planHash, "Saved plan already exists for different source data");
    else { await mkdir(PRIVATE, { recursive: true }); await writeFile(SNAPSHOT, JSON.stringify({ documents, plan }, null, 2), { flag: "wx" }); }
    log({ records: plan.records.length, uniqueTexts: plan.uniqueTexts, characters: plan.characters,
      estimatedUsdBeforeFreeTier: plan.estimatedUsdBeforeFreeTier, planHash: plan.planHash });
    return;
  }
  const snapshot = await readJson(SNAPSHOT);
  const plan = buildPlan(snapshot.documents);
  assert.equal(plan.planHash, snapshot.plan.planHash);
  if (phase === "--generate") {
    assertSnapshotUnchanged(snapshot.documents, await listDocuments(request));
    await generateFiles(plan, request, token);
    return;
  }
  const manifest = await validateBundle(plan);
  if (phase === "--verify") return verifyPublication(snapshot, plan, manifest, await readJson(JOURNAL), request);
  assertSnapshotUnchanged(snapshot.documents, await listDocuments(request));
  const journal = await uploadFiles(manifest, request);
  assertSnapshotUnchanged(snapshot.documents, await listDocuments(request));
  // Each write also carries its source updateTime: a concurrent edit aborts the whole commit.
  const response = await request(COMMIT, { method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify(buildCommit(plan.records, urlsFor(manifest, journal))) });
  const result = await response.json();
  assert.equal(result.writeResults?.length, EXPECTED_COUNT);
  await saveJson(resolve(PRIVATE, "commit.json"), result);
  return verifyPublication(snapshot, plan, manifest, journal, request);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main(process.argv.slice(2)).catch(error => {
    // Assertions may contain source documents/URLs; never print their actual/expected payloads.
    console.error(error.code === "ERR_ASSERTION" ? "Safety verification failed; inspect the local plan and state before retrying." : error.message);
    process.exitCode = 1;
  });
}
