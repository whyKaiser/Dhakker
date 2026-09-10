// Guard tests for the audio generator.
//
// This tool puts a voice on a religious text and hands it to pilgrims. The
// failures that matter are not crashes: generating for a text nobody approved,
// overwriting an admin's own recording, widening the write beyond the three
// audio fields, or printing a download token into a terminal.

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  AUDIO_WRITE_FIELDS,
  MAX_CHARACTERS_PER_RECORD,
  SYNTHESIS_ENDPOINT,
  TTS_LANGUAGE_CODE,
  VOICE_PREFERENCE,
  assertOnlyKnownArguments,
  attachAudio,
  buildAudioWrite,
  downloadUrl,
  ineligibilityReason,
  parseArguments,
  pickVoice,
  planLine,
  run,
  selectRecords,
  storagePath,
  synthesise,
  uploadAudio,
  verifyAttached,
} from "./generate_dua_audio.mjs";

const SOURCE = readFileSync("scripts/generate_dua_audio.mjs", "utf8");

/** The file without its own prose, so a scan tests code and not comments. */
function codeOnly(source) {
  return source
    .split("\n")
    .filter((l) => {
      const t = l.trim();
      return !(t.startsWith("//") || t.startsWith("*") || t.startsWith("/*"));
    })
    .join("\n");
}

test("the comment stripper the scans below rely on works", () => {
  assert.ok(SOURCE.includes("robotic reading"));
  assert.equal(codeOnly(SOURCE).includes("robotic reading"), false);
  assert.ok(codeOnly(SOURCE).includes("audioContent"));
});

const PLAN = {
  projectId: "p",
  database: "(default)",
  collection: "supplications",
  bucket: "b.firebasestorage.app",
  token: "ya29.SECRET",
};

/** A record that is eligible in every respect, for mutation by each test. */
function verified(extra = {}) {
  return {
    documentId: "dua-1",
    verificationStatus: "verified",
    revokedAt: null,
    isActive: true,
    contentKind: "general_dua",
    audioMode: "tts",
    audioUrl: "",
    text: { ar: "اللهم لبيك", en: "Here I am" },
    ...extra,
  };
}

// ── Who may be given a voice ──────────────────────────────────────────────

test("a verified, recitable, audioless record is eligible", () => {
  assert.equal(ineligibilityReason(verified()), null);
});

test("an unapproved record is never given audio", () => {
  // THE rule this file exists for. A voice lends a text authority the review
  // has not granted, and a pilgrim hears it rather than reads it.
  for (const status of ["unverified", "pending", "", null, undefined]) {
    const reason = ineligibilityReason(verified({ verificationStatus: status }));
    assert.match(String(reason), /not verified/);
  }
});

test("a revoked approval is not an approval", () => {
  assert.equal(
    ineligibilityReason(verified({ revokedAt: "2026-01-01T00:00:00Z" })),
    "revoked",
  );
});

test("a hidden record is skipped", () => {
  assert.equal(ineligibilityReason(verified({ isActive: false })), "inactive");
});

test("guidance and evidence get no play button", () => {
  // These are not texts a pilgrim says. Audio on them would read as a
  // recitation.
  for (const kind of ["procedural_guidance", "contextual_evidence", "", null]) {
    assert.match(
      String(ineligibilityReason(verified({ contentKind: kind }))),
      /not recitable/,
    );
  }
});

test("every recitable kind is accepted", () => {
  for (const kind of [
    "specific_text",
    "general_dua",
    "general_dhikr",
    "mosque_entry",
  ]) {
    assert.equal(ineligibilityReason(verified({ contentKind: kind })), null);
  }
});

test("an existing recording is never overwritten, whatever the mode says", () => {
  // A URL with the wrong mode is an admin's problem to fix in the console.
  // Silently replacing their upload is not this script's business.
  for (const mode of ["file", "tts", "", null]) {
    assert.equal(
      ineligibilityReason(verified({ audioMode: mode, audioUrl: "https://x/y.mp3" })),
      "already has audio",
    );
  }
});

test("whitespace is not a recording", () => {
  assert.equal(ineligibilityReason(verified({ audioUrl: "   " })), null);
});

