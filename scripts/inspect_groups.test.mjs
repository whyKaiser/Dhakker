// Guard tests for the groups inspection tool.
//
// Two properties matter more than the report itself:
//
//   * it never writes — every request it makes is a GET, to Firestore only;
//   * it never prints a join code — the code IS the secret the whole of #33
//     exists to protect, and a job summary is read by more people than the
//     database is.
//
// Both are asserted against the requests and the output this file actually
// produces, not against its comments.

import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  GROUPS_COLLECTION,
  GROUP_CODES_COLLECTION,
  KNOWN_ARGUMENTS,
  REPORT_FIELDS,
  FORBIDDEN_HOSTS,
  assertOnlyKnownArguments,
  documentIdOf,
  presentString,
  reportRow,
  formatRow,
  listDocuments,
  inspectGroups,
  printReport,
} from "./inspect_groups.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const source = fs.readFileSync(path.join(here, "inspect_groups.mjs"), "utf8");

/**
 * The source with comments removed.
 *
 * The file DESCRIBES what it refuses to do ("no PATCH, no POST…"), so a
 * naive scan matches its own prose. Scanning the code alone is the point:
 * the question is what it executes, not what it says.
 */
const code = source
  .replace(/\/\*[\s\S]*?\*\//g, "")
  .split("\n")
  .filter((l) => !l.trim().startsWith("//"))
  .join("\n");

const SECRET_CODE = "HAJJ-4821";

/** A Firestore REST group document. */
function groupDoc(id, { code = SECRET_CODE, ownerId = "owner-1" } = {}) {
  const fields = { ownerId: { stringValue: ownerId } };
  if (code !== null) fields.code = { stringValue: code };
  return {
    name: `projects/p/databases/(default)/documents/groups/${id}`,
    fields,
  };
}

function pointerDoc(code) {
  return {
    name: `projects/p/databases/(default)/documents/group_codes/${code}`,
    fields: { groupId: { stringValue: "g1" } },
  };
}

/**
 * A fake Firestore that records every request, so a write cannot pass
 * unnoticed. Returns groups for one collection and pointers for the other.
 */
function fakeFirestore({ groups = [], pointers = [], status = 200 } = {}) {
  const requests = [];
  const fetch = async (url, init = {}) => {
    requests.push({ url, method: init.method ?? "GET", init });
    if (status !== 200) {
      return { ok: false, status, json: async () => ({}) };
    }
    const documents = url.includes(`/documents/${GROUP_CODES_COLLECTION}`)
      ? pointers
      : groups;
    return { ok: true, status: 200, json: async () => ({ documents }) };
  };
  return { fetch, requests };
}

const PLAN = { projectId: "p", database: "(default)", token: "t" };

// ── It cannot write ───────────────────────────────────────────────────────

test("every request it issues is a GET", async () => {
  const fs_ = fakeFirestore({ groups: [groupDoc("g1")], pointers: [] });
  await inspectGroups(PLAN, { fetch: fs_.fetch });

  assert.ok(fs_.requests.length > 0, "it made no request at all");
  for (const r of fs_.requests) {
    assert.equal(r.method, "GET", `non-GET request: ${r.method} ${r.url}`);
    assert.equal(r.init.body, undefined, "a request carried a body");
  }
});

test("no write verb appears anywhere in the executable source", () => {
  // The tool has no write path. This fails if one is ever added.
  for (const verb of ["PATCH", "POST", "DELETE", "PUT"]) {
    assert.equal(
      new RegExp(`["']${verb}["']`).test(code),
      false,
      `${verb} appears in the code`,
    );
  }
  // The strings exist only in the two places that REFUSE them: the accepted
  // argument list and the rejection message.
  assert.equal(
    (code.match(/--write/g) || []).length,
    0,
    "--write appears in the code",
  );
  assert.equal((code.match(/--execute/g) || []).length, 0);
});

test("the comment-stripping the scan relies on actually works", () => {
  // If the stripper silently returned the whole file, the scan above would
  // pass for the wrong reason forever.
  assert.ok(source.includes("no PATCH, no POST"), "fixture comment missing");
  assert.equal(code.includes("no PATCH, no POST"), false, "comments not stripped");
  assert.ok(code.includes("listDocuments"), "the stripper ate the code");
});

test("it contacts Firestore only, never Cloud Storage", async () => {
  const fs_ = fakeFirestore({ groups: [groupDoc("g1")] });
  await inspectGroups(PLAN, { fetch: fs_.fetch });

  for (const r of fs_.requests) {
    assert.ok(
      r.url.startsWith("https://firestore.googleapis.com/"),
      `unexpected host: ${r.url}`,
    );
    for (const host of FORBIDDEN_HOSTS) {
      assert.equal(r.url.includes(host), false, `contacted ${host}`);
    }
  }
});

test("it reads only the two collections it needs", async () => {
  // Members hold live GPS coordinates. Nothing here needs them.
  const fs_ = fakeFirestore({ groups: [groupDoc("g1")] });
  await inspectGroups(PLAN, { fetch: fs_.fetch });

  for (const r of fs_.requests) {
    const isGroups = r.url.includes(`/documents/${GROUPS_COLLECTION}?`);
    const isCodes = r.url.includes(`/documents/${GROUP_CODES_COLLECTION}?`);
    assert.ok(isGroups || isCodes, `unexpected collection: ${r.url}`);
    assert.equal(r.url.includes("/members"), false, "it read member documents");
  }
});

// ── It cannot leak the join code ──────────────────────────────────────────

test("the report shape carries no code field", () => {
  assert.equal(REPORT_FIELDS.includes("code"), false);
  assert.equal(REPORT_FIELDS.includes("joinCode"), false);
  const row = reportRow(groupDoc("g1"), new Set());
  assert.deepEqual(Object.keys(row).sort(), [...REPORT_FIELDS].sort());
});

test("no printed line contains the join code", async () => {
  const fs_ = fakeFirestore({
    groups: [groupDoc("g1"), groupDoc("g2", { code: "HAJJ-9999" })],
    pointers: [pointerDoc(SECRET_CODE)],
  });
  const result = await inspectGroups(PLAN, { fetch: fs_.fetch });

  const lines = [];
  printReport(result, (l) => lines.push(l));
  const out = lines.join("\n");

  assert.equal(out.includes(SECRET_CODE), false, "a join code was printed");
  assert.equal(out.includes("HAJJ-9999"), false, "a join code was printed");
  assert.equal(/HAJJ-\d+/.test(out), false, "something code-shaped was printed");
  // …while still saying what the operator needs to know.
  assert.ok(out.includes("g1") && out.includes("g2"));
});

test("a row renders presence, not values", () => {
  const line = formatRow(reportRow(groupDoc("g1"), new Set([SECRET_CODE])));
  assert.equal(line.includes(SECRET_CODE), false);
  assert.match(line, /code=present/);
  assert.match(line, /pointer=present/);
});

test("nothing from a member document can reach the report", () => {
  // Coordinates and names are never fetched, but assert the shape refuses
  // them even if a future edit passed one in.
  const doc = groupDoc("g1");
  doc.fields.lat = { doubleValue: 21.4225 };
  doc.fields.name = { stringValue: "عائلة فلان" };
  const line = formatRow(reportRow(doc, new Set()));

  assert.equal(line.includes("21.4"), false);
  assert.equal(line.includes("عائلة"), false);
});

// ── The verdict ───────────────────────────────────────────────────────────

test("an empty collection gives GROUPS_EMPTY", async () => {
  const fs_ = fakeFirestore({ groups: [], pointers: [] });
  const result = await inspectGroups(PLAN, { fetch: fs_.fetch });

  const lines = [];
  assert.equal(printReport(result, (l) => lines.push(l)), "GROUPS_EMPTY");
  assert.match(
    lines.join("\n"),
    /GROUPS_EMPTY — safe to deploy rules without migration/,
  );
});

test("any group at all gives GROUPS_PRESENT", async () => {
  const fs_ = fakeFirestore({ groups: [groupDoc("g1")], pointers: [] });
  const result = await inspectGroups(PLAN, { fetch: fs_.fetch });

  const lines = [];
  assert.equal(printReport(result, (l) => lines.push(l)), "GROUPS_PRESENT");
  assert.match(
    lines.join("\n"),
    /GROUPS_PRESENT — migration required before rules deploy/,
  );
});

test("a group that already has its pointer does not need one", async () => {
  const fs_ = fakeFirestore({
    groups: [groupDoc("g1")],
    pointers: [pointerDoc(SECRET_CODE)],
  });
  const result = await inspectGroups(PLAN, { fetch: fs_.fetch });

  assert.equal(result.groupCount, 1);
  assert.equal(result.needsPointer, 0);
  assert.equal(result.rows[0].hasPointer, true);
});

test("a group whose pointer is missing is counted", async () => {
  const fs_ = fakeFirestore({
    groups: [groupDoc("g1"), groupDoc("g2", { code: "HAJJ-0001" })],
    pointers: [pointerDoc(SECRET_CODE)],
  });
  const result = await inspectGroups(PLAN, { fetch: fs_.fetch });

  assert.equal(result.needsPointer, 1);
  assert.equal(result.rows.find((r) => r.documentId === "g2").needsPointer, true);
});

test("a group with no code is reported separately, not as migratable", async () => {
  // A pointer cannot be built for it, so calling it "needs a pointer" would
  // send the operator after something impossible.
  const fs_ = fakeFirestore({
    groups: [groupDoc("g1", { code: null })],
    pointers: [],
  });
  const result = await inspectGroups(PLAN, { fetch: fs_.fetch });

  assert.equal(result.withoutCode, 1);
  assert.equal(result.needsPointer, 0);

  const lines = [];
  printReport(result, (l) => lines.push(l));
  assert.match(lines.join("\n"), /carry no code at all/);
});

test("a blank code counts as absent", () => {
  const row = reportRow(groupDoc("g1", { code: "   " }), new Set());
  assert.equal(row.hasCode, false);
  assert.equal(row.needsPointer, false);
});

// ── Listing ───────────────────────────────────────────────────────────────

test("pagination is followed, so an empty verdict is never a partial read", async () => {
  // Reporting "no groups" after reading one page would be wrong exactly when
  // it matters most.
  let call = 0;
  const fetch = async (url) => {
    call++;
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
      json: async () => ({ documents: [groupDoc("g2")] }),
    };
  };

  const result = await inspectGroups(PLAN, { fetch });
  assert.equal(result.groupCount, 2);
  assert.ok(call >= 3);
});

