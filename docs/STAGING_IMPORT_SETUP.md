# Staging import — setup you perform, once

This is the exact list of Google Cloud and GitHub steps needed before
`.github/workflows/staging-import.yml` can run. **Nothing here has been done
for you** — no Google Cloud resource, Firebase setting, or GitHub setting was
created or changed. Every command below is yours to run when you choose.

The workflow writes **one** record to **`supplications_staging`**, always
with `verificationStatus: unverified`. The *workflow* never names the
production collection — but read the IAM note in 1.4 before assuming the
*credential* cannot reach it: on a shared project, it can.

---

## Why Workload Identity Federation and not a key file

A service-account JSON key is a long-lived credential. Put one in GitHub
Secrets and it is valid until someone remembers to rotate it, it appears in
every fork of a mistake, and its blast radius is "whatever that account can
do, forever".

Workload Identity Federation removes the key entirely — but it is worth
being precise about what happens, because **two different tokens** are
involved and they are routinely conflated:

| | GitHub OIDC token | Google access token |
|---|---|---|
| Minted by | GitHub, because of `permissions: id-token: write` | Google STS, in exchange for the first |
| Asserts | *this repository, this workflow, this ref* | authorisation to call Google APIs |
| Can write to Firestore | **No** | **Yes** |
| Lifetime | GitHub's; not configurable in this workflow | **ours to set** — `access_token_lifetime` |
| Reaches the importer | never | yes, as `FIREBASE_ADMIN_TOKEN` |

Only the second one matters for blast radius, and the auth action's default
for it is **`3600s` — a full hour**. The workflow requests **`300s`**
explicitly. (Verified against `action.yml` at the pinned commit: the input
exists, defaults to `3600s`, and applies when `token_format: access_token`.)

The write step also carries `timeout-minutes: 4`, deliberately under that
lifetime. If an import ever cannot finish inside five minutes, the run
**fails and says so**. Do not "fix" that by dropping back to the one-hour
default: raise the lifetime deliberately, in review, and raise the timeout
with it.

There is no secret to leak, rotate, or find in a log.

---

## Part 1 — Google Cloud

Run these as a user with `roles/iam.workloadIdentityPoolAdmin` and
`roles/iam.serviceAccountAdmin` on the project. Set your shell up first:

```sh
export PROJECT_ID=dhakker-160d0
export PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
export POOL=github-pool
export PROVIDER=github-provider
export SA=dhakker-staging-import
export REPO=whyKaiser/Dhakker
```

### 1.1 Enable the APIs

```sh
gcloud services enable \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  firestore.googleapis.com \
  --project="$PROJECT_ID"
```

### 1.2 Create the identity pool and the GitHub provider

```sh
gcloud iam workload-identity-pools create "$POOL" \
  --project="$PROJECT_ID" --location=global \
  --display-name="GitHub Actions"

gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" \
  --project="$PROJECT_ID" --location=global \
  --workload-identity-pool="$POOL" \
  --display-name="GitHub OIDC" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.ref=assertion.ref" \
  --attribute-condition="assertion.repository_owner == 'whyKaiser' && assertion.repository == '${REPO}' && assertion.ref == 'refs/heads/main'"
```

> **The `--attribute-condition` is the load-bearing line of this entire
> setup.** Without it the provider trusts *every* repository on GitHub —
> anyone could mint a token for your project from their own repo.

All three clauses are required, and each blocks something different:

| Clause | Blocks |
|---|---|
| `assertion.repository_owner == 'whyKaiser'` | every other GitHub account and org |
| `assertion.repository == 'whyKaiser/Dhakker'` | your other repositories, and **forks** — a fork keeps the owner in some contexts but never this full name |
| `assertion.ref == 'refs/heads/main'` | pull-request branches (`refs/pull/N/merge`), feature branches, and **tags** (`refs/tags/*`) |

