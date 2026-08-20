# Staging import — setup you perform, once

This is the exact list of Google Cloud and GitHub steps needed before
`.github/workflows/staging-import.yml` can run. **Nothing here has been done
for you** — no Google Cloud resource, Firebase setting, or GitHub setting was
created or changed. Every command below is yours to run when you choose.

The workflow writes **one** record to **`supplications_staging`**, always
with `verificationStatus: unverified`. It cannot reach `supplications`.

---

## Why Workload Identity Federation and not a key file

A service-account JSON key is a long-lived credential. Put one in GitHub
Secrets and it is valid until someone remembers to rotate it, it appears in
every fork of a mistake, and its blast radius is "whatever that account can
do, forever".

Workload Identity Federation removes the key entirely. GitHub mints a
short-lived OIDC token that says *this repository, this workflow, this ref*;
Google verifies it against a trust policy you define and returns an access
token that expires in five minutes. There is no secret to leak, rotate, or
find in a log.

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
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == 'whyKaiser' && assertion.repository == '${REPO}'"
```

> **The `--attribute-condition` is the load-bearing line.** Without it the
> provider trusts *every* repository on GitHub — anyone could mint a token
> for your project from their own repo. Do not omit it, and do not widen it
> to just the owner.

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

**`roles/datastore.user` is the minimum role that works.** It grants read and
write on documents and nothing else.

Roles you should **not** use here, and why:

| Role | Why not |
|---|---|
| `roles/datastore.owner` | Adds index, database and import/export administration — none of which an import needs. |
| `roles/editor` | Project-wide write on every service. Wildly beyond scope. |
| `roles/owner` | Can also change IAM, i.e. grant itself anything later. |
| `roles/datastore.viewer` | Read-only; the import would fail. |

If you want to go tighter than `datastore.user`, Firestore IAM has no
per-collection granularity — the correct way to narrow it further is a
**separate Firebase project for staging**, not a narrower role.

### 1.5 Let the repository impersonate that service account

```sh
gcloud iam service-accounts add-iam-policy-binding \
  "${SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="$PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/attribute.repository/${REPO}"
```

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
