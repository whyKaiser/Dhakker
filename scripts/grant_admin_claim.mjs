#!/usr/bin/env node
/**
 * Grants or revokes the `admin` custom claim on ONE Firebase Auth account.
 *
 * ── Why this exists ──────────────────────────────────────────────────────
 *
 * `docs/ADMIN_CLAIM_SETUP.md` documents doing this with the Admin SDK and a
 * service-account JSON key. A key file is a long-lived credential that can
 * mint admins, sitting on a laptop; this project has avoided creating one
 * everywhere else, and there is no reason to make an exception for the single
 * control that decides who may replace the audio a pilgrim hears.
 *
 * This uses the Identity Toolkit REST API with a SHORT-LIVED OAuth access
 * token instead — the kind `gcloud auth print-access-token` prints, which
 * expires in about an hour and is never written to disk by this tool.
 *
 * ── What it will not do ──────────────────────────────────────────────────
 *
 * One account per run, named explicitly. No search, no list, no "all admins",
 * no wildcard. A tool that can grant admin in bulk is a tool that can be
 * talked into granting it to the wrong person, and there is no legitimate
 * reason to grant it to two accounts in one command.
 *
 * It also refuses to run without `--confirm=GRANT_ADMIN` (or REVOKE_ADMIN):
 * a typo'd uid should cost an error, not an admin.
 *
 * Existing claims are read first and MERGED, never replaced. Identity
 * Toolkit's update overwrites the whole custom-attributes blob, so a naive
 * write silently deletes every other claim the account carries. This project
 * has only one today; the next one would have been erased without a trace.
 *
 * Usage:
 *   FIREBASE_PROJECT_ID=dhakker-160d0 \
 *   GOOGLE_ACCESS_TOKEN="$(gcloud auth print-access-token)" \
 *     node scripts/grant_admin_claim.mjs --uid=<uid> --confirm=GRANT_ADMIN
 *
 *   ... --revoke --confirm=REVOKE_ADMIN
 */

export const IDENTITY_TOOLKIT = "https://identitytoolkit.googleapis.com/v1";

/** What a 403 usually means here, and the command that fixes each. */
export const HELP_403 = [
  "",
  "If that was a 403, it is almost always one of:",
  "  1. The Identity Toolkit API is not enabled on the project:",
  "       gcloud services enable identitytoolkit.googleapis.com \\",
  "         --project=dhakker-160d0",
  "  2. The signed-in account lacks Firebase Authentication Admin.",
  "       gcloud auth list          # who am I",
  "  3. The token was minted for a different project.",
  "",
].join("\n");

export const KNOWN_ARGUMENTS = Object.freeze([
  "--uid=<uid>",
  "--confirm=GRANT_ADMIN|REVOKE_ADMIN",
  "--revoke",
]);

/** Rejects any argument this tool does not define. */
export function assertOnlyKnownArguments(args) {
  const unknown = args.filter(
    (a) => a !== "--revoke" && !a.startsWith("--uid=") && !a.startsWith("--confirm="),
  );
  if (unknown.length === 0) return;
  throw new Error(
    `Unrecognised argument(s): ${unknown.join(", ")}\n` +
      `Accepted: ${KNOWN_ARGUMENTS.join(", ")}\n` +
      `There is no flag for granting to more than one account. Run it again.`,
  );
}

/**
 * Parses the command line into an intent.
 *
 * The confirmation must match the DIRECTION: confirming GRANT while passing
 * --revoke is a mismatch between what was typed and what would happen, and is
 * refused rather than resolved in either direction.
 */
export function parseArguments(args) {
  assertOnlyKnownArguments(args);

  const uidArg = args.find((a) => a.startsWith("--uid="));
  const uid = uidArg ? uidArg.slice("--uid=".length).trim() : "";
  if (!uid) {
    throw new Error("--uid=<uid> is required: name the one account explicitly.");
  }
  // Firebase Auth uids are opaque, but they are never empty, never contain
  // whitespace or a slash, and are at most 128 chars. Rejecting the shapes
  // that cannot be a uid turns a paste error into an error message.
  if (uid.length > 128 || /[\s/]/.test(uid)) {
    throw new Error("--uid does not look like a Firebase Auth uid.");
  }

  const revoke = args.includes("--revoke");
  const expected = revoke ? "REVOKE_ADMIN" : "GRANT_ADMIN";
  const confirmArg = args.find((a) => a.startsWith("--confirm="));
  const confirm = confirmArg ? confirmArg.slice("--confirm=".length).trim() : "";
  if (confirm !== expected) {
    throw new Error(
      `--confirm=${expected} is required for this direction.\n` +
        `You passed: ${confirm || "(nothing)"}.`,
    );
  }

  return { uid, revoke };
}

/**
 * Merges the admin flag into whatever claims the account already carries.
 *
 * Identity Toolkit replaces the entire customAttributes string, so the
 * existing ones must be read and carried forward or they are destroyed.
 * Malformed stored JSON is treated as "no claims" rather than throwing: the
 * account still needs its claim set, and refusing to help because of an
 * unrelated corrupt value would leave it stuck.
 */
