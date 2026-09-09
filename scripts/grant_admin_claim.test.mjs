// Guard tests for the admin-claim tool.
//
// This tool decides who may replace the audio a pilgrim hears. What it must
// never do is grant to the wrong account, grant in bulk, silently erase other
// claims, or put a credential anywhere it can be read later.

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  IDENTITY_TOOLKIT,
  assertOnlyKnownArguments,
  parseArguments,
  mergeClaims,
  lookupClaims,
  setClaims,
  describeApiError,
  HELP_403,
  run,
} from "./grant_admin_claim.mjs";

const SOURCE = readFileSync("scripts/grant_admin_claim.mjs", "utf8");

/** The file without its own prose, so a scan tests code and not comments. */
function codeOnly(source) {
  return source
    .split("\n")
    .filter((l) => {
      const t = l.trim();
      return !(t.startsWith("//") || t.startsWith("*") || t.startsWith("/*"));
    })
    .join("\n");
}

test("the comment stripper the scans below rely on works", () => {
  assert.ok(SOURCE.includes("service-account JSON key"));
  assert.equal(codeOnly(SOURCE).includes("service-account JSON key"), false);
  assert.ok(codeOnly(SOURCE).includes("accounts:update"));
});

// ── Arguments ─────────────────────────────────────────────────────────────

test("it grants to exactly one named account", () => {
  assert.deepEqual(
    parseArguments(["--uid=abc123", "--confirm=GRANT_ADMIN"]),
    { uid: "abc123", revoke: false },
  );
});

test("an unrecognised flag is refused, not ignored", () => {
  // A flag somebody believed was limiting the tool must not be silently
  // dropped.
  assert.throws(
    () => assertOnlyKnownArguments(["--all", "--uid=x"]),
    /Unrecognised argument/,
  );
  assert.throws(
    () => parseArguments(["--uid=a", "--confirm=GRANT_ADMIN", "--force"]),
    /Unrecognised argument/,
  );
});

test("there is no way to name a second account", () => {
  // No --uids, no comma splitting, no file input. Granting admin twice in one
  // command has no legitimate use and a very bad failure mode.
  const code = codeOnly(SOURCE);
  for (const forbidden of ["--uids", "--all", "--file", "split(\",\")"]) {
    assert.equal(code.includes(forbidden), false, `${forbidden} must not exist`);
  }
});

test("it refuses to run without the matching confirmation", () => {
  assert.throws(() => parseArguments(["--uid=a"]), /--confirm=GRANT_ADMIN/);
  assert.throws(
    () => parseArguments(["--uid=a", "--confirm=yes"]),
    /--confirm=GRANT_ADMIN/,
  );
});

test("confirming a grant while asking to revoke is refused", () => {
  // The typed word and the action must agree; resolving the mismatch either
  // way would do something the operator did not ask for.
  assert.throws(
    () => parseArguments(["--uid=a", "--revoke", "--confirm=GRANT_ADMIN"]),
    /REVOKE_ADMIN/,
  );
  assert.throws(
    () => parseArguments(["--uid=a", "--confirm=REVOKE_ADMIN"]),
    /GRANT_ADMIN/,
  );
});

test("a revoke is accepted with its own confirmation", () => {
  assert.deepEqual(
    parseArguments(["--uid=abc", "--revoke", "--confirm=REVOKE_ADMIN"]),
    { uid: "abc", revoke: true },
  );
});

test("a missing or malformed uid is refused", () => {
  for (const args of [
    ["--confirm=GRANT_ADMIN"],
    ["--uid=", "--confirm=GRANT_ADMIN"],
    ["--uid=   ", "--confirm=GRANT_ADMIN"],
    ["--uid=has space", "--confirm=GRANT_ADMIN"],
    ["--uid=has/slash", "--confirm=GRANT_ADMIN"],
    [`--uid=${"x".repeat(129)}`, "--confirm=GRANT_ADMIN"],
  ]) {
    assert.throws(() => parseArguments(args), /uid/);
  }
});

// ── Claims ────────────────────────────────────────────────────────────────

