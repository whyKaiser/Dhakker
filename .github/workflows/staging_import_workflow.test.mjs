// Static validation of the staging-import workflow's safety gates.
//
// A workflow file has no unit tests of its own, and its failure mode is the
// worst kind: it looks fine in review and only misbehaves the day someone
// runs it against a real project. So the guarantees are asserted here as
// text properties of the file, and this suite runs in CI on every change.
//
// These are deliberately assertions about the FILE, not about YAML
// semantics: the point is that a future edit which quietly adds a `push:`
// trigger, unpins an action, or slips `--production` in must turn a test
// red rather than pass review on a skim.

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const PATH = ".github/workflows/staging-import.yml";
const wf = readFileSync(PATH, "utf8");

// The line-level view, comments stripped, so a rule that only appears in a
// comment cannot satisfy a test about behaviour.
const code = wf
  .split("\n")
  .filter((l) => !l.trim().startsWith("#"))
  .join("\n");

test("the only trigger is workflow_dispatch", () => {
  assert.match(code, /^on:\s*$/m);
  assert.match(code, /^ {2}workflow_dispatch:/m);

  // Every automatic trigger must be absent. A staging write must never be
  // startable by pushing a commit or opening a PR.
  for (const trigger of [
    "push",
    "pull_request",
    "pull_request_target",
    "schedule",
    "repository_dispatch",
    "workflow_run",
    "workflow_call",
    "issue_comment",
    "release",
  ]) {
    assert.equal(
      new RegExp(`^ {2}${trigger}:`, "m").test(code),
      false,
      `trigger "${trigger}" must not be present`,
    );
  }
});

test("permissions are exactly contents:read and id-token:write", () => {
  const block = code.match(/^permissions:\n((?: {2}\S.*\n)+)/m);
  assert.ok(block, "a top-level permissions block is required");

  const lines = block[1].trim().split("\n").map((l) => l.trim());
  assert.deepEqual(lines.sort(), ["contents: read", "id-token: write"]);
});

test("the job runs in the protected firebase-staging environment", () => {
  assert.match(code, /^ {4}environment: firebase-staging$/m);
});

test("concurrency prevents two staging imports at once, without cancelling", () => {
  assert.match(code, /^concurrency:/m);
  assert.match(code, /group: staging-import/);
  // Cancelling mid-write would leave a half-imported collection; queueing is
  // the correct behaviour for a job that writes.
  assert.match(code, /cancel-in-progress: false/);
});

test("production is unreachable from this workflow", () => {
  assert.equal(code.includes("--production"), false);
  // The only collection named anywhere in the executable part is staging.
  assert.equal(/supplications(?!_staging)/.test(code), false);
  assert.ok(code.includes("supplications_staging"));
});

test("the write is limited to one record and carries its confirmations", () => {
  assert.match(code, /--staging --limit 1 --write/);
  assert.match(code, /--confirm-project=/);
  assert.match(code, /--confirm-count=/);
});

test("a dry run happens before authentication", () => {
  // Matched by the step's name rather than by the exact command line: the
  // command now pipes through `tee` so the counts can be asserted, and
  // pinning the literal text made this test fail for a change that did not
  // touch the ordering it exists to protect.
  const dryRun = code.indexOf("Dry run (no credentials, nothing written)");
  const auth = code.indexOf("google-github-actions/auth@");
  assert.ok(dryRun > -1, "a dry-run step is required");
  assert.ok(auth > -1, "an auth step is required");
  assert.ok(dryRun < auth, "the dry run must precede authentication");
  assert.match(code, /--staging --limit 1/, "the dry run must be limited");
});

test("the dry-run log must state the count before AND after --limit", () => {
  // The 2026-08-27 staging run logged only "Included: 1", which is true of
  // the write and says nothing about how many records the ledger cleared.
  // Both numbers now have to appear or the step fails.
  assert.match(code, /grep -q "Cleared by ledger \(before --limit\): 73"/);
  assert.match(code, /grep -q "\^Included:   1"/);
  assert.match(code, /grep -q "\^Excluded:   12"/);
});

