#!/usr/bin/env node
/**
 * Generates neural audio for APPROVED supplications and attaches it to them.
 *
 * ── Why this exists ──────────────────────────────────────────────────────
 *
 * `dua_playback_service.dart` prefers a stored file and falls back to
 * device TTS:
 *
 *     final hasFile = dua.audioMode == 'file' && dua.audioUrl.trim().isNotEmpty;
 *
 * The stored file is the design; TTS is the safety net. Every record the
 * importer wrote came in with `audioMode: "tts"` and an empty `audioUrl`, so
 * every one of them falls through to the net — which is the robotic reading
 * that was reported.
 *
 * Pre-generating is a ONE-TIME cost, which is what makes it affordable where
 * live synthesis was not: the file is stored once and served forever.
 *
 * ── What it will not do ──────────────────────────────────────────────────
 *
 * It will not generate audio for a record a human has not approved. A voice
 * reading an unreviewed text is worse than no voice: it lends the text an
 * authority the review has not granted, and a pilgrim hears it rather than
 * reads it. `verificationStatus == "verified"` is checked against the LIVE
 * document, never against a flag on the command line.
 *
 * It will not generate for a record that is not recitable. Procedural
 * guidance and contextual evidence are not texts a pilgrim says; giving them
 * audio would put a play button on an instruction.
 *
 * It will not overwrite audio that already exists. A re-run costs nothing and
 * changes nothing, so a half-finished run is resumed by running it again.
 *
 * It will not touch the text, the verification, or any other field. The
 * updateMask names exactly three fields and the tests assert the whole list.
 *
 * ── Usage ────────────────────────────────────────────────────────────────
 *
 * DRY RUN IS THE DEFAULT. Without `--write` nothing is contacted except the
 * read that builds the plan:
 *
 *   export FIREBASE_PROJECT_ID=dhakker-160d0
 *   export FIREBASE_STORAGE_BUCKET=dhakker-160d0.firebasestorage.app
 *   export GOOGLE_ACCESS_TOKEN="$(gcloud auth print-access-token)"
 *
 *   node scripts/generate_dua_audio.mjs --production
 *
 * A real run needs `--write` plus confirmations that must match the plan the
 * dry run printed:
 *
 *   node scripts/generate_dua_audio.mjs --production --write \
 *     --confirm-project=dhakker-160d0 --confirm-count=<n>
 *
 * `--limit` is accepted only against staging, exactly as in the importer.
 */

import { createHash, randomUUID } from "node:crypto";

import {
  RECITABLE_CONTENT_KINDS,
  fromFirestoreValue,
  listCollection,
} from "./import_source_pack.mjs";

export const SYNTHESIS_ENDPOINT =
  "https://texttospeech.googleapis.com/v1/text:synthesize";
export const VOICES_ENDPOINT = "https://texttospeech.googleapis.com/v1/voices";

/**
 * Google's Arabic voices are published under `ar-XA` — a pan-Arab code, not a
 * country one. There is no `ar-SA` on this API, so asking for one returns
 * nothing at all. (The device TTS in `tts_voice.dart` is a different engine
 * with a different catalogue; the two are not interchangeable.)
 */
export const TTS_LANGUAGE_CODE = "ar-XA";

/**
 * Preferred voice families, best first. Chirp3-HD are the current neural
 * ones; Wavenet and Standard are the older tiers, kept as fallbacks so a
 * catalogue change degrades rather than fails.
 *
 * No voice name is hard-coded. Names move, and a name recalled rather than
 * read would fail at synthesis time with a 400 that says nothing useful — so
 * the catalogue is fetched and matched against these substrings.
 */
export const VOICE_PREFERENCE = Object.freeze(["Chirp3-HD", "Wavenet", "Standard"]);

export const AUDIO_ENCODING = "MP3";
export const AUDIO_CONTENT_TYPE = "audio/mpeg";

/** The three fields this script owns. Nothing else is ever written. */
export const AUDIO_WRITE_FIELDS = Object.freeze([
  "audioMode",
  "audioUrl",
  "updatedAt",
]);