test("existing claims are carried forward, not erased", () => {
  // accounts:update replaces the whole blob. A naive write deletes every
  // other claim without a trace.
  const merged = mergeClaims('{"tier":"staff","region":"makkah"}', {
    admin: true,
  });
  assert.deepEqual(merged, { tier: "staff", region: "makkah", admin: true });
});

test("admin is written as the boolean true, never a string", () => {
  // storage.rules compares against `true`. A string would read as granted
  // here and refuse there.
  assert.equal(mergeClaims("", { admin: true }).admin, true);
  assert.notEqual(mergeClaims("", { admin: true }).admin, "true");
  assert.equal(mergeClaims("", { admin: false }).admin, false);
  for (const truthy of ["true", 1, "yes", {}]) {
    assert.equal(mergeClaims("", { admin: truthy }).admin, false);
  }
});

test("a revoke sets false rather than deleting the claim", () => {
  const merged = mergeClaims('{"admin":true,"tier":"staff"}', { admin: false });
  assert.deepEqual(merged, { admin: false, tier: "staff" });
});

test("corrupt stored claims do not block the grant", () => {
  for (const broken of ["not json", "[1,2]", "null", '"a string"', undefined]) {
    assert.deepEqual(mergeClaims(broken, { admin: true }), { admin: true });
  }
});

// ── Requests ──────────────────────────────────────────────────────────────

test("lookup reads exactly the one account and nothing else", async () => {
  const seen = [];
  await lookupClaims(
    { projectId: "p", token: "t", uid: "u1" },
    {
      fetch: async (url, init) => {
        seen.push({ url: String(url), body: JSON.parse(init.body) });
        return new Response(
          JSON.stringify({ users: [{ customAttributes: '{"admin":true}' }] }),
          { status: 200 },
        );
      },
    },
  );
  assert.equal(seen.length, 1);
  assert.equal(seen[0].url, `${IDENTITY_TOOLKIT}/projects/p/accounts:lookup`);
  assert.deepEqual(seen[0].body, { localId: ["u1"] });
});

test("an unknown uid stops the run rather than creating anything", async () => {
  await assert.rejects(
    () =>
      lookupClaims(
        { projectId: "p", token: "t", uid: "ghost" },
        { fetch: async () => new Response(JSON.stringify({ users: [] }), { status: 200 }) },
      ),
    /Nothing was changed/,
  );
});

test("a failed lookup raises rather than assuming no claims", async () => {
  // Reading "no claims" from a 403 would erase the real ones on write.
  await assert.rejects(
    () =>
      lookupClaims(
        { projectId: "p", token: "t", uid: "u" },
        { fetch: async () => new Response("denied", { status: 403 }) },
      ),
    /lookup failed/,
  );
});

test("a failure says WHY, not just that it failed", async () => {
  // A bare "HTTP 403" is three different problems with three different
  // fixes. Google says which; swallowing it leaves the operator guessing.
  await assert.rejects(
    () =>
      lookupClaims(
        { projectId: "p", token: "t", uid: "u" },
        {
          fetch: async () =>
            new Response(
              JSON.stringify({
                error: {
                  status: "PERMISSION_DENIED",
                  message:
                    "Identity Toolkit API has not been used in project dhakker-160d0 before or it is disabled.",
                },
              }),
              { status: 403 },
            ),
        },
      ),
    /PERMISSION_DENIED.*has not been used/s,
  );
});

test("a token-shaped run in an API error is redacted before it is shown", () => {
  // Google does not echo the Authorization header today. "Does not" is a
  // property of today's API, and a credential in a scrollback is not
  // recoverable once it is there.
  const described = describeApiError(403, {
    error: {
      status: "PERMISSION_DENIED",
      message: `bad credential ya29.${"A1b2C3d4".repeat(8)} for project p`,
    },
  });
  assert.equal(described.includes("A1b2C3d4A1b2C3d4"), false);
  assert.match(described, /\[redacted\]/);
  assert.match(described, /PERMISSION_DENIED/);
});

test("a non-JSON or shapeless error still produces a usable label", () => {
  assert.equal(describeApiError(500, null), "HTTP_500");
  assert.equal(describeApiError(403, "denied"), "HTTP_403");
  assert.equal(describeApiError(404, { error: {} }), "HTTP_404");
});

