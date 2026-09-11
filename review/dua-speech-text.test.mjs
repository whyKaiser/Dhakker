import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import { deriveSpeechText, SPECIAL_SPEECH_MARKS } from "./dua-speech-text.mjs";
const original = JSON.parse(readFileSync(new URL("fixtures/algieba-original-records.json", import.meta.url)));

test("reported Baqarah 201 example uses official spelling without reading mark names", () => {
  const r = original.records.find(r => r.id.endsWith("general-001"));
  const result = deriveSpeechText(r.id, r.text);
  assert.equal(result.speechText, "ربنا آتنا في الدنيا حسنة وفي الآخرة حسنة وقنا عذاب النار");
  assert.equal(result.source.wordCount, 11);
});
test("all 53 sources stay unchanged, and every special symbol is resolved", () => {
  const before = JSON.stringify(original);
  const results = original.records.map(r => deriveSpeechText(r.id, r.text));
  assert.equal(results.filter(r => r.strategy === "official-emlaey-aligned").length, 22);
  assert.equal(results.filter(r => r.strategy === "redundant-dagger-alif").length, 9);
  assert.equal(results.filter(r => r.strategy === "unchanged").length, 22);
  assert.ok(results.every(r => !SPECIAL_SPEECH_MARKS.test(r.speechText)));
  assert.equal(JSON.stringify(original), before);
});
test("word spelling is preserved where simply dropping marks would corrupt it", () => {
  const r = original.records.find(r => r.id.endsWith("general-011"));
  const result = deriveSpeechText(r.id, r.text);
  assert.ok(result.speechText.includes("الصلاة"));
  assert.ok(result.speechText.includes("ولوالدي"));
  assert.ok(!result.speechText.includes("الصلوة"));
  assert.ok(result.speechText.includes("،"));
});
test("unrelated or edited Quranic text is rejected instead of guessed", () => {
  const r = original.records.find(r => r.id.endsWith("general-001"));
  assert.throws(() => deriveSpeechText(r.id, r.text + " كلمة"));
  assert.throws(() => deriveSpeechText("unknown", "هَٰذَا"));
});
test("approved talbiyah and ordinary Arabic diacritics are not stripped", () => {
  const r = original.records.find(r => r.id.endsWith("umrah-talbiyah"));
  assert.equal(deriveSpeechText(r.id, r.text).speechText, r.text);
});
