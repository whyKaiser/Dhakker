# Production reconcile — manual setup

`.github/workflows/production-reconcile.yml` reads the production
`supplications` collection and reports how it differs from the source pack
and the review ledger. It is dispatched by hand, from `main`, behind a
protected environment, and it writes nothing.

**Nothing in this document has been executed.** Every step below is yours to
perform in the Google Cloud Console and in GitHub Settings. The workflow will
fail its configuration gate with a clear message until they are done.

## Why this workflow needs its own identity

The staging import already has a service account, and reusing it would be the
obvious shortcut. It holds `roles/datastore.user` — **read and write**,
project-wide, on every collection. Handing that token to a job whose entire
claim is "I can only read" would make the claim depend on the job's own good
behaviour.

`roles/datastore.viewer` has no write permission at all. With it, a `PATCH`
is refused by Google before it reaches a document. That is the difference
between a workflow that *does not* write and one that *cannot*.

The workflow refuses to run if the reader variable is set to the staging
account, so the two cannot be conflated by accident.

---

## 1. Create the read-only service account

Google Cloud Console → **IAM & Admin → Service Accounts** → project
`dhakker-160d0` → **Create service account**.

| field | value |
|---|---|
| Name | `dhakker-production-reader` |
| Description | `Read-only reconciliation of the supplications collection. No write role, ever.` |

Its address will be:

```
dhakker-production-reader@dhakker-160d0.iam.gserviceaccount.com
```

**Do not grant any role on the create screen** — do it explicitly in step 2 so
the grant is a deliberate act with one entry in the audit log.

**Do not create a JSON key.** Workload Identity Federation issues short-lived
tokens; a downloaded key is a long-lived secret with nowhere safe to live. The
workflow sets `create_credentials_file: false` and never writes one to disk.

## 2. Grant exactly one role

**IAM & Admin → IAM** → **Grant access** → principal
`dhakker-production-reader@dhakker-160d0.iam.gserviceaccount.com` → role
**Cloud Datastore Viewer** (`roles/datastore.viewer`).

Or with the CLI, on a machine where you are already authenticated:

```bash
gcloud projects add-iam-policy-binding dhakker-160d0 \
  --member="serviceAccount:dhakker-production-reader@dhakker-160d0.iam.gserviceaccount.com" \
  --role="roles/datastore.viewer"
```

**One role. Nothing else.** In particular:

| role | why not |
|---|---|
| `roles/datastore.user` | read **and write** — the whole point is to not have it |
| `roles/storage.objectViewer` | reconciliation compares Firestore documents against the pack; it never touches audio |
| `roles/editor`, `roles/viewer` | project-wide on every service, far beyond one collection |

Note the same caveat that applies to staging: **Firestore IAM has no
per-collection scope.** `datastore.viewer` can read `users`, `sos_requests`
and everything else in the project, not just `supplications`. That is a
property of Firestore, not of this setup, and it is a documented risk
acceptance rather than an oversight. What the role cannot do is change
anything.

## 3. Let the existing WIF provider impersonate it

The provider from the staging setup is reused; only the binding is new. Bind
the GitHub principal for **this repository and the `main` branch only**, so a
run from a fork or a feature branch cannot obtain this identity:

```bash
PROJECT_NUMBER=435128982475   # dhakker-160d0

gcloud iam service-accounts add-iam-policy-binding \
  dhakker-production-reader@dhakker-160d0.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/subject/repo:whyKaiser/Dhakker:ref:refs/heads/main"
```

Confirm the provider's own attribute condition still restricts the repository
(it was set up for the staging import; if it names `whyKaiser/Dhakker`, this
account inherits that restriction too):

```bash
gcloud iam workload-identity-pools providers describe github-provider \
  --location=global --workload-identity-pool=github-pool \
  --project=dhakker-160d0 --format="value(attributeCondition)"
```

## 4. Create the protected GitHub environment

GitHub → **Settings → Environments → New environment** →
**`firebase-production-readonly`**.

Configure on the environment itself, not in the workflow file — a pull request
can edit the file, but not the environment:

1. **Required reviewers** → add yourself (and anyone else who should be able
   to approve a production read). The job pauses until one of them approves.
2. **Deployment branches** → *Selected branches* → `main`.
3. **Environment variables** → **Add variable**:

   | name | value |
   |---|---|
   | `FIREBASE_PRODUCTION_READER_SERVICE_ACCOUNT` | `dhakker-production-reader@dhakker-160d0.iam.gserviceaccount.com` |

   A **variable**, not a secret: a service-account address is a public
   identifier, and keeping it visible means the run log shows which identity
   was used. There is no secret to add — the token is minted at run time.

The workflow also reads `FIREBASE_PROJECT_ID`, `FIREBASE_DATABASE_ID` and
`GCP_WORKLOAD_IDENTITY_PROVIDER`. If those are repository-level variables from
the staging setup they are already visible here; if they were set on the
`firebase-staging` environment only, add them to this environment too.

## 5. Run it

Actions → **Production reconcile (read-only, manual)** → **Run workflow** on
`main`, and type all four confirmations exactly:

```
confirm_project    : dhakker-160d0
confirm_database   : (default)
confirm_collection : supplications
confirm_mode       : RECONCILE_READ_ONLY
```

The job then waits for environment approval. After approval it lists the
collection, compares it against the pack and the ledger, and writes a summary.

## Reading the result

| case | meaning | what to do |
|---|---|---|
| `expected_and_present` | cleared by the ledger, live, text matches | nothing |
| `expected_missing` | cleared but not live | an import would create it |
| `text_changed` | live, but the stored text differs from the pack | an import would update it and drop its verification |
| **`present_but_excluded`** | **live, but the ledger holds it back** | **decide what to retract** |
| **`present_but_removed_from_pack`** | **live, but the pack no longer contains it** | **decide what to retract** |

The run exits non-zero if either bold case appears. That is a finding, not a
failure of the job: neither can be corrected by importing, because writing
more records does not retract one that is already live.

**Retraction is deliberate and human.** This workflow reports and stops. There
is no `--delete`, no `--prune` and no `revoke` path anywhere in the importer,
and this change does not add one.

## What is still true after all of this

- **The report is a snapshot.** Nothing stops a document changing a second
  after the listing.
- **`roles/datastore.viewer` is project-wide.** It can read every collection
  in `dhakker-160d0`, not only `supplications`.
- **`id-token: write` is a GitHub permission, not a Google one.** It lets the
  job mint an OIDC token to exchange; what that token may do is decided
  entirely by the service account's single role.
- **The workflow file is not the guarantee.** IAM is. This document, the file
  and `production_reconcile_workflow.test.mjs` make the intent auditable; the
  role makes writing impossible.