test("a record with no Arabic text is skipped rather than synthesised empty", () => {
  assert.equal(ineligibilityReason(verified({ text: { ar: "  ", en: "x" } })), "no Arabic text");
  assert.equal(ineligibilityReason(verified({ text: {} })), "no Arabic text");
  assert.equal(ineligibilityReason(verified({ text: null })), "no Arabic text");
});

test("an implausibly long text is refused rather than billed", () => {
  const long = "ا".repeat(MAX_CHARACTERS_PER_RECORD + 1);
  assert.match(
    String(ineligibilityReason(verified({ text: { ar: long } }))),
    /exceeds/,
  );
  const atLimit = "ا".repeat(MAX_CHARACTERS_PER_RECORD);
  assert.equal(ineligibilityReason(verified({ text: { ar: atLimit } })), null);
});

test("a document with no id is skipped, not written to an empty path", () => {
  assert.equal(ineligibilityReason(verified({ documentId: "" })), "no document id");
  assert.equal(ineligibilityReason(null), "not a document");
});

test("selection separates the two lists and never loses a record", () => {
  const docs = [
    verified({ documentId: "a" }),
    verified({ documentId: "b", verificationStatus: "unverified" }),
    verified({ documentId: "c", audioUrl: "https://x" }),
  ];
  const { eligible, skipped, totalEligible } = selectRecords(docs);
  assert.deepEqual(eligible.map((e) => e.documentId), ["a"]);
  assert.deepEqual(skipped.map((s) => s.documentId), ["b", "c"]);
  assert.equal(totalEligible, 1);
  assert.equal(eligible.length + skipped.length, docs.length);
});

test("a limit caps what is generated but not what is reported", () => {
  const docs = [1, 2, 3].map((n) => verified({ documentId: `d${n}` }));
  const { eligible, totalEligible } = selectRecords(docs, 2);
  assert.equal(eligible.length, 2);
  assert.equal(totalEligible, 3);
});

// ── Arguments ─────────────────────────────────────────────────────────────

test("an unrecognised flag is refused, not ignored", () => {
  assert.throws(() => assertOnlyKnownArguments(["--force", "--staging"]), /Unrecognised/);
  assert.throws(
    () => parseArguments(["--staging", "--all"]),
    /Unrecognised/,
  );
});

test("--limit consumes its value rather than reading it as a flag", () => {
  assert.doesNotThrow(() => assertOnlyKnownArguments(["--staging", "--limit", "3"]));
  assert.equal(parseArguments(["--staging", "--limit", "3"]).limit, 3);
  assert.equal(parseArguments(["--staging", "--limit=3"]).limit, 3);
});

test("the destination is named explicitly and never inferred", () => {
  assert.throws(() => parseArguments([]), /exactly one/);
  assert.throws(() => parseArguments(["--staging", "--production"]), /exactly one/);
  assert.equal(parseArguments(["--production"]).collection, "supplications");
  assert.equal(parseArguments(["--staging"]).collection, "supplications_staging");
});

test("a partial production run is refused", () => {
  // Some records with audio and some without, with nothing that says which.
  assert.throws(
    () => parseArguments(["--production", "--limit=1"]),
    /not allowed against production/,
  );
  assert.doesNotThrow(() => parseArguments(["--staging", "--limit=1"]));
});

test("dry run is the default", () => {
  assert.equal(parseArguments(["--production"]).write, false);
});

test("a write needs both confirmations", () => {
  assert.throws(() => parseArguments(["--production", "--write"]), /confirm-project/);
  assert.throws(
    () => parseArguments(["--production", "--write", "--confirm-project=p"]),
    /confirm-count/,
  );
  assert.deepEqual(
    parseArguments([
      "--production",
      "--write",
      "--confirm-project=p",
      "--confirm-count=7",
    ]),
    {
      collection: "supplications",
      production: true,
      write: true,
      limit: null,
      voice: null,
      confirmProject: "p",
      confirmCount: 7,
    },
  );
});

test("confirmations without --write are an error, not a quiet dry run", () => {
  // Passing them means the operator believes this run is writing. Reporting
  // a dry run would tell them the job is done.
  assert.throws(
    () => parseArguments(["--production", "--confirm-project=p", "--confirm-count=1"]),
    /without --write/,
  );
});

test("a bad limit is refused", () => {
  for (const v of ["0", "-1", "x", "1.5"]) {
    assert.throws(() => parseArguments(["--staging", `--limit=${v}`]), /positive integer/);
  }
});

