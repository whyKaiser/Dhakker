import assert from "node:assert/strict";
import test from "node:test";
import { assertRequestAllowed, validateSample, SAMPLES, COMPARISON_VOICES, ALTERNATIVE_VOICES, runPreview } from "./preview-dua-audio.mjs";

const sample = { verificationStatus: "verified", isActive: true, revokedAt: null,
  contentKind: "general_dua", audioUrl: "", text: { ar: "يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَىٰ دِينِكَ" } };
test("preview preserves the approved Arabic text exactly", () => {
  assert.equal(validateSample(sample, SAMPLES[0].id), sample.text.ar);
});
for (const patch of [{ verificationStatus: "pending" }, { isActive: false },
  { revokedAt: "2026-09-10" }, { deploymentBlocked: true },
  { excludedFromImport: true }, { reviewStatus: "blocked" },
  { contentKind: "procedural_guidance" }, { audioUrl: "existing.mp3" }]) {
  test(`preview rejects ${JSON.stringify(patch)}`, () => {
    assert.throws(() => validateSample({ ...sample, ...patch }, SAMPLES[0].id));
  });
}
test("preview cannot write production or upload audio, even in generation mode", () => {
  for (const url of [
    "https://firestore.googleapis.com/v1/projects/dhakker-160d0/databases/(default)/documents/supplications/" + SAMPLES[0].id,
    "https://storage.googleapis.com/upload/storage/v1/b/bucket/o",
  ]) {
    for (const method of ["POST", "PUT", "PATCH", "DELETE"]) {
      assert.throws(() => assertRequestAllowed(url, method, true));
    }
  }
});
test("synthesis requires explicit generation mode", () => {
  const url = "https://texttospeech.googleapis.com/v1/text:synthesize";
  assert.throws(() => assertRequestAllowed(url, "POST", false));
  assert.doesNotThrow(() => assertRequestAllowed(url, "POST", true));
});
test("byte limit accounts for multibyte Arabic", () => {
  assert.throws(() => validateSample({ ...sample, text: { ar: "ع".repeat(2600) } }, SAMPLES[0].id));
});

function fakeFetch({ omitVoice = false, names = COMPARISON_VOICES } = {}) {
  const calls = [];
  return { calls, fetch: async (url, options) => {
    calls.push({ url, method: options.method ?? "GET" });
    if (url.includes("/voices?")) return Response.json({ voices:
      names.filter((_, i) => !omitVoice || i > 0).map(name => ({
        name: `ar-XA-Chirp3-HD-${name}`, languageCodes: ["ar-XA"],
      })),
    });
    return Response.json({ fields: {
      verificationStatus: { stringValue: "verified" },
      isActive: { booleanValue: true },
      revokedAt: { nullValue: null },
      contentKind: { stringValue: "general_dhikr" },
      text: { mapValue: { fields: { ar: { stringValue: sample.text.ar } } } },
    } });
  } };
}

test("comparison dry-run plans three voices with one source read and no synthesis", async () => {
  const deps = fakeFetch();
  const manifest = await runPreview({ token: "test-only", compare: true }, deps);
  assert.equal(manifest.samples.length, 3);
  assert.equal(manifest.voices.length, 3);
  assert.equal(new Set(manifest.samples.map(s => s.textSha256)).size, 1);
  assert.equal(new Set(manifest.samples.map(s => s.file)).size, 3);
  assert.equal(manifest.characters, [...sample.text.ar].length * 3);
  assert.equal(manifest.published, false);
  assert.equal(manifest.listeningReviewPassed, false);
  assert.equal(deps.calls.length, 2);
  assert.ok(deps.calls.every(c => c.method === "GET"));
});

test("comparison refuses a missing voice instead of falling back to Charon", async () => {
  const deps = fakeFetch({ omitVoice: true });
  await assert.rejects(runPreview({ token: "test-only", compare: true }, deps), /unavailable/);
  assert.equal(deps.calls.length, 1);
});

test("further comparison plans two alternatives without regenerating Algenib", async () => {
  const deps = fakeFetch({ names: ALTERNATIVE_VOICES });
  const manifest = await runPreview({ token: "test-only", more: true }, deps);
  assert.equal(manifest.samples.length, 2);
  assert.deepEqual(manifest.voices, ALTERNATIVE_VOICES.map(name => `ar-XA-Chirp3-HD-${name}`));
  assert.equal(manifest.characters, [...sample.text.ar].length * 2);
  assert.equal(new Set(manifest.samples.map(s => s.textSha256)).size, 1);
  assert.equal(deps.calls.length, 2);
  assert.ok(deps.calls.every(c => c.method === "GET"));
});

test("conflicting comparison flags make no requests", async () => {
  const deps = fakeFetch();
  await assert.rejects(runPreview({ token: "test-only", compare: true, more: true }, deps), /one comparison/);
  assert.equal(deps.calls.length, 0);
});