test("a 404 means empty, not a crash", async () => {
  const fetch = async () => ({ ok: false, status: 404, json: async () => ({}) });
  const docs = await listDocuments(
    { ...PLAN, collection: GROUPS_COLLECTION },
    { fetch },
  );
  assert.deepEqual(docs, []);
});

test("any other HTTP failure is raised, not silently read as empty", async () => {
  // A 403 from a misconfigured reader must not be reported as GROUPS_EMPTY:
  // that would green-light a deploy that breaks joining.
  const fs_ = fakeFirestore({ status: 403 });
  await assert.rejects(
    inspectGroups(PLAN, { fetch: fs_.fetch }),
    /HTTP 403/,
  );
});

// ── Arguments ─────────────────────────────────────────────────────────────

test("--database is accepted", () => {
  assert.doesNotThrow(() => assertOnlyKnownArguments(["--database=(default)"]));
  assert.doesNotThrow(() => assertOnlyKnownArguments([]));
});

test("an unknown argument is refused, and the message says what exists", () => {
  assert.throws(() => assertOnlyKnownArguments(["--write"]), (err) => {
    assert.match(err.message, /Unrecognised argument\(s\): --write/);
    assert.match(err.message, /only reads/);
    return true;
  });
  assert.throws(() => assertOnlyKnownArguments(["--collection=members"]));
  assert.throws(() => assertOnlyKnownArguments(["--execute"]));
});