/**
 * A cap on what one record may cost, in characters.
 *
 * The free tier is generous and the whole job is a fraction of it, but a
 * single malformed record carrying a whole book of text would spend it in one
 * request. Refusing is better than discovering the bill.
 */
export const MAX_CHARACTERS_PER_RECORD = 3000;

export const KNOWN_ARGUMENTS = Object.freeze([
  "--production",
  "--staging",
  "--write",
  "--limit <n>",
  "--voice=<name>",
  "--confirm-project=<id>",
  "--confirm-count=<n>",
]);

export function assertOnlyKnownArguments(args) {
  const known = new Set(["--production", "--staging", "--write", "--limit"]);
  const prefixes = ["--limit=", "--voice=", "--confirm-project=", "--confirm-count="];
  const unknown = [];
  for (let i = 0; i < args.length; i += 1) {
    const a = args[i];
    if (known.has(a)) {
      // `--limit 3` consumes its value; `--limit=3` does not.
      if (a === "--limit") i += 1;
      continue;
    }
    if (prefixes.some((p) => a.startsWith(p))) continue;
    unknown.push(a);
  }
  if (unknown.length === 0) return;
  throw new Error(
    `Unrecognised argument(s): ${unknown.join(", ")}\n` +
      `Accepted: ${KNOWN_ARGUMENTS.join(", ")}\n` +
      "There is no flag that skips the approval check.",
  );
}

export function parseArguments(args) {
  assertOnlyKnownArguments(args);

  const production = args.includes("--production");
  const staging = args.includes("--staging");
  if (production === staging) {
    throw new Error("Name exactly one of --production or --staging.");
  }
  const collection = production ? "supplications" : "supplications_staging";

  const write = args.includes("--write");

  let limit = null;
  const inline = args.find((a) => a.startsWith("--limit="));
  const spaced = args.indexOf("--limit");
  const rawLimit = inline
    ? inline.slice("--limit=".length)
    : spaced >= 0
      ? args[spaced + 1]
      : null;
  if (rawLimit !== null && rawLimit !== undefined) {
    limit = Number(rawLimit);
    if (!Number.isInteger(limit) || limit < 1) {
      throw new Error("--limit must be a positive integer.");
    }
    // A partial production run leaves the collection in a state no dry run
    // described: some records with audio, some without, and nothing that
    // says which. Try a limit against staging.
    if (production) throw new Error("--limit is not allowed against production.");
  }

  const voiceArg = args.find((a) => a.startsWith("--voice="));
  const voice = voiceArg ? voiceArg.slice("--voice=".length).trim() : null;
  if (voiceArg && !voice) throw new Error("--voice must name a voice.");

  const projectArg = args.find((a) => a.startsWith("--confirm-project="));
  const countArg = args.find((a) => a.startsWith("--confirm-count="));
  const confirmProject = projectArg
    ? projectArg.slice("--confirm-project=".length).trim()
    : null;
  const confirmCount = countArg
    ? Number(countArg.slice("--confirm-count=".length).trim())
    : null;

  if (write && (!confirmProject || confirmCount === null)) {
    throw new Error(
      "--write requires --confirm-project=<id> and --confirm-count=<n>, " +
        "both matching the plan a dry run printed.",
    );
  }
  if (!write && (confirmProject || countArg)) {
    // Confirmations without --write mean the operator believes this run is
    // writing. Letting it pass as a dry run would tell them the job is done.
    throw new Error("Confirmations were passed without --write.");
  }

  return { collection, production, write, limit, voice, confirmProject, confirmCount };
}

/**
 * Why a record may not be given audio, or null when it may.
 *
 * Order matters only for the message; every check is independent and any one
 * of them is disqualifying. The approval check reads the LIVE document —
 * there is no argument, flag or pack field that can stand in for it.
 */
