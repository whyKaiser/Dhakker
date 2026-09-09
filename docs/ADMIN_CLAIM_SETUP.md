# Admin custom claim — manual setup

Granting this claim is a **manual step that has not been performed**, and
it BLOCKS content approval: `firestore.rules` refuses a `verified` write from
an account without it, so it comes before reviewing the source pack, not
after. Nothing
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

Run it **once per admin account**, from a trusted machine. Do not add this to
a workflow — a pipeline that can mint admins is a pipeline that can be made
to mint one.

### The supported way: `scripts/grant_admin_claim.mjs`, no key file

The Admin SDK needs a service-account key: a long-lived credential that can
mint admins, sitting on a laptop. This project avoids creating one everywhere
else, and the single control over who may replace a pilgrim's audio is a poor
place to start.

The tool uses the Identity Toolkit REST API with a **short-lived** OAuth
token instead — about an hour, and never written to disk by the tool.

```bash
# 1. Find the account's uid: Firebase console → Authentication → Users.
# 2. A token that expires in an hour. Needs the gcloud CLI, signed in as
#    someone with Firebase Authentication Admin on the project.
export FIREBASE_PROJECT_ID=dhakker-160d0
export GOOGLE_ACCESS_TOKEN="$(gcloud auth print-access-token)"

node scripts/grant_admin_claim.mjs --uid=<uid> --confirm=GRANT_ADMIN
```

What it will not do, asserted by `scripts/grant_admin_claim.test.mjs`:

* **One account per run**, named explicitly. There is no `--all`, no list, no
  file input. Granting admin to two accounts in one command has no
  legitimate use and a very bad failure mode.
* **No run without a confirmation matching the direction.** Confirming
  `GRANT_ADMIN` while passing `--revoke` is refused rather than resolved
  either way; a typo'd uid should cost an error, not an admin.
* **Existing claims are read and merged.** Identity Toolkit replaces the
  whole custom-attributes blob, so a naive write erases every other claim
  without a trace. There is only one claim today; the next one would have
  gone silently.
* `admin` is written as the boolean `true`, never `"true"` — `storage.rules`
  compares against the boolean, and a string would read as granted here and
  refuse there.
* A failed lookup **raises** rather than being read as "no claims", which
  would erase the real ones on the write that followed.
* The uid is printed; the token never is.

It also invalidates tokens already issued, on grant and on revoke both — see
below for why that is not optional.

### Revoking

```bash
node scripts/grant_admin_claim.mjs --uid=<uid> --revoke --confirm=REVOKE_ADMIN
```

### If you would rather use the Admin SDK

The original path still works and is not wrong — it needs a key file, which
is the only reason it is no longer the recommendation.

```js
import { initializeApp, cert } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

initializeApp({ credential: cert("<path to service account json>") });
await getAuth().setCustomUserClaims("<uid>", { admin: true });
await getAuth().revokeRefreshTokens("<uid>");
```

### After granting

1. The claim reaches the client only on a **fresh ID token**. The tool
   invalidates existing sessions, so the account must sign in again. If the
   claim was set some other way, the account must sign out and back in, or
   the app must call
   `user.getIdToken(true)` to force a refresh. Until then the old token is
   still claimless and uploads still fail.
2. Verify from the admin screen by uploading one small file, not by reading
   the claim back in code.

### Why token revocation is not optional

A claim change does not invalidate tokens already issued. Without revoking,
a removed admin keeps write access until their current token expires — up to
an hour. `grant_admin_claim.mjs` does it on both directions, and a test
asserts it for each.

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
