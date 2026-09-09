// Guard tests for the group_codes migration.
//
// This tool WRITES to production. The properties that matter:
//
//   * dry run is the default, and a dry run issues no write at all;
//   * it writes to `group_codes` and to nothing else — never to groups,
//     never to members (live GPS), never to supplications or the archive;
//   * creation is create-only, so a circulating code can never be repointed
//     at a different group;
//   * a group with no usable code is SKIPPED, never guessed at;
//   * no join code reaches the log.
//
// Every one is asserted against the requests and the output this file
// actually produces, not against its comments.

import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  GROUPS_COLLECTION,
  GROUP_CODES_COLLECTION,
  ALLOWED_WRITE_COLLECTION,
  KNOWN_ARGUMENTS,
  FORBIDDEN_HOSTS,
  assertOnlyKnownArguments,
  documentIdOf,
  isUsableAsDocumentId,
  planFor,
  pointerFields,
  createPointer,
  migrate,
} from "./migrate_group_codes.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const source = fs.readFileSync(
  path.join(here, "migrate_group_codes.mjs"),
  "utf8",
);

/** The source with comments removed — the file describes what it refuses. */
const code = source
  .replace(/\/\*[\s\S]*?\*\//g, "")
  .split("\n")
  .filter((l) => !l.trim().startsWith("//"))
  .join("\n");

const SECRET = "HAJJ-4821";
const PLAN = { projectId: "p", database: "(default)", token: "t" };

function groupDoc(id, { code = SECRET, ownerId = "owner-1" } = {}) {
  const fields = { ownerId: { stringValue: ownerId } };
  if (code !== null) fields.code = { stringValue: code };
  return {
    name: `projects/p/databases/(default)/documents/groups/${id}`,
    fields,
  };
}

function pointerDoc(c) {
  return {
    name: `projects/p/databases/(default)/documents/group_codes/${c}`,
    fields: { groupId: { stringValue: "g1" } },
  };
}

/** Records every request so a stray write cannot pass unnoticed. */
function fakeFirestore({ groups = [], pointers = [], createStatus = 200 } = {}) {
  const requests = [];
  const fetch = async (url, init = {}) => {
    const method = init.method ?? "GET";
    requests.push({ url, method, init });
    if (method === "POST") {
      return { ok: createStatus === 200, status: createStatus, json: async () => ({}) };
    }
    const documents = url.includes(`/documents/${GROUP_CODES_COLLECTION}`)
      ? pointers
      : groups;
    return { ok: true, status: 200, json: async () => ({ documents }) };
  };
  return { fetch, requests };
}

const quiet = () => {};

// ── Dry run is the default ────────────────────────────────────────────────

test("a dry run issues no write at all", async () => {
  const f = fakeFirestore({ groups: [groupDoc("g1"), groupDoc("g2", { code: "HAJJ-2" })] });
  const r = await migrate(PLAN, { fetch: f.fetch }, quiet);

  assert.equal(r.created, 0);
  for (const req of f.requests) {
    assert.equal(req.method, "GET", `dry run issued ${req.method}`);
  }
});

test("execute must be asked for explicitly", async () => {
  // The absence of --execute is what makes a dry run a dry run.
  const f = fakeFirestore({ groups: [groupDoc("g1")] });
  await migrate({ ...PLAN }, { fetch: f.fetch }, quiet);
  assert.equal(f.requests.filter((r) => r.method === "POST").length, 0);

  const f2 = fakeFirestore({ groups: [groupDoc("g1")] });
  await migrate({ ...PLAN, execute: true }, { fetch: f2.fetch }, quiet);
  assert.equal(f2.requests.filter((r) => r.method === "POST").length, 1);
});

test("a dry run says so, and says nothing was created", async () => {
  const lines = [];
  const f = fakeFirestore({ groups: [groupDoc("g1")] });
  await migrate(PLAN, { fetch: f.fetch }, (l) => lines.push(l));

  const out = lines.join("\n");
  assert.match(out, /DRY RUN, nothing is written/);
  assert.match(out, /no document was created/i);
});

// ── It writes to one collection only ──────────────────────────────────────

test("every write targets group_codes and nothing else", async () => {
  const f = fakeFirestore({ groups: [groupDoc("g1")] });
  await migrate({ ...PLAN, execute: true }, { fetch: f.fetch }, quiet);

  const writes = f.requests.filter((r) => r.method !== "GET");
  assert.ok(writes.length > 0, "no write was attempted");
  for (const w of writes) {
    assert.ok(
      w.url.includes(`/documents/${GROUP_CODES_COLLECTION}?documentId=`),
      `write went to ${w.url}`,
    );
    assert.equal(w.url.includes(`/documents/${GROUPS_COLLECTION}?`), false);
    assert.equal(w.url.includes("/members"), false, "it wrote to members");
    assert.equal(w.url.includes("supplications"), false);
  }
});

test("the write helper refuses any other collection", async () => {
  await assert.rejects(
    createPointer(
      { ...PLAN, collection: "groups" },
      SECRET,
      {},
      { fetch: async () => ({ ok: true, status: 200 }) },
    ),
    /refusing to write to groups/,
  );
});

test("ALLOWED_WRITE_COLLECTION is exactly group_codes", () => {
  assert.equal(ALLOWED_WRITE_COLLECTION, "group_codes");
});

test("it never contacts Cloud Storage", async () => {
  const f = fakeFirestore({ groups: [groupDoc("g1")] });
  await migrate({ ...PLAN, execute: true }, { fetch: f.fetch }, quiet);

  for (const r of f.requests) {
    assert.ok(r.url.startsWith("https://firestore.googleapis.com/"));
    for (const host of FORBIDDEN_HOSTS) {
      assert.equal(r.url.includes(host), false, `contacted ${host}`);
    }
  }
});

test("no DELETE or PATCH appears in the executable source", () => {
  for (const verb of ["DELETE", "PATCH", "PUT"]) {
    assert.equal(new RegExp(`["']${verb}["']`).test(code), false, `${verb} present`);
  }
});

test("the comment stripping the scan relies on works", () => {
  assert.ok(source.includes("never to `members`"), "fixture comment missing");
  assert.equal(code.includes("never to `members`"), false);
  assert.ok(code.includes("createPointer"), "the stripper ate the code");
});

// ── Create-only ───────────────────────────────────────────────────────────

test("creation uses POST ?documentId=, which 409s on an existing document", async () => {
  const f = fakeFirestore({ groups: [groupDoc("g1")] });
  await migrate({ ...PLAN, execute: true }, { fetch: f.fetch }, quiet);

  const post = f.requests.find((r) => r.method === "POST");
  assert.match(post.url, /\?documentId=/);
});

test("a 409 is counted as already-existing, not an error", async () => {
  // Idempotence: a re-run after a partial migration must be safe.
  const f = fakeFirestore({ groups: [groupDoc("g1")], createStatus: 409 });
  const r = await migrate({ ...PLAN, execute: true }, { fetch: f.fetch }, quiet);

  assert.equal(r.created, 0);
  assert.equal(r.existed, 1);
});

test("any other create failure is raised, not swallowed", async () => {
  const f = fakeFirestore({ groups: [groupDoc("g1")], createStatus: 403 });
  await assert.rejects(
    migrate({ ...PLAN, execute: true }, { fetch: f.fetch }, quiet),
    /HTTP 403/,
  );
});

test("a group that already has its pointer is not rewritten", async () => {
  // Repointing a circulating code would redirect joiners into another group.
  const f = fakeFirestore({
    groups: [groupDoc("g1")],
    pointers: [pointerDoc(SECRET)],
  });
  const r = await migrate({ ...PLAN, execute: true }, { fetch: f.fetch }, quiet);

  assert.equal(r.created, 0);
  assert.equal(f.requests.filter((x) => x.method === "POST").length, 0);
});

// ── Codes it refuses to guess at ──────────────────────────────────────────

test("a group with no code is skipped, never invented", async () => {
  const f = fakeFirestore({ groups: [groupDoc("g1", { code: null })] });
  const r = await migrate({ ...PLAN, execute: true }, { fetch: f.fetch }, quiet);

  assert.equal(r.created, 0);
  assert.equal(f.requests.filter((x) => x.method === "POST").length, 0);
  assert.equal(r.plans[0].action, "no-code");
});

test("a blank code is treated as no code", () => {
  assert.equal(planFor(groupDoc("g1", { code: "   " }), new Set()).action, "no-code");
});

test("a code that cannot be a document id is skipped", () => {
  // A slash would silently create a nested path instead of a pointer.
  for (const bad of ["a/b", ".", "..", "x".repeat(1501)]) {
    const p = planFor(groupDoc("g1", { code: bad }), new Set());
    assert.equal(p.action, "bad-code", `accepted ${JSON.stringify(bad.slice(0, 12))}`);
  }
});

test("the write helper refuses an unusable code even if called directly", async () => {
  for (const bad of ["", "   ", "a/b", "."]) {
    await assert.rejects(
      createPointer(PLAN, bad, {}, { fetch: async () => ({ ok: true, status: 200 }) }),
      /unusable code/,
    );
  }
});

test("isUsableAsDocumentId", () => {
  assert.equal(isUsableAsDocumentId("HAJJ-1234"), true);
  assert.equal(isUsableAsDocumentId(" HAJJ-1234 "), true);
  assert.equal(isUsableAsDocumentId(""), false);
  assert.equal(isUsableAsDocumentId("a/b"), false);
  assert.equal(isUsableAsDocumentId("."), false);
  assert.equal(isUsableAsDocumentId(".."), false);
  assert.equal(isUsableAsDocumentId(null), false);
  assert.equal(isUsableAsDocumentId(7), false);
});

// ── The pointer body ──────────────────────────────────────────────────────

test("the pointer carries exactly the fields the rules read", async () => {
  const f = fakeFirestore({ groups: [groupDoc("g1", { ownerId: "owner-9" })] });
  await migrate({ ...PLAN, execute: true }, { fetch: f.fetch }, quiet);

  const body = JSON.parse(f.requests.find((r) => r.method === "POST").init.body);
  assert.deepEqual(Object.keys(body.fields).sort(), [
    "groupId",
    "migratedAt",
    "ownerId",
  ]);
  assert.equal(body.fields.groupId.stringValue, "g1");
  assert.equal(body.fields.ownerId.stringValue, "owner-9");
});

test("the pointer body never carries the code itself", () => {
  // The document is NAMED by the code; repeating it inside would put it in
  // one more place for no gain.
  const fields = pointerFields({ groupId: "g1", ownerId: "o" });
  assert.equal(JSON.stringify(fields).includes("HAJJ"), false);
  assert.equal("code" in fields, false);
});

// ── It cannot leak a join code ────────────────────────────────────────────

test("no printed line contains a join code", async () => {
  const lines = [];
  const f = fakeFirestore({
    groups: [
      groupDoc("g1"),
      groupDoc("g2", { code: "HAJJ-9999" }),
      groupDoc("g3", { code: null }),
    ],
    pointers: [pointerDoc(SECRET)],
  });
  await migrate({ ...PLAN, execute: true }, { fetch: f.fetch }, (l) => lines.push(l));

  const out = lines.join("\n");
  assert.equal(/HAJJ-\d+/.test(out), false, "a join code was printed");
  assert.ok(out.includes("g1") && out.includes("g2") && out.includes("g3"));
});

// ── Counting ──────────────────────────────────────────────────────────────

test("the plan separates the four outcomes", async () => {
  const f = fakeFirestore({
    groups: [
      groupDoc("ready", { code: "HAJJ-1" }),
      groupDoc("done", { code: "HAJJ-2" }),
      groupDoc("nocode", { code: null }),
      groupDoc("bad", { code: "a/b" }),
    ],
    pointers: [pointerDoc("HAJJ-2")],
  });
  const r = await migrate(PLAN, { fetch: f.fetch }, quiet);

  const by = (a) => r.plans.filter((p) => p.action === a).length;
  assert.equal(by("ready"), 1);
  assert.equal(by("done"), 1);
  assert.equal(by("no-code"), 1);
  assert.equal(by("bad-code"), 1);
});

test("pagination is followed, so no group is silently missed", async () => {
  const fetch = async (url) => {
    if (url.includes(GROUP_CODES_COLLECTION)) {
      return { ok: true, status: 200, json: async () => ({ documents: [] }) };
    }
    if (!url.includes("pageToken")) {
      return {
        ok: true,
        status: 200,
        json: async () => ({ documents: [groupDoc("g1")], nextPageToken: "T" }),
      };
    }
    return {
      ok: true,
      status: 200,
      json: async () => ({ documents: [groupDoc("g2", { code: "HAJJ-2" })] }),
    };
  };
  const r = await migrate(PLAN, { fetch }, quiet);
  assert.equal(r.plans.length, 2);
});

test("an empty groups collection is a no-op", async () => {
  const f = fakeFirestore({ groups: [], pointers: [] });
  const r = await migrate({ ...PLAN, execute: true }, { fetch: f.fetch }, quiet);

  assert.equal(r.created, 0);
  assert.equal(f.requests.filter((x) => x.method === "POST").length, 0);
});

// ── Arguments ─────────────────────────────────────────────────────────────

test("only --database and --execute are accepted", () => {
  assert.doesNotThrow(() => assertOnlyKnownArguments([]));
  assert.doesNotThrow(() => assertOnlyKnownArguments(["--execute"]));
  assert.doesNotThrow(() =>
    assertOnlyKnownArguments(["--database=(default)", "--execute"]),
  );
});

test("no argument can name, add or filter a code", () => {
  for (const bad of ["--code=HAJJ-1", "--only=g1", "--group=g1", "--force"]) {
    assert.throws(() => assertOnlyKnownArguments([bad]), /Unrecognised argument/);
  }
  assert.throws(() => assertOnlyKnownArguments(["--code=HAJJ-1"]), (err) => {
    assert.match(err.message, /nothing on the command line can name, add or/i);
    return true;
  });
});

test("KNOWN_ARGUMENTS names no way to select a document", () => {
  const joined = KNOWN_ARGUMENTS.join(" ");
  for (const flag of ["--code", "--only", "--group", "--force"]) {
    assert.equal(joined.includes(flag), false);
  }
});

test("documentIdOf takes the last segment", () => {
  assert.equal(
    documentIdOf("projects/p/databases/(default)/documents/groups/g1"),
    "g1",
  );
  assert.equal(documentIdOf(""), "");
});