export function ineligibilityReason(doc) {
  if (!doc || typeof doc !== "object") return "not a document";
  const id = String(doc.documentId ?? doc.duaId ?? "").trim();
  if (!id) return "no document id";
  if (doc.verificationStatus !== "verified") {
    return `not verified (${doc.verificationStatus ?? "unset"})`;
  }
  // An approval that was later withdrawn is not an approval. `revokedAt`
  // survives a re-import precisely so it can mean this here.
  if (doc.revokedAt !== null && doc.revokedAt !== undefined && doc.revokedAt !== "") {
    return "revoked";
  }
  if (doc.isActive === false) return "inactive";
  if (!RECITABLE_CONTENT_KINDS.includes(doc.contentKind)) {
    return `not recitable (${doc.contentKind ?? "unset"})`;
  }
  // Already carrying a file — whatever `audioMode` says. A record with a URL
  // and the wrong mode is an admin's problem to fix in the console; silently
  // overwriting their upload is not this script's business.
  if (String(doc.audioUrl ?? "").trim() !== "") return "already has audio";
  const text = String(doc?.text?.ar ?? "").trim();
  if (!text) return "no Arabic text";
  if (text.length > MAX_CHARACTERS_PER_RECORD) {
    return `text exceeds ${MAX_CHARACTERS_PER_RECORD} characters`;
  }
  return null;
}

/** Splits the live collection into what will be generated and what is skipped. */
export function selectRecords(docs, limit = null) {
  const eligible = [];
  const skipped = [];
  for (const doc of docs ?? []) {
    const reason = ineligibilityReason(doc);
    const id = String(doc?.documentId ?? doc?.duaId ?? "").trim() || "(no id)";
    if (reason) {
      skipped.push({ documentId: id, reason });
      continue;
    }
    eligible.push({ documentId: id, text: String(doc.text.ar).trim() });
  }
  const capped = limit === null ? eligible : eligible.slice(0, limit);
  return { eligible: capped, skipped, totalEligible: eligible.length };
}

/**
 * Picks a voice from the catalogue the API actually returned.
 *
 * Throws rather than falling back to the API default: an unnamed default is
 * not reproducible, and the whole point of storing a file is that every
 * pilgrim hears the same reading.
 */
export function pickVoice(voices) {
  const arabic = (voices ?? []).filter(
    (v) =>
      v &&
      typeof v.name === "string" &&
      Array.isArray(v.languageCodes) &&
      v.languageCodes.includes(TTS_LANGUAGE_CODE),
  );
  if (arabic.length === 0) {
    throw new Error(
      `No ${TTS_LANGUAGE_CODE} voice in the catalogue. Check that the ` +
        "Text-to-Speech API is enabled on this project.",
    );
  }
  for (const family of VOICE_PREFERENCE) {
    // Sorted so the choice does not depend on the catalogue's own ordering:
    // a run today and a run next month must pick the same voice.
    const match = arabic
      .filter((v) => v.name.includes(family))
      .map((v) => v.name)
      .sort();
    if (match.length > 0) return match[0];
  }
  return arabic.map((v) => v.name).sort()[0];
}

/**
 * The voice's short name, lowercased, for use in an object name.
 *
 * `ar-XA-Chirp3-HD-Algieba` becomes `algieba`. Keeping it in the filename
 * means the voice a file was made with is visible without opening it, which
 * matters once a second voice ever exists in the same bucket.
 */
export function voiceSlug(voiceName) {
  const last = String(voiceName ?? "").split("-").pop() ?? "";
  const slug = last.toLowerCase().replace(/[^a-z0-9]/g, "");
  // An unnameable voice must not silently produce `-<hash>.mp3`, which would
  // read as "no voice" rather than "unknown voice".
  return slug || "voice";
}