test("an API message is truncated rather than pasted whole", () => {
  // Words, not one long run: an unbroken run is caught by the redaction, so
  // a test built from one would pass without the truncation existing at all.
  const described = describeApiError(400, {
    error: { status: "INVALID_ARGUMENT", message: "policy denied ".repeat(400) },
  });
  assert.ok(described.length < 260, `too long: ${described.length}`);
  assert.equal(described.includes("[redacted]"), false, "redaction did the work");
});

test("the 403 help names the enable command, not just the problem", () => {
  // An error that describes a wall without pointing at the door is half an
  // error message.
  assert.match(HELP_403, /identitytoolkit\.googleapis\.com/);
  assert.match(HELP_403, /gcloud services enable/);
  assert.match(HELP_403, /Firebase Authentication Admin/);
});

test("the write targets one uid and carries the merged claims", async () => {
  const seen = [];
  await setClaims(
    { projectId: "p", token: "t", uid: "u1" },
    { admin: true, tier: "staff" },
    {
      fetch: async (url, init) => {
        seen.push({ url: String(url), body: JSON.parse(init.body) });
        return new Response("{}", { status: 200 });
      },
    },
  );
  assert.equal(seen[0].url, `${IDENTITY_TOOLKIT}/projects/p/accounts:update`);
  assert.equal(seen[0].body.localId, "u1");
  assert.deepEqual(JSON.parse(seen[0].body.customAttributes), {
    admin: true,
    tier: "staff",
  });
});

test("existing sessions are invalidated on both grant and revoke", async () => {
  // A claim change does not touch tokens already issued: without this a
  // revoked admin keeps write access for up to an hour.
  for (const revoke of [false, true]) {
    const bodies = [];
    await run(
      { projectId: "p", token: "t", uid: "u", revoke },
      {
        fetch: async (url, init) => {
          const body = JSON.parse(init.body);
          bodies.push(body);
          return String(url).endsWith("accounts:lookup")
            ? new Response(JSON.stringify({ users: [{ customAttributes: "" }] }), {
                status: 200,
              })
            : new Response("{}", { status: 200 });
        },
      },
      () => {},
    );
    assert.ok(
      bodies.some((b) => typeof b.validSince === "string"),
      `validSince was not set (revoke: ${revoke})`,
    );
  }
});

test("nothing it prints contains the access token", async () => {
  const printed = [];
  await run(
    { projectId: "p", token: "ya29.SUPER-SECRET-TOKEN", uid: "u1", revoke: false },
    {
      fetch: async (url) =>
        String(url).endsWith("accounts:lookup")
          ? new Response(JSON.stringify({ users: [{ customAttributes: "" }] }), {
              status: 200,
            })
          : new Response("{}", { status: 200 }),
    },
    (line) => printed.push(String(line)),
  );
  const all = printed.join("\n");
  assert.equal(all.includes("ya29"), false);
  assert.equal(all.includes("SUPER-SECRET-TOKEN"), false);
  // The uid IS printed: it is how the operator confirms the right account.
  assert.ok(all.includes("u1"));
});

// ── What the file must never contain ──────────────────────────────────────

test("no key file, no ambient credential, no committed secret", () => {
  const code = codeOnly(SOURCE);
  for (const token of [
    "GOOGLE_APPLICATION_CREDENTIALS",
    "private_key",
    "serviceAccount.json",
    "cert(",
    "firebase-admin",
  ]) {
    assert.equal(code.includes(token), false, `${token} must not appear`);
  }
});

test("it reaches only Identity Toolkit", () => {
  const hosts = [...codeOnly(SOURCE).matchAll(/https:\/\/([a-z0-9.-]+)/g)].map(
    (m) => m[1],
  );
  assert.deepEqual([...new Set(hosts)], ["identitytoolkit.googleapis.com"]);
});

test("it never touches Firestore or Storage", () => {
  const code = codeOnly(SOURCE);
  for (const token of ["firestore", "storage", "supplications", "audio/duas"]) {
    assert.equal(
      code.toLowerCase().includes(token.toLowerCase()),
      false,
      `${token} must not appear`,
    );
  }
});