// ── The voice ─────────────────────────────────────────────────────────────

const CATALOGUE = [
  { name: "ar-XA-Standard-B", languageCodes: ["ar-XA"] },
  { name: "ar-XA-Wavenet-A", languageCodes: ["ar-XA"] },
  { name: "ar-XA-Chirp3-HD-Zephyr", languageCodes: ["ar-XA"] },
  { name: "ar-XA-Chirp3-HD-Achernar", languageCodes: ["ar-XA"] },
  { name: "en-US-Chirp3-HD-Aoede", languageCodes: ["en-US"] },
];

test("the neural family wins over the older tiers", () => {
  assert.equal(pickVoice(CATALOGUE), "ar-XA-Chirp3-HD-Achernar");
});

test("the choice does not depend on the catalogue's ordering", () => {
  // A run today and a run next month must pick the same voice, or two
  // supplications are read by two different people.
  const shuffled = [...CATALOGUE].reverse();
  assert.equal(pickVoice(shuffled), pickVoice(CATALOGUE));
});

test("an English voice is never used to read Arabic", () => {
  const picked = pickVoice(CATALOGUE);
  assert.ok(picked.startsWith("ar-XA"), picked);
  assert.throws(
    () => pickVoice([{ name: "en-US-Chirp3-HD-Aoede", languageCodes: ["en-US"] }]),
    /No ar-XA voice/,
  );
});

test("older tiers are used when the neural one is absent", () => {
  assert.equal(
    pickVoice([
      { name: "ar-XA-Standard-B", languageCodes: ["ar-XA"] },
      { name: "ar-XA-Wavenet-A", languageCodes: ["ar-XA"] },
    ]),
    "ar-XA-Wavenet-A",
  );
});

test("an empty or malformed catalogue raises rather than defaulting", () => {
  // The API's own default is unnamed and not reproducible.
  for (const bad of [[], null, undefined, [null, "x", { name: "n" }]]) {
    assert.throws(() => pickVoice(bad), /No ar-XA voice/);
  }
});

test("the preference list is ordered best-first", () => {
  assert.equal(VOICE_PREFERENCE[0], "Chirp3-HD");
});

// ── Synthesis ─────────────────────────────────────────────────────────────

test("the request sends the text as text, never as SSML", async () => {
  // A stray "<" in a ministry text must not be able to change how it is read.
  let sent = null;
  await synthesise("اللهم لبيك", "ar-XA-Chirp3-HD-Achernar", PLAN, {
    fetch: async (url, init) => {
      sent = { url: String(url), body: JSON.parse(init.body) };
      return new Response(JSON.stringify({ audioContent: Buffer.from("id3").toString("base64") }), {
        status: 200,
      });
    },
  });
  assert.equal(sent.url, SYNTHESIS_ENDPOINT);
  assert.deepEqual(sent.body.input, { text: "اللهم لبيك" });
  assert.equal("ssml" in sent.body.input, false);
  assert.equal(sent.body.voice.languageCode, TTS_LANGUAGE_CODE);
  assert.equal(sent.body.voice.name, "ar-XA-Chirp3-HD-Achernar");
});

test("an empty or absent audio payload is an error, not a zero-byte file", async () => {
  for (const body of [{}, { audioContent: "" }, { audioContent: null }]) {
    await assert.rejects(
      () =>
        synthesise("x", "v", PLAN, {
          fetch: async () => new Response(JSON.stringify(body), { status: 200 }),
        }),
      /no audio|empty audio/,
    );
  }
});

test("a failed synthesis raises rather than returning silence", async () => {
  await assert.rejects(
    () =>
      synthesise("x", "v", PLAN, {
        fetch: async () => new Response("nope", { status: 429 }),
      }),
    /HTTP 429/,
  );
});

// ── Upload ────────────────────────────────────────────────────────────────

test("the file lands at the path the app already reads", () => {
  // admin_supplication_edit_screen.dart writes audio/duas/<id>.mp3. A
  // generated file and a hand-uploaded one must be the same object.
  assert.equal(storagePath("dua-1"), "audio/duas/dua-1.mp3");
});