Without the `ref` clause, anyone who can push a branch to this repository
could dispatch a workflow of their own writing against your Firestore. With
it, only code that has already been merged to `main` can authenticate at
all — the branch restriction is enforced by Google, not merely by GitHub.

The workflow additionally refuses to start from any ref except
`refs/heads/main` (a step that runs before checkout and before
authentication), and the protected environment restricts deployment
branches. Three independent layers; the provider condition is the one that
actually protects Google Cloud, because it is the only one outside the
repository's own control.

### 1.3 Create the service account the workflow impersonates

```sh
gcloud iam service-accounts create "$SA" \
  --project="$PROJECT_ID" \
  --display-name="Dhakker staging import (GitHub Actions)"
```

### 1.4 Grant the MINIMUM Firestore role

```sh
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/datastore.user"
```

**`roles/datastore.user` is the minimum role that works** for this task. It
grants read and write on documents and nothing else — no index, database, or
import/export administration.

> ### ⚠️ It is NOT collection-level least privilege
>
> **`roles/datastore.user` is project-wide.** It permits read and write to
> **every collection in the database**, including `supplications`, `zones`,
> `users`, and anything added later. Firestore IAM has **no per-collection
> granularity**, so no role can restrict this account to
> `supplications_staging`.
>
> Nothing in the Google Cloud layer stops this credential from writing to
> the production collection. What stops it is entirely in the layers above:
> the workflow never names `supplications`, and the importer refuses
> `--limit` against production and requires an explicit `--production` flag
> that the workflow never passes. Those are code guards, protected by
> review and by the static tests in
> `.github/workflows/staging_import_workflow.test.mjs` — they are real, but
> they are not IAM.
>
> If you want isolation that does not depend on the correctness of this
> repository's code, see **"Stronger isolation"** below.

Roles you should **not** use here, and why:

| Role | Why not |
|---|---|
| `roles/datastore.owner` | Adds index, database and import/export administration — none of which an import needs. |
| `roles/editor` | Project-wide write on every service. Wildly beyond scope. |
| `roles/owner` | Can also change IAM, i.e. grant itself anything later. |
| `roles/datastore.viewer` | Read-only; the import would fail. |

### Stronger isolation — the recommended option

**Use a separate Firebase/GCP project for staging.** Create, say,
`dhakker-staging`, run the whole of Part 1 against it, and point
`FIREBASE_PROJECT_ID` at it. Then:

- The service account has no grant of any kind on the production project, so
  a bug, a bad merge, or a compromised action **cannot** reach production
  data. The guarantee comes from IAM rather than from code being correct.
- A mistaken import damages throwaway data.
- The blast radius of the whole mechanism becomes "a staging project".

That is the option to choose if you can.

### Same-project path — an explicit risk acceptance

Running staging inside `dhakker-160d0` is supported, and is what the
variables in Part 2 describe, but **it is a documented risk acceptance, not
a least-privilege design**. You are accepting that a project-wide
`datastore.user` credential exists in CI and that only application-level
guards keep it away from `supplications`.

Accept it only with all four of these in place — they are the compensating
controls, and removing any one of them changes the risk materially:

| Control | What it stops |
|---|---|
| **GitHub Environment approval** on `firebase-staging` | any run starting without a named human approving it |
| **`assertion.ref == 'refs/heads/main'`** in the provider condition | authentication from a PR branch, a tag, a fork, or another repo |
| **Fixed staging collection** in the workflow | the destination ever being anything but `supplications_staging` |
| **Importer production guards** (`--production` required, `--limit` refused against it, confirmations must match) | a production write even if the workflow were edited |

Revisit this the moment the import stops being a one-record trial.

### 1.5 Let ONLY this repository impersonate that service account

```sh
gcloud iam service-accounts add-iam-policy-binding \
  "${SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="$PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/attribute.repository/${REPO}"
```

The binding is scoped by `attribute.repository`, so the exact principal
allowed to impersonate the account is:

