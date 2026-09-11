import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { makePlan, allowedRequest, internalPauses, synthesisBody, slowAudio, PROFILE, validateApprovedSample } from "./finalize-algieba-audio.mjs";
import { speechFor, spelling } from "./dua-speech-vowels.mjs";
import { SPECIAL_SPEECH_MARKS } from "./dua-speech-text.mjs";
import { sha256, buildCommit } from "./publish-algieba-audio.mjs";
const json = relative => JSON.parse(readFileSync(new URL(relative, import.meta.url)));
const originals = json("./fixtures/algieba-original-records.json").records;
const snapshot = { documents: originals.map(r => ({
  name: `projects/dhakker-160d0/databases/(default)/documents/supplications/${r.id}`,
  updateTime: "2026-09-10T17:00:00Z", fields: {
    text: { mapValue: { fields: { ar: { stringValue: r.text } } } },
    title: { mapValue: { fields: { ar: { stringValue: r.title } } } },
    isActive: { booleanValue: true }, verificationStatus: { stringValue: "verified" },
    revokedAt: { nullValue: null }, contentKind: { stringValue: "general_dua" },
    audioMode: { stringValue: "file" },
    audioUrl: { stringValue: `https://firebasestorage.googleapis.com/v0/b/dhakker-160d0.firebasestorage.app/o/audio%2Fduas%2Falgieba-${r.audioSha256}.mp3?alt=media&token=fixture` },
  },
})) };

test("53 canonical texts stay exact; 31 corrections, 22 retained performances", () => {
  const plan = makePlan(snapshot.documents, originals);
  assert.equal(plan.records.length, 53);
  assert.equal(plan.records.filter(r => r.regenerate).length, 31);
  for (const row of plan.records) {
    assert.equal(row.canonicalText, originals.find(r => r.id === row.id).text);
    assert.equal(row.canonicalTextSha256, sha256(row.canonicalText));
    assert.ok(!SPECIAL_SPEECH_MARKS.test(row.speechText));
  }
});
test("accepted hasanah wording uses ordinary vowels and commas", () => {
  const row = originals.find(r => r.id.endsWith("general-001"));
  const text = speechFor(row.id, row.text).speechText;
  assert.ok(text.includes("حَسَنَةً،"));
  assert.equal(spelling(text), "ربنا آتنا في الدنيا حسنة وفي الآخرة حسنة وقنا عذاب النار");
});
test("changing canonical text, review eligibility, or existing audio fails closed", () => {
  for (const field of ["text", "verificationStatus", "audioUrl"]) {
    const docs = structuredClone(snapshot.documents);
    docs[0].fields[field] = { stringValue: "changed" };
    assert.throws(() => makePlan(docs, originals));
  }
});
test("generation and read modes cannot mutate Firestore or Storage", () => {
  const commit = "https://firestore.googleapis.com/v1/projects/dhakker-160d0/databases/(default)/documents:commit";
  assert.equal(allowedRequest("--generate", commit, "POST"), false);
  assert.equal(allowedRequest("--verify", commit, "POST"), false);
  assert.equal(allowedRequest("--publish", commit, "POST"), true);
  assert.equal(allowedRequest("--publish", commit.replace("dhakker-160d0", "other"), "POST"), false);
  assert.equal(allowedRequest("--publish", commit, "DELETE"), false);
});
test("all writes are audio-only, atomic-batch shaped, and updateTime guarded", () => {
  const plan = makePlan(snapshot.documents, originals);
  const urls = new Map(plan.records.map(r => [r.id, `https://firebasestorage.googleapis.com/v0/b/dhakker-160d0.firebasestorage.app/o/test-${r.id}`]));
  const commit = buildCommit(plan.records, urls);
  assert.equal(commit.writes.length, 53);
  for (const write of commit.writes) {
    assert.deepEqual(write.updateMask.fieldPaths, ["audioMode", "audioUrl"]);
    assert.ok(write.currentDocument.updateTime);
    assert.deepEqual(Object.keys(write.update.fields), ["audioMode", "audioUrl"]);
  }
});
test("pause detector excludes leading/trailing silence and short closures", () => {
  assert.deepEqual(internalPauses("silence_start: 0\nsilence_end: 0.23\nsilence_start: 1\nsilence_end: 1.05\nsilence_start: 2.1\nsilence_end: 2.4\nsilence_start: 5\nsilence_end: 5.18", 5.184), [[2.1, 2.4]]);
});
test("synthesis profile matches approved voice; cache identity includes rate", () => {
  assert.equal(synthesisBody("test").audioConfig.speakingRate, 1.15);
  assert.equal(synthesisBody("test").voice.name, "ar-XA-Chirp3-HD-Algieba");
  assert.equal(PROFILE.tempo, 0.9);
});
test("slowdown preserves speech source and extends only detected silence", () => {
  // Deterministic local tones, not a production recording or a paid TTS call.
  const fixture = spawnSync("ffmpeg", [
    "-v", "error", "-f", "lavfi", "-i", "sine=frequency=880:duration=1:sample_rate=24000",
    "-f", "lavfi", "-i", "anullsrc=r=24000:cl=mono:d=0.4",
    "-f", "lavfi", "-i", "sine=frequency=880:duration=1:sample_rate=24000",
    "-filter_complex", "[0:a][1:a][2:a]concat=n=3:v=0:a=1[out]",
    "-map", "[out]", "-codec:a", "libmp3lame", "-b:a", "64k", "-f", "mp3", "pipe:1",
  ], {maxBuffer: 1024 * 1024});
  assert.equal(fixture.status, 0, "ffmpeg must be installed for offline audio tests");
  const bytes = fixture.stdout;
  const output = slowAudio(bytes);
  assert.equal(output.transformation.sourceAudioSha256, sha256(bytes));
  assert.equal(output.transformation.extendedSilences.length, 1);
  assert.ok(output.bytes.length > 300);
});
test("unreviewed, substituted and incorrectly hashed samples cannot claim approval", () => {
  const bytes = Buffer.from("offline fixture; not an approved recording");
  assert.throws(() => validateApprovedSample(bytes, {humanListeningStatus: "pending"}), /listening approval/);
  assert.throws(() => validateApprovedSample(bytes, {
    humanListeningStatus: "approved-by-user", audioSha256: sha256(bytes),
  }), /metadata/);
  assert.throws(() => validateApprovedSample(bytes, {
    humanListeningStatus: "approved-by-user", audioSha256: PROFILE.approvedSampleSha256,
  }), /Sample bytes/);
});