test("the upload names the object and the metadata carries the token", async () => {
  const calls = [];
  const url = await uploadAudio("dua-1", Buffer.from("mp3"), PLAN, {
    uuid: () => "TOKEN-123",
    fetch: async (u, init) => {
      calls.push({ url: String(u), method: init.method, body: init.body });
      return new Response("{}", { status: 200 });
    },
  });
  assert.equal(calls.length, 2);
  assert.match(calls[0].url, /uploadType=media/);
  assert.match(calls[0].url, /name=audio%2Fduas%2Fdua-1\.mp3/);
  assert.equal(calls[1].method, "PATCH");
  assert.deepEqual(JSON.parse(calls[1].body).metadata, {
    firebaseStorageDownloadTokens: "TOKEN-123",
  });
  assert.equal(url, downloadUrl(PLAN.bucket, "audio/duas/dua-1.mp3", "TOKEN-123"));
});

test("a failed upload is not followed by a metadata call", async () => {
  const calls = [];
  await assert.rejects(
    () =>
      uploadAudio("dua-1", Buffer.from("mp3"), PLAN, {
        fetch: async (u) => {
          calls.push(String(u));
          return new Response("no", { status: 403 });
        },
      }),
    /upload of dua-1 failed/,
  );
  assert.equal(calls.length, 1);
});

