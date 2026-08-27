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

All fields the importer produces, classified exhaustively and without
overlap. Asserted at module load, so a schema field added without an owner
throws before anything runs.

### A — pack-owned (39)

The pack is the authority; an import may overwrite these freely. **A change
to any of them is what drops verification.**

`duaId`, `contentKind`, `zoneKey`, `title`, `text`, `zoneId`, `zoneNameAr`, `tagsAr`, `tagsEn`, `languageCodes`, `authority`, `sourceUrl`, `sourceVersion`, `sourceLanguage`, `sourceSection`, `printedPage`, `contentHash`, `contextAuthority`, `contextSourceUrl`, `ritualKey`, `appliesToZoneKeys`, `usageQualifier`, `sourceReferences`, `recitationPolicy`, `relatedRecordIds`, `relatedRecordRole`, `usageNoteAr`, `sourceReferencesCompleteness`, `quranRef`, `isPortionOfAyah`, `textAuthority`, `textAuthoritySourceUrl`, `textRiwayah`, `textRasm`, `textEdition`, `textEditionDate`, `isGeneralSupplication`, `reviewNotes`, `visuallyUncertain`

### Create-only defaults (7)

Seeded on a **new** document; on an existing one they appear in neither the
body nor the `updateMask`, so whatever is there survives. Each is a live
decision the pack cannot know.

| field | seeded | why the pack may not overwrite it |
|---|---|---|
| `audioMode` | `"tts"` | an admin chose `file` deliberately |
| `audioUrl` | `""` | a recording uploaded by hand; re-importing text is no reason to unpublish it |
| `usage_count` | `0` | analytics the pilgrim's client increments — `firestore.rules` permits exactly this field |
| `isActive` | `true` | the admin's show/hide switch. An import must not republish a record they hid |
| `revokedAt` | `null` | the admin's retraction. The importer drops verification out of respect for the human who granted it; un-revoking would override the human who withdrew it |
| `createdAt` | now, `timestampValue` | — |
| `updatedAt` | now, `timestampValue` | the admin console orders its list by `updatedAt`, and Firestore's `orderBy` **excludes documents lacking the field**. Without it an imported record is invisible in the one screen where it can be verified. On update the console owns it |

`isActive` moved here out of A, and `revokedAt` out of the verification
class. Both were being overwritten by an import — the same class of fault as
`usage_count`, and for `revokedAt` a safety decision silently undone.

### Verification-reset (3)

`verificationStatus`, `verifiedAt`, `verifiedBy`.

Written **only when a pack-owned field actually changed**, always to the
unverified state. `revokedAt` is deliberately not among them.

### D — unknown administrative fields

Not listed, because they cannot be. Protected structurally by never
appearing in the `updateMask`; a list would be wrong the moment someone adds
a field.

## When verification drops, and when it is kept

| situation | write | verification |
|---|---|---|
| document absent | create, all fields + the 7 defaults | starts `unverified` |
| every pack field identical | **no PATCH at all** | **kept** — a record a human approved stays approved |
| any pack field changed | PATCH, mask = A ∪ the 3 reset fields (42 paths) | dropped to `unverified`, stamps nulled |

Comparison is canonical, not `contentHash` alone: map key order is
irrelevant (Firestore returns fields unordered), numbers compare numerically
whatever the wire type, null and absent are the same, and strings compare
NFC-normalised so a pure normalisation difference is not read as an edit.
**Array order stays significant** — `sourceReferences` and `ayat` are
sequences the page prints in an order, not sets.

### First import versus an identical re-import

- **First import**: 73 documents created, every one `unverified`. All 73 need
  a human approval, one at a time — there is no batch path, and this change
  does not add one.
- **Identical re-import**: zero writes, zero approvals withdrawn. Before this
  change every re-import reset all 73 and left the app with no supplications
  in front of pilgrims until each was re-approved.
- **Re-import after editing one record**: one write, one approval withdrawn.

## What the importer sends

| | create | update (content changed) | update (identical) |
|---|---|---|---|
| body | all pack fields + 7 defaults | A ∪ reset (42) | — |
| `updateMask.fieldPaths` | absent | the same 42 paths | — |
| create-only defaults | seeded | absent → preserved | — |
| unknown admin fields | n/a | absent → preserved | — |

Existence is **read, not guessed**: a `GET` precedes every `PATCH`, only a
real 404 licenses a create, and 401/403/429/5xx abort rather than write
blind.

### The null trap

A field named in the mask but **missing from the body** is *deleted* by
Firestore — leaving a document with no `verifiedAt` key at all, rather than
one explicitly null. So the reset fields are serialised as `nullValue` and
included in the mask. A test asserts the value **and** the key's existence.

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
meant. Each record is read back through the same credential.

**On create** — `duaId`, `contentKind`, the text by NFC-normalised hash, and
every one of `audioMode: "tts"`, `audioUrl: ""`, `usage_count: 0`,
`isActive: true`, `revokedAt: null`, `verificationStatus: "unverified"`,
`verifiedAt: null`, `verifiedBy: null`, plus `createdAt` and `updatedAt`
present and parseable as timestamps.

**On update** — the new pack values; that every create-only default and every
unknown admin field still equals what it was *before* the write; and, only if
content changed, that verification really did drop.

No value is ever printed. Text is compared by hash, and a mismatch names the
field and nothing else, so neither a signed `audioUrl` nor a full record text
can reach a log.

Verification happens server-side through the importer's credential.
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
