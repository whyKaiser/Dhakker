# Legacy retirement — manual setup and operating procedure

This is the only operation in the repository that deletes production data.
Read it in full before dispatching either phase.

## What is being retired, and why

The production reconciliation of 2026-08-28 reported:

| case | count |
|---|---|
| `expected_and_present` | 0 |
| `expected_missing` | 73 |
| `present_but_removed_from_pack` | **16** |

Production and the source pack do not overlap at all. None of the 73
ledger-cleared records has ever been imported, and all 16 live documents
predate the pack. All 16 were reported `verification=unset` and
`contentKind=unset`, all with `audioMode=file` and `audioUrl=present`.

They cannot be corrected by importing: writing more records never retracts
one already live. They are removed, not fixed — and removed reversibly.

## What is NOT being touched

**The audio files.** Every archived document keeps its `audioUrl` string in
full, so a record can be reconstructed later, but no object in Cloud Storage
is read, moved or deleted. That is enforced by IAM, not by the code: the
service account below holds no `roles/storage.*` binding of any kind, so the
objects are unreachable by the credential the job holds.

**Every other collection.** `users`, `zones`, `alerts`, `sos_requests`,
`knowledge_*` and the rest are never addressed. Note the standing caveat:
`roles/datastore.user` is project-wide because Firestore IAM has no
per-collection scope, so the credential *could* reach them. What stops it is
the manifest allowlist and the tool's fixed collection constants — and the
fact that the account exists only for the duration of this operation.

**Any document not in the manifest.** Including the 73 records the ledger
cleared, none of which is in production anyway.

---

## A. Google Cloud Console — one temporary service account

Create it, use it, then remove it. It should not outlive the operation.

**1. Create the account**

```bash
gcloud iam service-accounts create dhakker-legacy-retirement \
  --project=dhakker-160d0 \
  --display-name="Dhakker legacy retirement (temporary)"
```

**2. Grant exactly one role**

```bash
gcloud projects add-iam-policy-binding dhakker-160d0 \
  --member="serviceAccount:dhakker-legacy-retirement@dhakker-160d0.iam.gserviceaccount.com" \
  --role="roles/datastore.user"
```

`roles/datastore.user` is the narrowest role that can create and delete
Firestore documents. Firestore offers no delete-only role and no
per-collection role; this is the floor, not a preference.

**Grant nothing else.** In particular:

| role | why not |
|---|---|
| `roles/storage.*` | the audio files must stay out of reach — this is the whole Storage guarantee |
| `roles/datastore.owner` | adds index and database administration, neither of which is needed |
| `roles/editor`, `roles/owner` | project-wide across every service |

**3. Bind the GitHub principal**

```bash
gcloud iam service-accounts add-iam-policy-binding \
  dhakker-legacy-retirement@dhakker-160d0.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/435128982475/locations/global/workloadIdentityPools/github-pool/attribute.repository/whyKaiser/Dhakker"
```

The existing provider's attribute condition already confines this to `main`:

```
assertion.repository_owner == 'whyKaiser' &&
assertion.repository == 'whyKaiser/Dhakker' &&
assertion.ref == 'refs/heads/main'
```

No JSON key is created, downloaded or stored anywhere.

**4. After the retirement is complete — remove the account**

```bash
gcloud projects remove-iam-policy-binding dhakker-160d0 \
  --member="serviceAccount:dhakker-legacy-retirement@dhakker-160d0.iam.gserviceaccount.com" \
  --role="roles/datastore.user"

gcloud iam service-accounts delete \
  dhakker-legacy-retirement@dhakker-160d0.iam.gserviceaccount.com \
  --project=dhakker-160d0
```

A standing identity that can delete production documents is a liability with
no remaining purpose. Delete it the same day.

---

## B. GitHub Settings

**Settings → Environments → New environment → `firebase-legacy-retirement`**