```
principalSet://iam.googleapis.com/projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/github-pool/attribute.repository/whyKaiser/Dhakker
```

**Do not** substitute either of these broader forms:

| Form | Why not |
|---|---|
| `.../workloadIdentityPools/github-pool/*` | every identity in the pool, i.e. any repo the provider ever accepts |
| `.../attribute.repository_owner/whyKaiser` | every repository you own, including new and private ones |

The pool membership condition (1.2) and this binding are two separate
gates: the first decides who may *enter the pool*, the second who may
*become this service account*. Set both.

### 1.6 Print the provider resource name

```sh
gcloud iam workload-identity-pools providers describe "$PROVIDER" \
  --project="$PROJECT_ID" --location=global \
  --workload-identity-pool="$POOL" --format='value(name)'
```

Copy the output — it is `GCP_WORKLOAD_IDENTITY_PROVIDER` below.

---

## Part 2 — GitHub

### 2.1 Create the protected environment

**Settings → Environments → New environment → `firebase-staging`**

The name must match exactly; the workflow names it. On that environment:

- **Required reviewers** — add yourself (and anyone else who should be able
  to approve). GitHub then holds the job until a human approves it. This is
  enforced by GitHub, not by the workflow file, so a pull request cannot
  weaken it.
- **Deployment branches** — restrict to `main`. A branch cannot then run the
  workflow with its own edited copy.
- **Wait timer** — optional; a few minutes gives you a window to cancel.

### 2.2 Add the four variables

**Settings → Secrets and variables → Actions → Variables** (the *Variables*
tab, **not** Secrets — none of these is a secret, and putting them in
Secrets would only make them harder to review). Add them on the
`firebase-staging` environment, or repository-wide if you prefer:

| Variable | Value |
|---|---|
| `FIREBASE_PROJECT_ID` | `dhakker-160d0` |
| `FIREBASE_DATABASE_ID` | `(default)` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | the resource name printed by step 1.6 |
| `GCP_SERVICE_ACCOUNT` | `dhakker-staging-import@dhakker-160d0.iam.gserviceaccount.com` |

The workflow fails with a named list if any is missing.

---

## Part 3 — Running it

**Actions → Staging import (manual) → Run workflow**, then type:

| Input | Required value |
|---|---|
| `confirm_project` | `dhakker-160d0` |
| `confirm_collection` | `supplications_staging` |
| `confirm_count` | `1` |

Any mismatch fails the run **before authentication** — no token is minted.

The run then, in order: checks your confirmations → checks the four
variables are present and agree with what you typed → checks out the repo →
runs the importer **dry** with no credentials at all → authenticates →
writes exactly one record.

### What lands in Firestore

One document, `supplications_staging/moia-mukhtasar-1446-umrah-talbiyah`,
with `verificationStatus: unverified`, `verifiedAt: null`, `verifiedBy: null`.
The Worker's provenance gate rejects unverified records, so nothing becomes
citable in the app as a result of running this.

---

## Part 4 — Afterwards

Inspect the document in the Firebase console. When you are finished with the
trial:

```sh
# Delete the single staging document (console or gcloud firestore).
```

To revoke access entirely, remove the `workloadIdentityUser` binding from
step 1.5 — the repository can no longer impersonate the account, and there
is no key to hunt down because none was ever created.

---

## Pinned action versions

Every third-party action is pinned to a full commit SHA;
`.github/workflows/staging_import_workflow.test.mjs` fails if any is
downgraded to a tag or branch.

| Action | Version | Commit |
|---|---|---|
| `actions/checkout` | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `actions/setup-node` | v7.0.0 | `820762786026740c76f36085b0efc47a31fe5020` |
| `google-github-actions/auth` | v3.0.0 | `7c6bc770dae815cd3e89ee6cdf493a5fab2cc093` |

To update one, resolve the new tag to its commit and change both the SHA and
the version comment together:

```sh
git ls-remote https://github.com/actions/checkout refs/tags/vX.Y.Z
```
