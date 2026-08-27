# Import field ownership, reconciliation, and the production gate

## Why this document exists

The importer only ever wrote, and it wrote with a Firestore REST `PATCH`
carrying **no `updateMask`**. That is a full document replacement: every
field absent from the payload is deleted. With an empty collection nobody
noticed. The moment there were live documents it meant an import would

- reset `usage_count` to 0, discarding analytics the pilgrim's own client
  had incremented,
- overwrite `audioMode`/`audioUrl`, unpublishing a recording an admin had
  uploaded by hand,
- and delete outright any administrative field the script has never heard
  of.

None of that was intended, and nothing in the code said which fields the
importer was entitled to own. This document is that statement, and
`scripts/import_source_pack.mjs` asserts it at module load: a field added to
the schema without an owner throws before anything runs.

## The four classes

All 47 payload fields, classified exhaustively and without overlap.

### A — pack-owned (40 fields)

The source pack is the authority. An import may overwrite these freely;
doing so is the point of importing.

`duaId`, `contentKind`, `zoneKey`, `title`, `text`, `zoneId`, `zoneNameAr`,
`tagsAr`, `tagsEn`, `languageCodes`, `isActive`, `authority`, `sourceUrl`,
`sourceVersion`, `sourceLanguage`, `sourceSection`, `printedPage`,
`contentHash`, `contextAuthority`, `contextSourceUrl`, `ritualKey`,
`appliesToZoneKeys`, `usageQualifier`, `sourceReferences`,
`recitationPolicy`, `relatedRecordIds`, `relatedRecordRole`, `usageNoteAr`,
`sourceReferencesCompleteness`, `quranRef`, `isPortionOfAyah`,
`textAuthority`, `textAuthoritySourceUrl`, `textRiwayah`, `textRasm`,
`textEdition`, `textEditionDate`, `isGeneralSupplication`, `reviewNotes`,
`visuallyUncertain`

### B — operational (3 fields)

Owned by the running app and its admins, never by the pack. Seeded on a
**new** document; on an **existing** one they are left exactly as they are.

| field | why it must survive an import |
|---|---|
| `audioMode` | an admin chose `file` deliberately |
| `audioUrl` | a recording uploaded by hand; re-importing the text is not a reason to unpublish it |
| `usage_count` | live analytics; `firestore.rules` permits a signed-in pilgrim to increment exactly this field |

### C — verification (4 fields)

Always written, on create **and** on update, always to the unverified state:
`verificationStatus`, `verifiedAt`, `verifiedBy`, `revokedAt`.

This is a reset, not a preservation, and it is deliberate. Re-importing
content means the bytes a human approved may no longer be the bytes stored,
so the record must drop out of the pilgrim's view until someone approves it
again. Both `firestore.rules` and the app's own queries require
`verificationStatus == 'verified'`, so the record becomes invisible the
instant the import lands — which is the safe direction to fail.

### D — unknown administrative fields

Not listed, because they cannot be. Anything the admin console or a future
migration adds lives here. They are protected **structurally**, by never
appearing in the `updateMask`, rather than by enumeration — a list would be
wrong the moment someone adds a field.

## What the importer sends

| | create (document absent) | update (document exists) |
|---|---|---|
| body | all 47 fields | A ∪ C only (44) |
| `updateMask.fieldPaths` | absent | A ∪ C (44) |
| B | seeded (`tts`, `""`, `0`) | absent from body and mask → **preserved** |
| D | n/a | absent from mask → **preserved** |

Existence is **read, not guessed**: a `GET` precedes every `PATCH`, and only
a real 404 licenses a create. Any other failure aborts rather than writing
blind.

### The null trap

A field named in the mask but **missing from the body** is *deleted* by
Firestore. That would leave a document with no `verifiedAt` key at all —
different from `verifiedAt: null`, and enough to make `hasCompleteProvenance`
behave unpredictably. So the verification fields are serialised as
`nullValue` and included in the mask, which sets them to null while keeping
them present. A test asserts both the value and the key's existence.

## Reconciliation (`--reconcile`)

A hold stops the *next* write; it does not retract the last one. A record
imported and verified months ago, since blocked or dropped from the pack,
stays live in front of pilgrims — and no dry-run, log or test said so,
because they all reason about the pack and the ledger while the live
collection is never read.

`--reconcile` reads. It is refused in combination with `--write`, and there
is no flag in the file that can make it delete or revoke anything.

| case | meaning |
|---|---|
| `expected_and_present` | cleared by the ledger, live, text matches |
| `expected_missing` | cleared but not live — writing is what fixes it |
| `present_but_excluded` | **live but held back by the ledger** |
| `present_but_removed_from_pack` | **live but the pack no longer contains it** |
| `text_changed` | live, but the stored text hash differs from the pack |

The two bold cases fail the production preflight. Neither can be corrected
by writing, so the run stops and a human decides what to retract. Findings
report `documentId`, the case, the verification status and the hold's
reason — never a field value, so a signed `audioUrl` cannot reach a log.

## Post-write verification

A `200` proves the request was accepted, not that the document holds what was
meant. After writing, each record is read back through the same credential
and compared: `duaId`, `contentKind`, the four verification fields, and the
text by **hash** rather than by printing it. A mismatch names the field and
fails the run.

This happens server-side, through the importer's credential.
`supplications_staging` stays closed to every client
(`allow read, write: if false`), and the app has not been taught to read it.

## Proposed production workflow — design only, not created

No production workflow exists, and this PR does not add one. The design it
would have to satisfy:

1. `workflow_dispatch` only, refused from any ref except `main`.
2. Its **own** protected GitHub Environment, `firebase-production`, separate
   from `firebase-staging`, with its own required reviewers.
3. Four typed confirmations — project, database, collection, count — each
   compared to its exact expected value before any credential is minted.
4. `--reconcile --production` first. Any `present_but_excluded` or
   `present_but_removed_from_pack` **fails the run**.
5. A dry run, whose printed count must equal the typed `confirm_count`.
6. Human approval on the environment.
7. The write, then read-back verification of every record.
8. `--limit` remains refused against production.

The staging workflow must never gain a collection input: `--staging` maps to
`supplications_staging` in code, and no operator string can reach the
collection name.

## Known gaps this does not close

- **Retraction is still manual.** Reconciliation reports; it does not revoke.
  Setting `revokedAt` on a stale document is a human decision and belongs in
  its own change.
- **The app does not enforce holds.** Nothing in `lib/` reads the ledger; a
  hold is enforced at import time only. `verificationStatus` remains the sole
  barrier between a live document and a pilgrim.
- **There is no audit trail** for verification beyond `verifiedBy` and
  `verifiedAt` on the document, both of which any later edit overwrites.
