import assert from "node:assert/strict";
import test from "node:test";
import { requestBody, TEXT, PROMPT } from "./preview-algieba-pacing.mjs";
test("paced sample uses the chosen voice with bounded modest speed adjustment", () => {
  const body = requestBody("--chirp");
  assert.equal(body.voice.name, "ar-XA-Chirp3-HD-Algieba");
  assert.equal(body.audioConfig.speakingRate, 1.15);
  assert.deepEqual(body.input, { text: TEXT });
  assert.equal(body.audioConfig.audioEncoding, "MP3");
});
test("no special Quranic symbols or word changes are introduced in speech input", () => {
  assert.equal(TEXT.replace(/\p{M}/gu, "").replace(/[،.]/gu, ""), "ربنا آتنا في الدنيا حسنة وفي الآخرة حسنة وقنا عذاب النار");
  assert.ok(!/[\u06D6-\u06ED]/u.test(TEXT));
});
test("directed style instructions are separate from the text to speak", () => {
  const body = requestBody("--directed");
  assert.equal(body.input.prompt, PROMPT);
  assert.equal(body.input.text, TEXT);
  assert.equal(body.voice.name, "Algieba");
  assert.equal(body.voice.modelName, "gemini-2.5-flash-tts");
  assert.ok(!body.input.text.includes("Read the"));
});
test("sample tool has no publishing or unknown mode", () => {
  assert.throws(() => requestBody("--publish"));
  assert.throws(() => requestBody("--other"));
});