/**
 * Where one recording lives.
 *
 * Named for the voice and the sha256 of the AUDIO BYTES — the scheme already
 * in the bucket, written by `review/publish-algieba-audio.mjs`. Two things
 * follow from hashing the bytes rather than the id:
 *
 *   Identical audio is one object. The pack prints البقرة 201 twice, under
 *   two classifications, so two records legitimately carry the same text;
 *   they now share a single file instead of two identical uploads.
 *
 *   A re-generation after a text correction lands at a NEW name rather than
 *   overwriting the old recording in place.
 *
 * What this does NOT do, and must not be relied on for: it does not stop a
 * record from pointing at a stale file. The object name changing does not
 * change `audioUrl`; that protection is `lib/shared/audio/audio_staleness.dart`,
 * which drops the recording when the text it recites is edited.
 */
export function storagePath(voiceName, bytes) {
  const digest = createHash("sha256").update(bytes).digest("hex");
  return `audio/duas/${voiceSlug(voiceName)}-${digest}.mp3`;
}

/**
 * The URL the app stores and plays.
 *
 * Same shape the admin console produces via `getDownloadURL()`, so a
 * generated file and a hand-uploaded one are indistinguishable to the client.
 * The token is part of the URL; it is written to Firestore and never logged.
 */
export function downloadUrl(bucket, path, token) {
  return (
    `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/` +
    `${encodeURIComponent(path)}?alt=media&token=${token}`
  );
}

/**
 * What a Google API error actually says, in one line an operator can act on.
 *
 * A bare `HTTP 403` is three different problems with three different fixes,
 * and the operator is left guessing which. Google names it in `error.status`
 * and `error.message`; swallowing that is the same failure the Worker had
 * before its diagnostics, and the same one `grant_admin_claim.mjs` was fixed
 * for — a lesson this file did not learn until a 403 arrived here too.
 *
 * The message is redacted and truncated before it is shown: Google does not
 * echo the Authorization header today, but "does not" is a property of
 * today's API, and a credential in a terminal scrollback is not recoverable.
 */
export function describeApiError(httpStatus, body) {
  const err = (body && typeof body === "object" && body.error) || {};
  const code =
    typeof err.status === "string" && err.status ? err.status : `HTTP_${httpStatus}`;
  let message = typeof err.message === "string" ? err.message : "";
  message = message.replace(/[A-Za-z0-9._-]{40,}/g, "[redacted]").slice(0, 200);
  return message ? `${code}: ${message}` : code;
}

/** What a 403 usually means here, and the command that fixes each. */
export const HELP_403 = [
  "",
  "If that was a 403, it is almost always one of:",
  "  1. The Text-to-Speech API is not enabled on the project:",
  "       gcloud services enable texttospeech.googleapis.com \\",
  "         --project=dhakker-160d0",
  "  2. The project has no billing account. The free tier still requires",
  "     one; nothing is charged within it.",
  "  3. The signed-in account cannot use the API, or cannot write to the",
  "     bucket:",
  "       gcloud auth list          # who am I",
  "",
].join("\n");

/** Reads a response body as JSON, or null. Never throws. */
async function safeJson(res) {
  try {
    return await res.json();
  } catch {
    return null;
  }
}

/** Synthesises one text. Returns the raw MP3 bytes. */
export async function synthesise(text, voiceName, plan, deps = {}) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  const res = await doFetch(SYNTHESIS_ENDPOINT, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${plan.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      // `text`, never `ssml`: the stored strings are the ministry's text and
      // are not markup. Passing them as SSML would let a stray `<` change how
      // a supplication is read.
      input: { text },
      voice: { languageCode: TTS_LANGUAGE_CODE, name: voiceName },
      audioConfig: { audioEncoding: AUDIO_ENCODING },
    }),
  });
  if (!res.ok) {
    throw new Error(
      `synthesis failed — ${describeApiError(res.status, await safeJson(res))}`,
    );
  }
  const body = await res.json();
  const b64 = body?.audioContent;
  if (typeof b64 !== "string" || b64 === "") {
    throw new Error("synthesis returned no audio");
  }
  const bytes = Buffer.from(b64, "base64");
  if (bytes.length === 0) throw new Error("synthesis returned empty audio");
  return bytes;
}

/**
 * Uploads the bytes and returns the download URL.
 *
 * Two calls: the object, then the metadata that carries the download token.
 * The token is minted here rather than reused, so re-uploading a file rotates
 * the URL instead of leaving an old one valid.
 */