1. **Required reviewers** → yourself. The job pauses until approved, and the
   approval is requested again for the delete phase.
2. **Deployment branches** → *Selected branches* → `main`.
3. **Environment variables** → Add variable:

   | name | value |
   |---|---|
   | `FIREBASE_RETIREMENT_SERVICE_ACCOUNT` | `dhakker-legacy-retirement@dhakker-160d0.iam.gserviceaccount.com` |

   `FIREBASE_PROJECT_ID`, `FIREBASE_DATABASE_ID` and
   `GCP_WORKLOAD_IDENTITY_PROVIDER` are reused from the existing setup.

This must be a **different** environment from `firebase-production-readonly`.
Approval to read production is not approval to delete from it, and the
workflow refuses to run if the retirement account and the read-only reconcile
account are the same value.

---

## C. The manifest — already filled in

`review/legacy_retirement_manifest.json` now holds the 16 ids transcribed
from the `present_but_removed_from_pack` rows of the reconciliation report,
with `status: "ready"`:

```
AdFPibtyp2hgUSiTGTlM   KrtoO8fVJ7efRTfm4qEL   kry2IEcopLzT8Cqb2eYx
D_MAQAM_01             VJb72ru1SIxmT8HKRDMW   mtKhdmU0JtS4fQ0IxgPR
D_MARWAH_01            fXwYcLDK3jLELDWb7XFb   shQFcZYJ1FjvrSbCnqkp
D_SAFA_01              fah8Mp6J6iL0QpKKMQzB   tqYFWXC1CISbU4Ey1m7C
D_TAWAF_01             i8MeSW37qmpxOOsQ6OKn   vCw2sYNEtILJkpp7ljti
                                              wVAQ2mYygE0kDT4BH1rx
```

Five carry semantic names and eleven are Firestore auto-ids. Both shapes are
stored verbatim including case — Firestore ids are case-sensitive.

This list is the only thing standing between the tool and the production
collection, so it is restated independently in
`scripts/retire_legacy_records.test.mjs` and compared byte for byte. If the
two ever drift, one of them was edited without the other being looked at,
and the suite fails.

**If the ids ever need changing**, edit them here in their own pull request
so the exact list is reviewable as a diff, and update the copy in the test
in the same change. `expectedCount` and the length of `documentIds` must
agree; the loader refuses a manifest whose own two counts disagree, which is
what catches a half-finished paste. Setting `status` back to anything other
than the literal `"ready"` returns the tool to refusing every phase,
dry-run included.

---

## D. Operating procedure

Run these four dispatches in order, reading the summary of each before
starting the next. Every one requires environment approval.

| # | phase | execute | what it does |
|---|---|---|---|
| 1 | `archive` | **false** | lists what it would copy. Writes nothing. |
| 2 | `archive` | true | copies all 16, then reads every copy back and compares it to the original. Deletes nothing. |
| 3 | `delete` | **false** | re-verifies all 16 copies and lists what it would delete. Deletes nothing. |
| 4 | `delete` | true | deletes the 16 originals — after re-verifying every copy again. |

Confirmations required each time: `dhakker-160d0`, `supplications`, `16`,
`RETIRE_LEGACY_RECORDS`.

**If any run fails, stop.** Do not re-dispatch to "get past" it. Every
failure mode in the tool aborts before deleting anything:

- an id in the manifest that is not in the collection
- an archive copy missing, or present but not matching
- a read that fails with anything other than 404

Each means the manifest and the collection disagree, and the answer is a
fresh reconciliation, not a retry.

## E. After

The archive is denied to every client — pilgrim, admin and unauthenticated
alike — by `firestore.rules`, and the emulator tests assert that against the
complete ruleset. It holds exactly the text judged unfit to publish, so it
must never be reachable from the app.

Restoring a record, if it ever happens, goes back through the normal write
path with full provenance. It is not an edit in place in the archive.

Then delete the service account (section A step 4).