test("the written record is read back and verified before the run passes", () => {
  // A 200 from Firestore proves the request was accepted, not that the
  // document holds what was sent.
  assert.match(code, /grep -qE "\^verified moia-mukhtasar-1446-umrah-talbiyah/);
  assert.match(code, /writes: \[01\]\$/, "the write count must be asserted");
  assert.match(
    code,
    /test "\$\(grep -cE '\^\(created\|updated\) ' write\.log\)" -le 1/,
    "a second write must fail the run",
  );
  const write = code.indexOf("--staging --limit 1 --write");
  const verify = code.indexOf("verified moia-mukhtasar-1446-umrah-talbiyah");
  assert.ok(write > -1 && verify > write, "verification follows the write");
});

test("the staging workflow still cannot open or read supplications_staging", () => {
  // Verification happens server-side through the importer's own credential.
  // It must not have loosened the rules or taught the app to read staging.
  const rules = readFileSync("firestore.rules", "utf8");
  assert.match(
    rules,
    /match \/supplications_staging\/\{document=\*\*\} \{\s*allow read, write: if false;/,
    "supplications_staging must stay closed to every client",
  );
});

test("confirmations are checked before authentication", () => {
  const confirmStep = code.indexOf("Verify manual confirmations");
  const auth = code.indexOf("google-github-actions/auth@");
  assert.ok(confirmStep > -1);
  assert.ok(
    confirmStep < auth,
    "the confirmation gate must run before any credential is minted",
  );
});

test("each confirmation is compared to its exact required value", () => {
  assert.match(code, /CONFIRM_PROJECT" != "dhakker-160d0"/);
  assert.match(code, /CONFIRM_COLLECTION" != "supplications_staging"/);
  assert.match(code, /CONFIRM_COUNT" != "1"/);
  // Each mismatch must end the run.
  assert.match(code, /exit 1/);
});

test("every third-party action is pinned to a full 40-hex commit SHA", () => {
  const uses = [...code.matchAll(/uses:\s*(\S+)/g)].map((m) => m[1]);
  assert.ok(uses.length > 0, "expected at least one action");

  for (const ref of uses) {
    assert.match(
      ref,
      /^[\w.-]+\/[\w.-]+@[0-9a-f]{40}$/,
      `"${ref}" must be pinned to a full commit SHA, not a tag or branch`,
    );
  }
});

test("every pinned action documents its release version in a comment", () => {
  // A bare SHA is unreviewable. Each `uses:` must be preceded by a comment
  // naming the version that SHA corresponds to.
  const lines = wf.split("\n");
  const usesLines = lines
    .map((l, i) => [l, i])
    .filter(([l]) => /^\s*uses:/.test(l));

  assert.ok(usesLines.length > 0);
  for (const [line, i] of usesLines) {
    const preceding = lines.slice(Math.max(0, i - 6), i).join("\n");
    assert.match(
      preceding,
      /#.*v\d+\.\d+\.\d+/,
      `no version comment documented above: ${line.trim()}`,
    );
  }
});

test("configuration comes from vars, never from inline secrets", () => {
  for (const name of [
    "FIREBASE_PROJECT_ID",
    "FIREBASE_DATABASE_ID",
    "GCP_WORKLOAD_IDENTITY_PROVIDER",
    "GCP_SERVICE_ACCOUNT",
  ]) {
    assert.ok(
      code.includes(`vars.${name}`),
      `${name} must be read from vars.*`,
    );
    assert.equal(
      code.includes(`secrets.${name}`),
      false,
      `${name} must not be read from secrets.*`,
    );
  }
});

test("no long-lived credential is created or exported", () => {
  assert.match(code, /create_credentials_file:\s*false/);
  assert.match(code, /export_environment_variables:\s*false/);
  assert.match(code, /access_token_lifetime:\s*\d+s/);
  // A service-account key must never appear.
  assert.equal(/credentials_json|private_key|service_account_key/.test(code), false);
});

test("nothing echoes a token, a credential, or the environment", () => {
  const dangerous = [
    /echo[^\n]*\$\{?\{?\s*secrets\./,
    /echo[^\n]*access_token/i,
    /echo[^\n]*FIREBASE_ADMIN_TOKEN/,
    /echo[^\n]*Authorization/i,
    /\bprintenv\b/,
    /\benv\s*$/m,
    /set -x/,
  ];
  for (const pattern of dangerous) {
    assert.equal(
      pattern.test(code),
      false,
      `workflow must not contain ${pattern}`,
    );
  }
});

test("the checkout does not leave repository credentials on disk", () => {
  // Otherwise the job would carry a token it has no use for.
  assert.match(code, /persist-credentials:\s*false/);
});

// ── Token lifetime ──────────────────────────────────────────────────────
//
// Two different tokens are involved and they are easy to conflate:
//   - the GitHub OIDC token, minted because of `id-token: write`, which only
//     proves who this workflow is and is consumed by the STS exchange;
//   - the Google access token STS returns, which is the one that can write
//     to Firestore.
// Only the second has a lifetime this repository controls, and the action's
// default for it is a full hour.

test("a 300s Google access-token lifetime is requested explicitly", () => {
  assert.match(code, /access_token_lifetime:\s*300s/);
  // The action's default is 3600s; leaving it implicit would hand the job an
  // hour of write-capable credential for a few seconds of work.
  assert.equal(/access_token_lifetime:\s*3600s/.test(code), false);
});

test("the write step is bounded below the token lifetime", () => {
  // If the import cannot finish inside the token's life, the run must fail
  // and say so — not be quietly "fixed" by reverting to the 1h default.
  const write = code.slice(code.indexOf("Write one record to"));
  const timeout = write.match(/timeout-minutes:\s*(\d+)/);
  assert.ok(timeout, "the write step must declare timeout-minutes");
  assert.ok(
    Number(timeout[1]) * 60 < 300,
    `timeout (${timeout[1]}m) must be under the 300s token lifetime`,
  );
});

test("the OIDC token and the access token are documented as distinct", () => {
  // Asserted on the full file including comments: this is a documentation
  // requirement, and the comment is where a reviewer reads it.
  assert.match(wf, /TWO DIFFERENT TOKENS/);
  assert.match(wf, /GitHub OIDC token/);
  assert.match(wf, /Google access token/);
  assert.match(wf, /3600s/);
});

// ── The access token reaches exactly one step ──────────────────────────

test("the auth output is referenced once, and only by the importer step", () => {
  const refs = [...code.matchAll(/steps\.auth\.outputs\.access_token/g)];
  assert.equal(refs.length, 1, "the token must be referenced exactly once");

  // That single reference must sit inside the write step, after its name.
  const writeStep = code.indexOf("Write one record to supplications_staging");
  assert.ok(writeStep > -1);
  assert.ok(
    refs[0].index > writeStep,
    "the token must be consumed by the importer step, not earlier",
  );

  // And it must arrive through env:, not be interpolated into the command
  // line, where it would land in the process table and any command echo.
  assert.match(code, /FIREBASE_ADMIN_TOKEN:\s*\$\{\{\s*steps\.auth\.outputs\.access_token\s*\}\}/);
  assert.equal(
    /node scripts\/import_source_pack\.mjs[\s\S]{0,400}access_token/.test(code),
    false,
    "the token must never appear in the command line",
  );
});

test("no other step can see the token", () => {
  // Only the write step declares FIREBASE_ADMIN_TOKEN at all.
  const declarations = [...code.matchAll(/FIREBASE_ADMIN_TOKEN:/g)];
  assert.equal(declarations.length, 1);
});

// ── Ref restriction, enforced before authentication ────────────────────

test("the workflow refuses any ref except refs/heads/main", () => {
  assert.match(code, /github\.ref/);
  assert.match(code, /!=\s*"refs\/heads\/main"/);

  const refCheck = code.indexOf("Refuse to run from any ref except main");
  const auth = code.indexOf("google-github-actions/auth@");
  const checkout = code.indexOf("actions/checkout@");
  assert.ok(refCheck > -1, "a ref gate is required");
  assert.ok(refCheck < auth, "the ref gate must precede authentication");
  assert.ok(refCheck < checkout, "the ref gate must precede checkout");
});

// ── The setup documentation is part of the security control ────────────
//
// The Workload Identity provider condition and the service-account binding
// live in Google Cloud, which this repository cannot inspect. The document
// telling the operator how to build them is therefore the only artefact we
// CAN test — and a doc that quietly loses the `ref` clause would leave the
// project open to anyone who can push a branch.

const DOC = "docs/STAGING_IMPORT_SETUP.md";
const doc = readFileSync(DOC, "utf8");

// Markdown wraps prose across lines and prefixes blockquotes with "> ", so a
// phrase like "no per-collection granularity" can straddle a line break.
// Content assertions run against this flattened view; assertions about
// commands and code fences keep using `doc` itself.
const prose = doc.replace(/\n>?\s*/g, " ");

test("the provider condition restricts owner, repository AND ref", () => {
  const condition = doc.match(/--attribute-condition="([^"]+)"/);
  assert.ok(condition, "the documented gcloud command must set a condition");
  const c = condition[1];

  assert.match(c, /assertion\.repository_owner == 'whyKaiser'/);
  assert.match(c, /assertion\.repository == '\$\{REPO\}'/);
  assert.match(c, /assertion\.ref == 'refs\/heads\/main'/);
  assert.match(doc, /export REPO=whyKaiser\/Dhakker/);

  // `ref` must also be mapped, or the condition cannot reference it.
  assert.match(doc, /attribute\.ref=assertion\.ref/);
});

test("the doc explains what each provider clause blocks", () => {
  for (const blocked of ["forks", "tags", "pull-request branches"]) {
    assert.ok(
      doc.toLowerCase().includes(blocked.toLowerCase()),
      `the doc must say ${blocked} are blocked`,
    );
  }
});

test("the impersonation binding is scoped to this repository", () => {
  assert.match(
    doc,
    /principalSet:\/\/iam\.googleapis\.com\/projects\/\$\{PROJECT_NUMBER\}\/locations\/global\/workloadIdentityPools\/\$\{POOL\}\/attribute\.repository\/\$\{REPO\}/,
  );
  // And the broader forms must be called out as wrong, not merely omitted.
  assert.match(doc, /attribute\.repository_owner\/whyKaiser/);
  assert.match(doc, /every repository you own/);
});

test("datastore.user is documented as project-wide, not collection-scoped", () => {
  assert.match(prose, /project-wide/);
  assert.match(prose, /NOT collection-level least privilege/);
  assert.match(prose, /no per-collection granularity/);
  // The doc must not claim IAM keeps the credential out of production.
  assert.match(prose, /Nothing in the Google Cloud layer stops this credential/);
});

test("a separate project is recommended, same-project is a risk acceptance", () => {
  assert.match(doc, /Stronger isolation — the recommended option/);
  assert.match(doc, /separate Firebase\/GCP project for staging/);
  assert.match(doc, /explicit risk acceptance/);

  // All four compensating controls must be named.
  for (const control of [
    "GitHub Environment approval",
    "refs/heads/main",
    "Fixed staging collection",
    "Importer production guards",
  ]) {
    assert.ok(doc.includes(control), `missing compensating control: ${control}`);
  }
});

test("the doc distinguishes the two tokens and the 3600s default", () => {
  assert.match(doc, /GitHub OIDC token/);
  assert.match(doc, /Google access token/);
  assert.match(prose, /`3600s` — a full hour/);
  assert.match(prose, /requests \*\*`300s`\*\*/);
  assert.match(doc, /timeout-minutes: 4/);
});