test("KNOWN_ARGUMENTS names no write or filter flag", () => {
  const joined = KNOWN_ARGUMENTS.join(" ");
  for (const flag of ["--write", "--execute", "--only", "--delete"]) {
    assert.equal(joined.includes(flag), false);
  }
});

// ── Small helpers ─────────────────────────────────────────────────────────

test("documentIdOf takes the last path segment", () => {
  assert.equal(documentIdOf("projects/p/databases/(default)/documents/groups/g1"), "g1");
  assert.equal(documentIdOf(""), "");
  assert.equal(documentIdOf(undefined), "");
});

test("presentString rejects blanks and non-strings", () => {
  assert.equal(presentString("x"), true);
  assert.equal(presentString("  "), false);
  assert.equal(presentString(""), false);
  assert.equal(presentString(null), false);
  assert.equal(presentString(7), false);
});

test("the report always states that nothing was written", async () => {
  const fs_ = fakeFirestore({ groups: [groupDoc("g1")] });
  const result = await inspectGroups(PLAN, { fetch: fs_.fetch });

  const lines = [];
  printReport(result, (l) => lines.push(l));
  const out = lines.join("\n");
  assert.match(out, /READ ONLY, nothing is written/);
  assert.match(out, /No document was written, created or deleted\./);
  assert.match(out, /Storage:   NOT CONTACTED/);
});
