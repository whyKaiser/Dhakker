import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import { buildRepairPlan, requestFor } from "./repair-algieba-audio.mjs";
const { records } = JSON.parse(readFileSync(new URL("fixtures/algieba-original-records.json", import.meta.url)));
function documents() {
  return records.map(r => ({ name: `projects/dhakker-160d0/databases/(default)/documents/supplications/${r.id}`,
    updateTime: "2026-09-10T17:00:00Z", fields: {
      text: { mapValue: { fields: { ar: { stringValue: r.text } } } },
      title: { mapValue: { fields: { ar: { stringValue: r.title } } } },
      isActive: { booleanValue: true }, verificationStatus: { stringValue: "verified" },
      revokedAt: { nullValue: null }, contentKind: { stringValue: "general_dua" },
      audioMode: { stringValue: "file" },
      audioUrl: { stringValue: `https://firebasestorage.googleapis.com/v0/b/dhakker-160d0.firebasestorage.app/o/audio%2Fduas%2Falgieba-${r.audioSha256}.mp3?alt=media&token=fixture` },
    } }));
}
test("plan changes only the 31 symbol-affected readings and deduplicates the shared dua", () => {
  const plan = buildRepairPlan(documents(), records);
  assert.equal(plan.checkedRecords, 53);
  assert.equal(plan.records.length, 31);
  assert.equal(plan.uniqueSpeechTexts, 30);
  assert.equal(plan.unchangedIds.length, 22);
  assert.equal(plan.characters, 3522);
  assert.ok(plan.records.every(r => r.updateTime));
  assert.ok(plan.records.every(r => !JSON.stringify(r).includes("token=")));
});
for (const [key, value] of [
  ["isActive", { booleanValue: false }],
  ["verificationStatus", { stringValue: "pending" }],
  ["contentKind", { stringValue: "procedural_guidance" }],
  ["revokedAt", { timestampValue: "2026-09-10T17:00:00Z" }],
  ["audioUrl", { stringValue: "https://firebasestorage.googleapis.com/v0/b/dhakker-160d0.firebasestorage.app/o/other.mp3" }],
]) test(`repair refuses changed ${key}`, () => {
  const docs = documents(); docs[0].fields[key] = value;
  assert.throws(() => buildRepairPlan(docs, records));
});
test("repair refuses missing, duplicate and edited canonical sources", () => {
  assert.throws(() => buildRepairPlan(documents().slice(1), records));
  const duplicate = documents(); duplicate[0] = duplicate[1];
  assert.throws(() => buildRepairPlan(duplicate, records));
  const changed = documents(); changed[0].fields.text.mapValue.fields.ar.stringValue += " كلمة";
  assert.throws(() => buildRepairPlan(changed, records));
});
test("preparation and synthesis cannot publish, upload or call other services", async () => {
  for (const mode of ["--prepare", "--sample", "--generate"]) {
    const request = requestFor("fixture", mode);
    for (const url of [
      "https://firestore.googleapis.com/v1/projects/dhakker-160d0/databases/(default)/documents:commit",
      "https://storage.googleapis.com/upload/storage/v1/b/dhakker-160d0.firebasestorage.app/o",
      "https://other.invalid/",
    ]) await assert.rejects(request(url, { method: "POST" }));
  }
  await assert.rejects(requestFor("fixture", "--prepare")("https://texttospeech.googleapis.com/v1/text:synthesize", { method: "POST" }));
});