test("the download URL is the shape the client already plays", () => {
  const url = downloadUrl("b.app", "audio/duas/a b.mp3", "t");
  assert.match(url, /^https:\/\/firebasestorage\.googleapis\.com\/v0\/b\/b\.app\/o\//);
  assert.match(url, /audio%2Fduas%2Fa%20b\.mp3\?alt=media&token=t$/);
});

// ── The Firestore write ───────────────────────────────────────────────────

test("the write touches exactly three fields", () => {
  // The mask is the whole protection: anything not named survives. Text,
  // verification, isActive, usage_count and every admin field are outside it.
  assert.deepEqual([...AUDIO_WRITE_FIELDS], ["audioMode", "audioUrl", "updatedAt"]);
  const req = buildAudioWrite("dua-1", "https://x", PLAN, new Date(0));
  const masked = [...req.url.matchAll(/updateMask\.fieldPaths=([^&]+)/g)].map((m) =>
    decodeURIComponent(m[1]),
  );
  assert.deepEqual(masked, ["audioMode", "audioUrl", "updatedAt"]);
  assert.deepEqual(Object.keys(req.fields), ["audioMode", "audioUrl", "updatedAt"]);
});

test("no verification field can reach the write", () => {
  const req = buildAudioWrite("dua-1", "https://x", PLAN);
  const serialised = req.url + JSON.stringify(req.fields);
  for (const f of ["verificationStatus", "verifiedAt", "verifiedBy", "text", "isActive"]) {
    assert.equal(serialised.includes(f), false, `${f} must not be written`);
  }
});

test("the mode is switched to file, or the player keeps using TTS", () => {
  // dua_playback_service.dart requires BOTH audioMode == 'file' and a
  // non-empty audioUrl. Writing the URL alone would change nothing audible.
  const req = buildAudioWrite("dua-1", "https://x/y.mp3", PLAN);
  assert.equal(req.fields.audioMode.stringValue, "file");
  assert.equal(req.fields.audioUrl.stringValue, "https://x/y.mp3");
});

test("the write targets the named collection and document", async () => {
  let seen = null;
  await attachAudio("dua 1", "https://x", PLAN, {
    fetch: async (u) => {
      seen = String(u);
      return new Response("{}", { status: 200 });
    },
  });
  assert.match(seen, /\/documents\/supplications\/dua%201\?/);
});

test("the read-back refuses to accept a write that did not take", async () => {
  const cases = [
    [{ audioMode: { stringValue: "tts" }, audioUrl: { stringValue: "u" }, verificationStatus: { stringValue: "verified" } }, /audioMode/],
    [{ audioMode: { stringValue: "file" }, audioUrl: { stringValue: "" }, verificationStatus: { stringValue: "verified" } }, /audioUrl is empty/],
    [{ audioMode: { stringValue: "file" }, audioUrl: { stringValue: "u" }, verificationStatus: { stringValue: "unverified" } }, /must not stand/],
  ];
  for (const [fields, expected] of cases) {
    await assert.rejects(
      () =>
        verifyAttached("dua-1", PLAN, {
          fetch: async () => new Response(JSON.stringify({ fields }), { status: 200 }),
        }),
      expected,
    );
  }
});

// ── The run ───────────────────────────────────────────────────────────────

/** A fake backend: one listed document, everything else accepted. */
function backend(docs, calls = []) {
  return async (url, init = {}) => {
    const u = String(url);
    calls.push({ url: u, method: init.method ?? "GET" });
    if (u.includes("/documents/") && !u.includes("?updateMask") && (init.method ?? "GET") === "GET") {
      if (u.endsWith("?pageSize=300") || u.includes("pageSize=")) {
        return new Response(
          JSON.stringify({
            documents: docs.map((d) => ({
              name: `projects/p/databases/(default)/documents/supplications/${d.documentId}`,
              fields: {
                verificationStatus: { stringValue: d.verificationStatus },
                isActive: { booleanValue: d.isActive },
                contentKind: { stringValue: d.contentKind },
                audioMode: { stringValue: d.audioMode },
                audioUrl: { stringValue: d.audioUrl },
                revokedAt: { nullValue: null },
                text: { mapValue: { fields: { ar: { stringValue: d.text.ar } } } },
              },
            })),
          }),
          { status: 200 },
        );
      }
      return new Response(
        JSON.stringify({
          fields: {
            audioMode: { stringValue: "file" },
            audioUrl: { stringValue: "https://x?token=SECRET-TOKEN" },
            verificationStatus: { stringValue: "verified" },
          },
        }),
        { status: 200 },
      );
    }
    if (u.startsWith("https://texttospeech.googleapis.com/v1/voices")) {
      return new Response(JSON.stringify({ voices: CATALOGUE }), { status: 200 });
    }
    if (u === SYNTHESIS_ENDPOINT) {
      return new Response(
        JSON.stringify({ audioContent: Buffer.from("ID3audio").toString("base64") }),
        { status: 200 },
      );
    }
    return new Response("{}", { status: 200 });
  };
}

test("a dry run contacts nothing beyond the read that builds the plan", async () => {
  const calls = [];
  const printed = [];
  const result = await run(
    { ...PLAN, write: false, limit: null, voice: null },
    { fetch: backend([verified()], calls) },
    (l) => printed.push(String(l)),
  );
  assert.equal(result.generated, 0);
  assert.equal(result.planned, 1);
  assert.deepEqual(
    calls.filter((c) => c.method !== "GET"),
    [],
    "a dry run performed a non-GET request",
  );
  const all = calls.map((c) => c.url).join("\n");
  assert.equal(all.includes("texttospeech"), false);
  assert.equal(all.includes("storage.googleapis.com"), false);
  assert.match(printed.join("\n"), /DRY RUN/);
});

test("the dry run prints the confirmations the real run will demand", () => {
  // Otherwise the operator invents a count, and the mismatch check that is
  // supposed to catch a changed collection catches a typo instead.
  const printed = [];
  return run(
    { ...PLAN, write: false, limit: null, voice: null },
    { fetch: backend([verified()]) },
    (l) => printed.push(String(l)),
  ).then(() => {
    const all = printed.join("\n");
    assert.match(all, /--confirm-project=p/);
    assert.match(all, /--confirm-count=1/);
  });
});

test("a count that no longer matches the collection stops the run", async () => {
  // The collection changed between the dry run and the write: the operator is
  // confirming a plan that no longer exists.
  const calls = [];
  await assert.rejects(
    () =>
      run(
        {
          ...PLAN,
          write: true,
          limit: null,
          voice: null,
          confirmProject: "p",
          confirmCount: 5,
        },
        { fetch: backend([verified()], calls) },
        () => {},
      ),
    /does not match/,
  );
  assert.deepEqual(calls.filter((c) => c.method !== "GET"), []);
});

test("a project that does not match stops the run", async () => {
  await assert.rejects(
    () =>
      run(
        {
          ...PLAN,
          write: true,
          limit: null,
          voice: null,
          confirmProject: "other",
          confirmCount: 1,
        },
        { fetch: backend([verified()]) },
        () => {},
      ),
    /--confirm-project does not match/,
  );
});

test("a real run synthesises, uploads, attaches and verifies each record", async () => {
  const calls = [];
  const result = await run(
    {
      ...PLAN,
      write: true,
      limit: null,
      voice: null,
      confirmProject: "p",
      confirmCount: 1,
    },
    { fetch: backend([verified()], calls), uuid: () => "T" },
    () => {},
  );
  assert.equal(result.generated, 1);
  const urls = calls.map((c) => c.url);
  assert.ok(urls.some((u) => u === SYNTHESIS_ENDPOINT), "no synthesis");
  assert.ok(urls.some((u) => u.includes("uploadType=media")), "no upload");
  assert.ok(urls.some((u) => u.includes("updateMask")), "no attach");
});

test("an unapproved record is not synthesised even when it is the only one", async () => {
  const calls = [];
  await run(
    { ...PLAN, write: true, limit: null, voice: null, confirmProject: "p", confirmCount: 0 },
    { fetch: backend([verified({ verificationStatus: "unverified" })], calls) },
    () => {},
  );
  assert.equal(
    calls.some((c) => c.url === SYNTHESIS_ENDPOINT),
    false,
    "an unverified record reached the synthesiser",
  );
});

test("a failure stops the run rather than leaving a trail of half-written records", async () => {
  const calls = [];
  await assert.rejects(
    () =>
      run(
        { ...PLAN, write: true, limit: null, voice: null, confirmProject: "p", confirmCount: 2 },
        {
          fetch: async (url, init) => {
            calls.push(String(url));
            if (String(url) === SYNTHESIS_ENDPOINT) {
              return new Response("no", { status: 500 });
            }
            return backend([verified({ documentId: "a" }), verified({ documentId: "b" })])(
              url,
              init,
            );
          },
        },
        () => {},
      ),
    /synthesis failed/,
  );
  assert.equal(calls.filter((u) => u.includes("updateMask")).length, 0);
});

// ── What must never be printed ────────────────────────────────────────────

test("nothing it prints contains the access token or a download token", async () => {
  // A download token in a scrollback is a permanent read grant on the file.
  const printed = [];
  await run(
    {
      ...PLAN,
      token: "ya29.SUPER-SECRET-TOKEN",
      write: true,
      limit: null,
      voice: null,
      confirmProject: "p",
      confirmCount: 1,
    },
    { fetch: backend([verified()]), uuid: () => "DOWNLOAD-TOKEN-XYZ" },
    (l) => printed.push(String(l)),
  );
  const all = printed.join("\n");
  for (const secret of ["ya29", "SUPER-SECRET-TOKEN", "DOWNLOAD-TOKEN-XYZ", "SECRET-TOKEN"]) {
    assert.equal(all.includes(secret), false, `${secret} was printed`);
  }
  // The document id IS printed: it is how the operator follows the run.
  assert.ok(all.includes("dua-1"));
});

test("the plan prints a length, never the text of a supplication", () => {
  const line = planLine({ documentId: "dua-1", text: "اللهم لبيك" });
  assert.equal(line.includes("اللهم"), false);
  assert.match(line, /dua-1/);
  assert.match(line, /10 chars/);
});

// ── What the file must never contain ──────────────────────────────────────

test("no key file, no ambient credential, no committed secret", () => {
  const code = codeOnly(SOURCE);
  for (const token of [
    "GOOGLE_APPLICATION_CREDENTIALS",
    "private_key",
    "serviceAccount.json",
    "firebase-admin",
    "AIza",
  ]) {
    assert.equal(code.includes(token), false, `${token} must not appear`);
  }
});

test("it reaches only Google's TTS, Storage and Firestore", () => {
  const hosts = [...codeOnly(SOURCE).matchAll(/https:\/\/([a-z0-9.-]+)/g)].map((m) => m[1]);
  assert.deepEqual(
    [...new Set(hosts)].sort(),
    [
      "firebasestorage.googleapis.com",
      "firestore.googleapis.com",
      "storage.googleapis.com",
      "texttospeech.googleapis.com",
    ],
  );
});

test("there is no flag or branch that skips the approval check", () => {
  const code = codeOnly(SOURCE);
  for (const token of ["--force", "--skip-verify", "--unverified", "allowUnverified"]) {
    assert.equal(code.includes(token), false, `${token} must not exist`);
  }
  // The comparison itself, not a variable that could be set elsewhere.
  assert.ok(code.includes('verificationStatus !== "verified"'));
});