export async function uploadAudio(duaId, bytes, voiceName, plan, deps = {}) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  const path = storagePath(voiceName, bytes);
  const encoded = encodeURIComponent(path);
  const token = deps.uuid ? deps.uuid() : randomUUID();

  const up = await doFetch(
    `https://storage.googleapis.com/upload/storage/v1/b/${plan.bucket}/o` +
      `?uploadType=media&name=${encoded}`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${plan.token}`,
        "Content-Type": AUDIO_CONTENT_TYPE,
      },
      body: bytes,
    },
  );
  if (!up.ok) {
    throw new Error(
      `upload of ${duaId} failed — ${describeApiError(up.status, await safeJson(up))}`,
    );
  }

  const meta = await doFetch(
    `https://storage.googleapis.com/storage/v1/b/${plan.bucket}/o/${encoded}`,
    {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${plan.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        contentType: AUDIO_CONTENT_TYPE,
        metadata: { firebaseStorageDownloadTokens: token },
      }),
    },
  );
  if (!meta.ok) {
    throw new Error(
      `metadata for ${duaId} failed — ${describeApiError(meta.status, await safeJson(meta))}`,
    );
  }
  return downloadUrl(plan.bucket, path, token);
}

export function documentUrl(plan, duaId) {
  return (
    `https://firestore.googleapis.com/v1/projects/${plan.projectId}` +
    `/databases/${plan.database}/documents/${plan.collection}` +
    `/${encodeURIComponent(duaId)}`
  );
}

/**
 * The PATCH that attaches the audio.
 *
 * The mask names three fields and nothing else, so verification, text and
 * every administrative field survive untouched. `updatedAt` is included
 * because the admin console orders by it and a record whose audio changed
 * should surface as changed.
 */
