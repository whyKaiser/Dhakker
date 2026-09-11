import assert from "node:assert/strict";
import test from "node:test";
import { buildPlan, buildCommit, assertSnapshotUnchanged, assertOnlyAudioChanged, splitForSynthesis, EXPECTED_COUNT, BUCKET } from "./publish-algieba-audio.mjs";

function documents() {
  return Array.from({ length: EXPECTED_COUNT }, (_, i) => ({
    name: `projects/dhakker-160d0/databases/(default)/documents/supplications/dua-${i}`,
    updateTime: "2026-09-10T00:00:00.123456Z",
    fields: {
      verificationStatus: { stringValue: "verified" }, isActive: { booleanValue: true },
      revokedAt: { nullValue: null }, contentKind: { stringValue: "general_dua" },
      audioMode: { stringValue: "tts" }, audioUrl: { stringValue: "" },
      title: { mapValue: { fields: { ar: { stringValue: "دعاء" } } } },
      text: { mapValue: { fields: { ar: { stringValue: "  رَبِّ زِدْنِي عِلْمًا  " } } } },
    },
  }));
}

test("plan preserves exact text and deduplicates synthesis by canonical bytes", () => {
  const plan = buildPlan(documents());
  assert.equal(plan.records.length, 53);
  assert.equal(plan.uniqueTexts, 1);
  assert.equal(plan.records[0].text, "  رَبِّ زِدْنِي عِلْمًا  ");
  assert.equal(plan.characters, [...plan.records[0].text].length);
  assert.equal(plan.voice, "ar-XA-Chirp3-HD-Algieba");
});

for (const [field, value] of [
  ["verificationStatus", { stringValue: "pending" }],
  ["isActive", { booleanValue: false }],
  ["revokedAt", { timestampValue: "2026-09-10T00:00:00Z" }],
  ["deploymentBlocked", { booleanValue: true }],
  ["excludedFromImport", { booleanValue: true }],
  ["reviewStatus", { stringValue: "blocked" }],
  ["audioUrl", { stringValue: "existing-file" }],
  ["contentKind", { stringValue: "procedural_guidance" }],
]) {
  test(`plan rejects ${field} before synthesis`, () => {
    const docs = documents(); docs[0].fields[field] = value;
    assert.throws(() => buildPlan(docs));
  });
}

test("plan rejects missing explicit activity and oversized Arabic input", () => {
  const docs = documents(); delete docs[0].fields.isActive;
  assert.throws(() => buildPlan(docs));
  docs[0].fields.isActive = { booleanValue: true };
  docs[0].fields.text.mapValue.fields.ar.stringValue = "ع".repeat(2600);
  assert.throws(() => buildPlan(docs));
});
test("plan refuses changed count, collection, path traversal, missing version and duplicate ids", () => {
  assert.throws(() => buildPlan(documents().slice(1)));
  for (const name of ["projects/other/databases/(default)/documents/users/user1", "projects/dhakker-160d0/databases/(default)/documents/supplications/../../x"]) {
    const docs = documents(); docs[0].name = name; assert.throws(() => buildPlan(docs));
  }
  const missingVersion = documents(); delete missingVersion[0].updateTime;
  assert.throws(() => buildPlan(missingVersion));
  const duplicate = documents(); duplicate[0].name = duplicate[1].name;
  assert.throws(() => buildPlan(duplicate));
});
test("snapshot guard catches concurrent source edits and ignores result ordering", () => {
  const before = documents(); const after = structuredClone(before).reverse();
  assert.doesNotThrow(() => assertSnapshotUnchanged(before, after));
  after[0].updateTime = "2026-09-10T00:00:01Z";
  assert.throws(() => assertSnapshotUnchanged(before, after));
});
test("atomic commit changes only audio fields plus server timestamp, with every version guarded", () => {
  const plan = buildPlan(documents());
  const urls = new Map(plan.records.map(r => [r.id, `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/audio%2Fduas%2Fsample.mp3?alt=media&token=test-only`]));
  const body = buildCommit(plan.records, urls);
  assert.equal(body.writes.length, 53);
  for (const write of body.writes) {
    assert.deepEqual(Object.keys(write.update.fields), ["audioMode", "audioUrl"]);
    assert.deepEqual(write.updateMask.fieldPaths, ["audioMode", "audioUrl"]);
    assert.deepEqual(write.updateTransforms, [{ fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" }]);
    assert.equal(write.currentDocument.updateTime, "2026-09-10T00:00:00.123456Z");
    assert.equal(write.update.fields.audioMode.stringValue, "file");
  }
  urls.set(plan.records[0].id, "https://other.invalid/file.mp3");
  assert.throws(() => buildCommit(plan.records, urls));
});
test("read-back verification rejects unrelated mutations, wrong URL and TTS mode", () => {
  const before = documents()[0]; const after = structuredClone(before);
  after.fields.audioMode = { stringValue: "file" };
  after.fields.audioUrl = { stringValue: "expected-url" };
  after.fields.updatedAt = { timestampValue: "2026-09-10T01:00:00Z" };
  assert.doesNotThrow(() => assertOnlyAudioChanged(before, after, "expected-url"));
  assert.throws(() => assertOnlyAudioChanged(before, after, "wrong-url"));
  after.fields.verificationStatus.stringValue = "pending";
  assert.throws(() => assertOnlyAudioChanged(before, after, "expected-url"));
  after.fields.verificationStatus.stringValue = "verified";
  after.fields.audioMode.stringValue = "tts";
  assert.throws(() => assertOnlyAudioChanged(before, after, "expected-url"));
});

test("long-sentence splitting preserves every Arabic character, diacritic and whitespace", () => {
  const text = "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْهُدَى، وَالتُّقَى، وَالْعَفَافَ، وَالْغِنَى.  ".repeat(12);
  const parts = splitForSynthesis(text);
  assert.ok(parts.length > 1);
  assert.equal(parts.join(""), text);
  assert.ok(parts.every(p => p.length <= 300 && p.trim().length > 0));
  assert.deepEqual(splitForSynthesis("دعاء قصير"), ["دعاء قصير"]);
});
test("splitting falls back to existing whitespace, never divides a word or invents punctuation", () => {
  const text = "رَبَّنَآ ءَاتِنَا فِي ٱلدُّنۡيَا حَسَنَةٗ ".repeat(15);
  const parts = splitForSynthesis(text);
  assert.equal(parts.join(""), text);
  assert.ok(parts.slice(0, -1).every(p => /\s$/u.test(p)));
  assert.throws(() => splitForSynthesis("ع".repeat(301)));
});
