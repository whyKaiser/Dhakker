# Admin custom claim — manual setup

Granting this claim is a **manual step that has not been performed**. Nothing
in this repository grants it, and nothing should: it is the single control
that decides who may replace the audio a pilgrim hears.

## Why a claim, and not the Firestore role

`firestore.rules` decides admin by reading a document:

```
users/{uid}.role == 'admin'
```

`storage.rules` cannot do that. Storage security rules have no `get()` and no
`exists()` — they cannot read Firestore at all. The only identity signal
available to them is what the caller's ID token already carries. So Storage
admin is a **custom claim**, set server-side by the Firebase Admin SDK.

The two are therefore separate facts about the same person, and they can
disagree. That is a real operational consequence, not an oversight:

| account state | can edit dua text (Firestore) | can upload dua audio (Storage) |
|---|---|---|
| `role: 'admin'`, no claim | yes | **no** |
| claim only, no `role` | no | yes |
| both | yes | yes |

## What changed, and what it breaks

Before: any signed-in user could write `audio/duas/<id>.mp3`. The path is
derived from the supplication document id, and those ids are readable by
every signed-in user — so any pilgrim could overwrite the audio of any dua
with any other audio.

Now: only an account carrying `admin == true` may create, overwrite or delete
under `audio/duas/`. Reading is unchanged, so playback for pilgrims is
unaffected.

**Until the claim is granted, audio upload from the admin screens will fail
for everyone, including accounts with `role: 'admin'`.** That is the intended
fail-closed state. The rule uses strict equality against `true`, so a missing
claim, `"true"` as a string, `1`, or `false` all refuse.

## Granting it

Run this **once per admin account**, from a trusted machine, with Admin SDK
credentials. Do not commit the credentials, and do not add this to a
workflow — a pipeline that can mint admins is a pipeline that can be made to
mint one.

```js
// grant-admin.mjs — run locally, then delete. Not part of the repo.
import { initializeApp, cert } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

initializeApp({ credential: cert("<path to service account json>") });

const uid = "<the admin's Firebase Auth UID>";
await getAuth().setCustomUserClaims(uid, { admin: true });
console.log("granted");
```

Or with the Firebase CLI logged in as a project owner, using the Admin SDK
through `firebase functions:shell`, if you prefer not to handle a key file.

### After granting

1. The claim reaches the client only on a **fresh ID token**. The account
   must sign out and back in, or the app must call
   `user.getIdToken(true)` to force a refresh. Until then the old token is
   still claimless and uploads still fail.
2. Verify from the admin screen by uploading one small file, not by reading
   the claim back in code.

### Revoking

```js
await getAuth().setCustomUserClaims(uid, { admin: false });
await getAuth().revokeRefreshTokens(uid);   // existing tokens keep the old claim otherwise
```

The second line matters. A claim change does not invalidate tokens already
issued; without revoking, a removed admin keeps write access until their
current token expires (up to an hour).

## What this does not do

- It does not change who can read audio. Any signed-in user still can, because
  the app plays it to pilgrims.
- It does not grant anything in Firestore. Verification of a record still
  requires `role: 'admin'` **and** complete provenance, unchanged.
- It does not touch `supplications_legacy_archive`, which remains unreadable
  by every client including admins.

## Tests

`test_firestore_rules/storage.rules.test.mjs` exercises the complete ruleset
against the Storage emulator: anonymous refused; pilgrim refused for create,
overwrite and delete but still able to read; admin **without** the claim
refused; non-`true` claim values refused; admin with the claim allowed but
still bounded by the 15MB and `audio/*` limits; and no identity able to write
outside `audio/duas/{fileName}`, including one path segment deeper.