export function buildAudioWrite(duaId, url, plan, now = new Date()) {
  const mask = AUDIO_WRITE_FIELDS.map(
    (f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`,
  ).join("&");
  return {
    url: `${documentUrl(plan, duaId)}?${mask}`,
    fields: {
      audioMode: { stringValue: "file" },
      audioUrl: { stringValue: url },
      updatedAt: { timestampValue: now.toISOString() },
    },
  };
}

export async function attachAudio(duaId, url, plan, deps = {}) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  const req = buildAudioWrite(duaId, url, plan, deps.now ?? new Date());
  const res = await doFetch(req.url, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${plan.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ fields: req.fields }),
  });
  if (!res.ok) throw new Error(`attach of ${duaId} failed: HTTP ${res.status}`);
  return true;
}

/**
 * Reads the record back and proves it can now play a file.
 *
 * A 200 proves the request was accepted, not that the document is right — the
 * same reasoning as the importer's `verifyWritten`. Verification is re-checked
 * here too: if it somehow changed under us, the audio must not stand.
 */
export async function verifyAttached(duaId, plan, deps = {}) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  const res = await doFetch(documentUrl(plan, duaId), {
    headers: { Authorization: `Bearer ${plan.token}` },
  });
  if (!res.ok) throw new Error(`read-back of ${duaId} failed: HTTP ${res.status}`);
  const body = await res.json();
  const doc = {};
  for (const [k, v] of Object.entries(body.fields ?? {})) {
    doc[k] = fromFirestoreValue(v);
  }
  if (doc.audioMode !== "file") {
    throw new Error(`${duaId}: audioMode is "${doc.audioMode}" after the write`);
  }
  if (String(doc.audioUrl ?? "").trim() === "") {
    throw new Error(`${duaId}: audioUrl is empty after the write`);
  }
  if (doc.verificationStatus !== "verified") {
    throw new Error(
      `${duaId}: verificationStatus is "${doc.verificationStatus}" after the ` +
        "write — the audio must not stand on an unapproved record",
    );
  }
  return true;
}

/** One line per record. Never the text, never the URL, never the token. */
export function planLine(row) {
  return `  ${row.documentId}  |  ${row.text.length} chars`;
}

export async function run(plan, deps = {}, log = console.log) {
  const docs = await listCollection(plan, deps);
  const { eligible, skipped, totalEligible } = selectRecords(docs, plan.limit);

  log("");
  log(`collection:  ${plan.collection}`);
  log(`project:     ${plan.projectId}`);
  log(`eligible:    ${totalEligible}${plan.limit ? ` (limited to ${eligible.length})` : ""}`);
  log(`skipped:     ${skipped.length}`);
  for (const s of skipped) log(`  - ${s.documentId}: ${s.reason}`);
  log("");
  for (const row of eligible) log(planLine(row));
  const characters = eligible.reduce((n, r) => n + r.text.length, 0);
  log("");
  log(`total characters to synthesise: ${characters}`);

  if (!plan.write) {
    log("");
    log("DRY RUN — nothing was synthesised, uploaded or written.");
    log("Re-run with --write plus:");
    log(`  --confirm-project=${plan.projectId} --confirm-count=${eligible.length}`);
    return { generated: 0, skipped: skipped.length, planned: eligible.length };
  }

  if (plan.confirmProject !== plan.projectId) {
    throw new Error(
      `--confirm-project does not match the project this run targets.`,
    );
  }
  if (plan.confirmCount !== eligible.length) {
    throw new Error(
      `--confirm-count=${plan.confirmCount} does not match the ` +
        `${eligible.length} record(s) this run would generate. The collection ` +
        "changed since the dry run; look at the plan again.",
    );
  }

  const voiceName = plan.voice ?? (await listVoices(plan, deps).then(pickVoice));
  log(`voice:       ${voiceName}`);
  log("");

  let generated = 0;
  for (const row of eligible) {
    const bytes = await synthesise(row.text, voiceName, plan, deps);
    const url = await uploadAudio(row.documentId, bytes, voiceName, plan, deps);
    await attachAudio(row.documentId, url, plan, deps);
    await verifyAttached(row.documentId, plan, deps);
    generated += 1;
    // The URL carries a download token, so it is never printed.
    log(`generated ${row.documentId} (${bytes.length} bytes)`);
  }

  log("");
  log(`done: ${generated} generated, ${skipped.length} skipped.`);
  return { generated, skipped: skipped.length, planned: eligible.length };
}

export async function listVoices(plan, deps = {}) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  const res = await doFetch(
    `${VOICES_ENDPOINT}?languageCode=${TTS_LANGUAGE_CODE}`,
    { headers: { Authorization: `Bearer ${plan.token}` } },
  );
  if (!res.ok) {
    throw new Error(
      `voice list failed — ${describeApiError(res.status, await safeJson(res))}`,
    );
  }
  const body = await res.json();
  return body?.voices ?? [];
}

/* c8 ignore start — CLI wiring, exercised by hand rather than tests */
async function main() {
  const args = parseArguments(process.argv.slice(2));

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const bucket = process.env.FIREBASE_STORAGE_BUCKET;
  const token = process.env.GOOGLE_ACCESS_TOKEN;
  if (!projectId || !bucket || !token) {
    throw new Error(
      "FIREBASE_PROJECT_ID, FIREBASE_STORAGE_BUCKET and GOOGLE_ACCESS_TOKEN " +
        "must all be set.\n" +
        "Get a short-lived token with: gcloud auth print-access-token\n" +
        "Do not use a service-account key file for this.",
    );
  }

  await run({ ...args, projectId, bucket, token, database: "(default)" });
}

const isDirectRun =
  process.argv[1] && process.argv[1].endsWith("generate_dua_audio.mjs");
if (isDirectRun) {
  main().catch((err) => {
    console.error(`\n${err.message}`);
    if (/\b403\b|PERMISSION_DENIED/.test(err.message)) {
      console.error(HELP_403);
    }
    // exitCode, not exit(): process.exit() while stdio is still flushing
    // trips a libuv assertion on Windows.
    process.exitCode = 1;
  });
}
/* c8 ignore stop */
