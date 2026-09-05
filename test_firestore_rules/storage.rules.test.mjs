// Behavioural tests for storage.rules against the Storage emulator.
//
// These exist because the previous rule let ANY signed-in user write to
// `audio/duas/<id>.mp3`. The path is derived from the supplication document
// id, and those ids are readable by every signed-in user, so the target was
// both known and overwritable: a pilgrim could replace the audio of a dua
// with any other audio. Every provenance control in firestore.rules guards
// the TEXT; this closes the same door on the SOUND.
//
// As with the Firestore suite, the guarantee is behavioural, not textual.
// Firestore/Storage rules combine with OR semantics, so a comment or an
// `if false` block proves nothing — only exercising the complete ruleset
// against the emulator does.

import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {
  ref,
  uploadBytes,
  getBytes,
  deleteObject,
} from "firebase/storage";

const here = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(here, "..", "storage.rules"), "utf8");

const ADMIN_UID = "admin-user";
const PILGRIM_UID = "pilgrim-user";

const AUDIO = "audio/duas/dua-1.mp3";
const MP3 = { contentType: "audio/mpeg" };

/** A small valid payload. Content is irrelevant to the rules; size is not. */
const bytes = (n = 32) => new Uint8Array(n).fill(1);

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "dhakker-rules-test",
    storage: {
      rules,
      host: "127.0.0.1",
      port: 9199,
    },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearStorage();
});

/// An admin is ONLY someone carrying the custom claim. Note this deliberately
/// differs from firestore.rules, where admin is a `users/{uid}.role` document
/// read — Storage rules cannot read Firestore at all, so the claim is the
/// only signal available here.
const adminStorage = () =>
  testEnv.authenticatedContext(ADMIN_UID, { admin: true }).storage();

/// A user with role 'admin' in Firestore but NO claim. This is what every
/// current admin account looks like until the claim is granted by hand.
const adminWithoutClaim = () =>
  testEnv.authenticatedContext(ADMIN_UID).storage();

const pilgrimStorage = () =>
  testEnv.authenticatedContext(PILGRIM_UID).storage();

const anonStorage = () => testEnv.unauthenticatedContext().storage();

/** Puts a file in place bypassing rules, so overwrite/delete can be tested. */
async function seedAudio(p = AUDIO) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), p), bytes(), MP3);
  });
}

// ── Unauthenticated ──────────────────────────────────────────────────────

test("an unauthenticated user cannot create dua audio", async () => {
  await assertFails(uploadBytes(ref(anonStorage(), AUDIO), bytes(), MP3));
});

test("an unauthenticated user cannot overwrite, delete or read dua audio", async () => {
  await seedAudio();
  await assertFails(uploadBytes(ref(anonStorage(), AUDIO), bytes(64), MP3));
  await assertFails(deleteObject(ref(anonStorage(), AUDIO)));
  await assertFails(getBytes(ref(anonStorage(), AUDIO)));
});

// ── Ordinary signed-in pilgrim: the hole this closes ─────────────────────

test("a signed-in pilgrim cannot CREATE dua audio", async () => {
  await assertFails(uploadBytes(ref(pilgrimStorage(), AUDIO), bytes(), MP3));
});

test("a signed-in pilgrim cannot OVERWRITE existing dua audio", async () => {
  // The regression that matters most: replacing the sound of a dua.
  await seedAudio();
  await assertFails(uploadBytes(ref(pilgrimStorage(), AUDIO), bytes(64), MP3));
});

test("a signed-in pilgrim cannot DELETE dua audio", async () => {
  await seedAudio();
  await assertFails(deleteObject(ref(pilgrimStorage(), AUDIO)));
});

test("a pilgrim can still READ dua audio — playback is unchanged", async () => {
  await seedAudio();
  await assertSucceeds(getBytes(ref(pilgrimStorage(), AUDIO)));
});

// ── Fail closed without the claim ────────────────────────────────────────

test("an admin WITHOUT the custom claim is refused — fail closed", async () => {
  // A Firestore `role == 'admin'` document grants nothing here: Storage
  // rules cannot read Firestore. Until the claim is granted by hand, this
  // account writes nothing. That is the intended operational consequence.
  await seedAudio();
  await assertFails(uploadBytes(ref(adminWithoutClaim(), AUDIO), bytes(), MP3));
  await assertFails(deleteObject(ref(adminWithoutClaim(), AUDIO)));
});

test("a non-true claim value does not pass — strict equality", async () => {
  for (const claim of [{ admin: "true" }, { admin: 1 }, { admin: false }, {}]) {
    const ctx = testEnv.authenticatedContext("claimy", claim).storage();
    await assertFails(
      uploadBytes(ref(ctx, AUDIO), bytes(), MP3),
      `claim ${JSON.stringify(claim)} was accepted`,
    );
  }
});

// ── Admin with the claim: allowed, but only within the limits ────────────

test("an admin with the claim can create dua audio", async () => {
  await assertSucceeds(uploadBytes(ref(adminStorage(), AUDIO), bytes(), MP3));
});

test("an admin with the claim can overwrite and delete dua audio", async () => {
  await seedAudio();
  await assertSucceeds(uploadBytes(ref(adminStorage(), AUDIO), bytes(64), MP3));
  await assertSucceeds(deleteObject(ref(adminStorage(), AUDIO)));
});

test("an admin cannot upload a non-audio content type", async () => {
  for (const contentType of ["text/html", "application/octet-stream", "image/png"]) {
    await assertFails(
      uploadBytes(ref(adminStorage(), AUDIO), bytes(), { contentType }),
      `${contentType} was accepted`,
    );
  }
});

test("an admin cannot upload a file at or over the 15MB cap", async () => {
  const tooBig = new Uint8Array(15 * 1024 * 1024);
  await assertFails(uploadBytes(ref(adminStorage(), AUDIO), tooBig, MP3));
});

// ── Nothing outside the audio path is writable, by anyone ────────────────

test("no identity can write outside audio/duas — including admin", async () => {
  const outside = [
    "audio/other.mp3",
    "audio/duas",
    "audio/duas/nested/deep.mp3", // {fileName} is ONE segment; this is not it
    "uploads/evil.mp3",
    "profile/pic.png",
    "firestore-backup.json",
  ];
  for (const p of outside) {
    for (const [who, st] of [
      ["admin", adminStorage()],
      ["pilgrim", pilgrimStorage()],
      ["anonymous", anonStorage()],
    ]) {
      await assertFails(
        uploadBytes(ref(st, p), bytes(), MP3),
        `${who} could write ${p}`,
      );
    }
  }
});

test("a deep path under audio/duas is not covered by the audio rule", async () => {
  // Confirms the single-segment match: the admin allowance does not leak
  // down a subdirectory an attacker could pick.
  await assertFails(
    uploadBytes(ref(adminStorage(), "audio/duas/a/b.mp3"), bytes(), MP3),
  );
});
