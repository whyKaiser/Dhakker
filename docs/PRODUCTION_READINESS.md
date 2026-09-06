# Production readiness

State of the project on `main` as of the merge of #36 — the last of the
group-privacy (#33), stored-data-typing (#34), rate-limiter (#35) and
documentation (#36) changes — and what still has to happen
before a pilgrim can usefully open the app. Nothing in this document has been
executed; every numbered step below is a manual, human decision.

## Where production stands today

**The 16 legacy records are gone from `supplications`, and they were archived
first.** Sequence, all verified from the run logs:

1. Read-only reconciliation found 16 documents in `supplications` that nothing
   in the source pack accounted for — `expected_and_present: 0`,
   `expected_missing: 73`, `present_but_removed_from_pack: 16`.
2. Archive phase copied all 16 into `supplications_legacy_archive` and read
   every copy back, field for field. `16 document(s) archived and verified.`
3. Delete dry run re-verified all 16 against their copies and listed what it
   would remove. Nothing was written.
4. Delete phase re-verified every copy again, then deleted the 16 originals.
   `16 document(s) deleted from supplications.`
5. A final read-only reconciliation reported `present_but_removed_from_pack: 0`
   and `present_but_excluded: 0`, exiting 0.

**The archive is intact and unreadable by clients.** Every retired document is
in `supplications_legacy_archive` in full, including its `audioUrl`, so a
record can be reconstructed. `firestore.rules` denies that collection to every
client — pilgrim, admin and unauthenticated alike — because it holds exactly
the text that was judged unfit to publish. Emulator tests assert this at five
path shapes for every identity.

**No audio file was touched.** The retirement path never contacts Cloud
Storage: the service account it ran as held no `roles/storage.*` binding, so
the objects were unreachable by the credential rather than merely
un-referenced by the code. Every run printed, and the workflow asserted,
`Storage:   NOT CONTACTED`.

**The retirement machinery has been dismantled.** After the final
reconciliation, the `dhakker-legacy-retirement` service account and the
`firebase-legacy-retirement` GitHub environment were both deleted. Nothing
now holds a standing credential that can delete production documents, and
`.github/workflows/legacy-retirement.yml` cannot run: it fails its own
configuration gate with no environment and no service-account variable.

That is the intended end state, not an omission. Should the workflow ever be
needed again, `docs/LEGACY_RETIREMENT_SETUP.md` describes recreating both from
scratch — deliberately, so that re-arming it is a conscious act rather than
something left switched on.

## The 73 records are not in production — and that is not a failure

The source pack holds 85 entries; the review ledger clears 73 of them for
import. **None has ever been written to production.** That is a separate
operational decision that has not been taken, not a gap left by the
retirement. The reconciliation reporting `expected_missing: 73` is that fact
being stated, not an error condition — it is why a reconciliation exits
non-zero only on `present_but_excluded` and `present_but_removed_from_pack`.

Consequence to be clear-eyed about: `supplications` currently serves **no**
records to pilgrims. The read rule requires
`isActive == true && verificationStatus == 'verified' && revokedAt == null`,
and there are no verified records anywhere — in production or in the
repository. The app handles this without crashing (`_EmptyDuasState`), but an
empty dua list is not a launchable product.

## Before launch

In order. Each is manual.

**1 · Deploy and verify the composite Firestore indexes.**
`firestore.indexes.json` declares 8. Without them the assistant's retrieval
query fails, and it degrades *silently* to "no approved source" — safe, but
invisible. Deploy with `firebase deploy --only firestore:indexes`, then
confirm each index reports Enabled in the console before relying on it.

**2 · Build a production import path with its own least-privilege identity.**
The existing production workflow is read-only by construction and must stay
that way. A production import needs a separate service account, its own
protected environment, its own confirmations, and the same
archive-before-change discipline the retirement used. Do not widen the
reconcile reader's role to do this.

**3 · Import the cleared records as `unverified`.**
Every record enters production unverified. The importer already refuses to
invent provenance, and `firestore.rules` refuses to accept
`verificationStatus: 'verified'` without complete provenance fields.

**4 · Review and approve content by hand, record by record.**
Each record is matched against the published official source and approved
individually. **There is no bulk approval, and none should be added.** A
record becomes visible to pilgrims only once a human has verified that
specific text against that specific source.

**5 · Configure the Worker and deploy for real.**
`ENVIRONMENT=production`, `FIREBASE_PROJECT_ID`, `ALLOWED_ORIGINS`, and the
provider keys as Cloudflare secrets. A missing `FIREBASE_PROJECT_ID` makes
the Worker refuse every request with `503` rather than skip token validation —
verify that it is set rather than assuming. Then deploy rules, indexes,
hosting and the Worker.

## Also outstanding

- **Grant the admin custom claim.** Audio upload is now admin-only via a
  custom claim and fails closed without it, so no account can upload audio
  until this is done — including accounts with `role: 'admin'` in Firestore.
  See `docs/ADMIN_CLAIM_SETUP.md`.
- **Web boot still depends on `gstatic.com`** for the Firebase JS SDK. The app
  now shows a bilingual failure screen with a retry instead of a blank page,
  but it still cannot start on a network that blocks that host. See
  `docs/WEB_BOOT.md`.
- **Create pointer documents for any pre-existing family group** before
  deploying the rules that close the group-location leak. Ordering matters
  and the check is one query; if `groups` is empty — expected while the app
  is unlaunched — there is nothing to do. See
  `docs/GROUP_PRIVACY_MIGRATION.md`.

## Known limits that are recorded, not fixed

- **Family group join codes are four digits** (`HAJJ-1000`..`HAJJ-9999`).
  They can no longer be enumerated, but 9000 is small enough to brute-force
  at roughly one Firestore read per attempt; only quota stands in the way. A
  longer code or an attempt limit is the real answer, and it is a deliberate
  decision rather than something to change quietly. See
  `docs/GROUP_PRIVACY_MIGRATION.md`.
- **Dependency advisories are dev-only.** `npm audit --omit=dev` reports zero
  at the repository root. The outstanding advisories are all transitive
  devDependencies of `firebase-tools` and `eslint` — emulator and lint
  tooling that never ships to a pilgrim or runs in the Worker. They are not
  force-upgraded, because the emulator versions in
  `test_firestore_rules/package.json` are pinned as a mutually compatible
  set.

## What has never been verified

- The app running against live Firebase — every check to date is unit tests,
  emulator tests, or offline boot checks.
- Tawaf/Sa'i counting accuracy, battery behaviour, and GPS in the field.
- Any Cloudflare Worker deployment configuration.