export function mergeClaims(existingJson, { admin }) {
  let existing = {};
  if (typeof existingJson === "string" && existingJson.trim() !== "") {
    try {
      const parsed = JSON.parse(existingJson);
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        existing = parsed;
      }
    } catch (_) {
      existing = {};
    }
  }
  // Strict `true`, never "true" or 1: storage.rules compares against the
  // boolean, and a string would read as granted here while refusing there.
  return { ...existing, admin: admin === true };
}

/**
 * Turns a Google API error into a line an operator can act on.
 *
 * A bare `HTTP 403` is three different problems with three different fixes:
 * the Identity Toolkit API not enabled on the project, the signed-in account
 * lacking Firebase Authentication Admin, or a token minted for the wrong
 * project. Google says which in `error.status` and `error.message`, and
 * swallowing that leaves the operator guessing — the same failure the Worker
 * had before its diagnostics.
 *
 * The message is truncated and any long unbroken token-shaped run is redacted
 * before it is shown. Google does not echo the Authorization header in an
 * error, but "does not" is a property of today's API, and a credential in a
 * terminal scrollback is not recoverable once it is there.
 */
export function describeApiError(httpStatus, body) {
  const err = (body && typeof body === "object" && body.error) || {};
  const code =
    typeof err.status === "string" && err.status ? err.status : `HTTP_${httpStatus}`;
  let message = typeof err.message === "string" ? err.message : "";
  message = message.replace(/[A-Za-z0-9._-]{40,}/g, "[redacted]").slice(0, 200);
  return message ? `${code}: ${message}` : code;
}

/** Reads the response body as JSON, or null. Never throws. */
async function safeJson(res) {
  try {
    return await res.json();
  } catch (_) {
    return null;
  }
}

/** Reads the account. Returns the raw customAttributes string, or "". */
export async function lookupClaims(plan, deps = {}) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  const res = await doFetch(
    `${IDENTITY_TOOLKIT}/projects/${plan.projectId}/accounts:lookup`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${plan.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ localId: [plan.uid] }),
    },
  );
  if (!res.ok) {
    throw new Error(`lookup failed — ${describeApiError(res.status, await safeJson(res))}`);
  }
  const body = await res.json();
  const user = (body.users ?? [])[0];
  if (!user) {
    throw new Error(
      "No account with that uid in this project. Nothing was changed.",
    );
  }
  return user.customAttributes ?? "";
}

/** Writes the merged claims back. */
export async function setClaims(plan, claims, deps = {}) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  const res = await doFetch(
    `${IDENTITY_TOOLKIT}/projects/${plan.projectId}/accounts:update`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${plan.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        localId: plan.uid,
        customAttributes: JSON.stringify(claims),
      }),
    },
  );
  if (!res.ok) {
    throw new Error(`update failed — ${describeApiError(res.status, await safeJson(res))}`);
  }
  return true;
}

/**
 * Invalidates tokens already issued.
 *
 * A claim change does not touch tokens that exist. Without this, a revoked
 * admin keeps write access for up to an hour — and on a GRANT the account
 * would otherwise have to sign out manually before the claim reached it.
 */
export async function revokeExistingTokens(plan, deps = {}) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  const res = await doFetch(
    `${IDENTITY_TOOLKIT}/projects/${plan.projectId}/accounts:update`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${plan.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        localId: plan.uid,
        validSince: String(Math.floor(Date.now() / 1000)),
      }),
    },
  );
  if (!res.ok) {
    throw new Error(
      `token revocation failed — ${describeApiError(res.status, await safeJson(res))}`,
    );
  }
  return true;
}

/** The whole operation. */
export async function run(plan, deps = {}, log = console.log) {
  const existing = await lookupClaims(plan, deps);
  const claims = mergeClaims(existing, { admin: !plan.revoke });
  await setClaims(plan, claims, deps);
  await revokeExistingTokens(plan, deps);

  // The uid is printed; the token never is. A uid identifies an account to
  // its owner, which is the point of the confirmation line.
  log("");
  log(plan.revoke ? "Revoked admin." : "Granted admin.");
  log(`account:  ${plan.uid}`);
  log(`claims:   ${Object.keys(claims).sort().join(", ")}`);
  log("existing sessions invalidated; the account must sign in again.");
  log("");
  log("Verify by uploading one small file from the admin screen — not by");
  log("reading the claim back in code. The rule is what matters, not the");
  log("value this tool believes it wrote.");
  return claims;
}

/* c8 ignore start — CLI wiring, exercised by hand rather than tests */
async function main() {
  const { uid, revoke } = parseArguments(process.argv.slice(2));

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const token = process.env.GOOGLE_ACCESS_TOKEN;
  if (!projectId || !token) {
    throw new Error(
      "FIREBASE_PROJECT_ID and GOOGLE_ACCESS_TOKEN must both be set.\n" +
        'Get a short-lived token with: gcloud auth print-access-token\n' +
        "Do not use a service-account key file for this.",
    );
  }

  await run({ projectId, token, uid, revoke });
}

const isDirectRun =
  process.argv[1] && process.argv[1].endsWith("grant_admin_claim.mjs");
if (isDirectRun) {
  main().catch((err) => {
    console.error(`\n${err.message}`);
    console.error(HELP_403);
    // exitCode, not exit(): process.exit() while stdio is still flushing
    // trips a libuv assertion on Windows, which buries the message that
    // matters under a crash that does not.
    process.exitCode = 1;
  });
}
/* c8 ignore stop */
