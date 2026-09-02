// Guard tests for the legacy-retirement tool.
//
// This is the only script in the repository that can DELETE a production
// document, so the tests are about what it refuses, not what it achieves.
// Every case runs in-process against a fake Firestore that records each
// request; none of them can reach a network.

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  ARCHIVE_COLLECTION,
  FORBIDDEN_HOSTS,
  MANIFEST_PATH,
  PHASES,
  SOURCE_COLLECTION,
  assertDeletable,
  describeFields,
  fieldsMatch,
  loadManifest,
  resolvePlan,
  runArchivePhase,
  runDeletePhase,
  stableJson,
} from "./retire_legacy_records.mjs";

const SCRIPT = readFileSync("scripts/retire_legacy_records.mjs", "utf8");

const PLAN = {
  phase: "archive",
  execute: true,
  projectId: "test-project",
  database: "(default)",
  token: "FAKE-TOKEN-NEVER-LOGGED",
};

/** Sixteen ids, to match the reported finding — but the tool is never told
 *  the number, so the suite also runs other sizes. */
const IDS = Array.from({ length: 16 }, (_, i) => `legacy-${String(i).padStart(2, "0")}`);

function manifestOf(ids = IDS) {
  return {
    ids: Object.freeze([...ids]),
    idSet: new Set(ids),
    expectedCount: ids.length,
    reconciledAt: "2026-08-28T00:00:00.000Z",
    reconciliationRunUrl: null,
  };
}

/** Raw Firestore `fields` for a legacy document: no verificationStatus, no
 *  contentKind, audioMode=file and an audioUrl carrying a download token —
 *  exactly the shape the live report described. */
function legacyFields(id) {
  return {
    duaId: { stringValue: id },
    text: {
      mapValue: {
        fields: {
          ar: { stringValue: `نص ${id}` },
          en: { stringValue: `text ${id}` },
        },
      },
    },
    audioMode: { stringValue: "file" },
    audioUrl: {
      stringValue: `https://firebasestorage.googleapis.com/v0/b/x/o/${id}.mp3?token=SECRET-${id}`,
    },
    isActive: { booleanValue: true },
    usage_count: { integerValue: "7" },
  };
}

/**
 * A fake Firestore. `source` and `archive` are plain maps of id → fields.
 * Every request is recorded so a test can assert on ORDER, which is what
 * "copy before delete" actually means.
 */
function fakeFirestore({ source = new Map(), archive = new Map(), fail } = {}) {
  const calls = [];
  const collectionOf = (url) =>
    url.includes(`/${ARCHIVE_COLLECTION}`) ? "archive" : "source";
  const idOf = (url) =>
    decodeURIComponent(url.split("?")[0].split("/").pop() ?? "");
  const store = { source, archive };

  const fetch = async (url, init = {}) => {
    const method = init.method ?? "GET";
    const which = collectionOf(url);
    const id =
      method === "POST"
        ? decodeURIComponent(new URL(url).searchParams.get("documentId") ?? "")
        : idOf(url);
    calls.push({ method, collection: which, id });

    const forced = fail?.({ method, collection: which, id });
    if (forced) return { ok: false, status: forced, json: async () => ({}) };

    if (method === "GET") {
      const map = store[which];
      if (!map.has(id)) return { ok: false, status: 404, json: async () => ({}) };
      return { ok: true, status: 200, json: async () => ({ fields: map.get(id) }) };
    }
    if (method === "POST") {
      if (store.archive.has(id)) {
        return { ok: false, status: 409, json: async () => ({}) };
      }
      store.archive.set(id, JSON.parse(init.body).fields);
      return { ok: true, status: 200, json: async () => ({}) };
    }
    if (method === "DELETE") {
      store.source.delete(id);
      return { ok: true, status: 200, json: async () => ({}) };
    }
    throw new Error(`unexpected method ${method}`);
  };

  return { fetch, calls, store };
}

function populated(ids = IDS) {
  return new Map(ids.map((id) => [id, legacyFields(id)]));
}

const lines = [];
const collect = (...a) => lines.push(a.join(" "));
function captured() {
  lines.length = 0;
  return { log: collect, output: () => lines.join("\n") };
}

// ── The manifest is the only allowlist ───────────────────────────────────

test("the committed manifest refuses to run: its ids have not been transcribed", () => {
  assert.throws(() => loadManifest(), /status "awaiting_ids", not "ready"/);
});

test("the committed manifest declares the reported count and no ids", () => {
  const raw = JSON.parse(readFileSync(MANIFEST_PATH, "utf8"));
  assert.equal(raw.expectedCount, 16);
  assert.deepEqual(raw.documentIds, []);
  assert.equal(raw.sourceCollection, SOURCE_COLLECTION);
  assert.equal(raw.archiveCollection, ARCHIVE_COLLECTION);
});

test("a manifest whose two counts disagree is refused", () => {
  const read = () =>
    JSON.stringify({
      status: "ready",
      sourceCollection: SOURCE_COLLECTION,
      archiveCollection: ARCHIVE_COLLECTION,
      expectedCount: 16,
      documentIds: ["a", "b"],
    });
  assert.throws(() => loadManifest("x", read), /expectedCount is 16 but documentIds has 2/);
});

test("a manifest naming another collection is refused", () => {
  const read = () =>
    JSON.stringify({
      status: "ready",
      sourceCollection: "users",
      archiveCollection: ARCHIVE_COLLECTION,
      expectedCount: 1,
      documentIds: ["a"],
    });
  assert.throws(() => loadManifest("x", read), /sourceCollection must be "supplications"/);
});

test("duplicate, empty and path-like ids are refused", () => {
  const build = (documentIds) => () =>
    JSON.stringify({
      status: "ready",
      sourceCollection: SOURCE_COLLECTION,
      archiveCollection: ARCHIVE_COLLECTION,
      expectedCount: documentIds.length,
      documentIds,
    });
  assert.throws(() => loadManifest("x", build(["a", "a"])), /duplicates/);
  assert.throws(() => loadManifest("x", build(["a", ""])), /non-id entry/);
  assert.throws(() => loadManifest("x", build(["users/admin"])), /unusable id/);
  assert.throws(() => loadManifest("x", build([".."])), /unusable id/);
  assert.throws(() => loadManifest("x", build([])), /non-empty array/);
});

test("assertDeletable refuses any id the manifest does not name", () => {
  const m = manifestOf(["keep-01"]);
  assert.doesNotThrow(() => assertDeletable("keep-01", m));
  for (const other of ["keep-02", "umrah-talbiyah", "", "KEEP-01"]) {
    assert.throws(() => assertDeletable(other, m), /not in review\/legacy_retirement_manifest\.json/);
  }
});

// ── Copy before delete ───────────────────────────────────────────────────

test("the archive phase issues no DELETE at all", async () => {
  const fs = fakeFirestore({ source: populated() });
  const { log } = captured();
  await runArchivePhase(PLAN, manifestOf(), { fetch: fs.fetch, log });
  assert.equal(fs.calls.filter((c) => c.method === "DELETE").length, 0);
  assert.equal(fs.store.source.size, 16, "the archive phase removed a source document");
  assert.equal(fs.store.archive.size, 16);
});

test("every id is archived and verified before the first delete is issued", async () => {
  const source = populated();
  const fs = fakeFirestore({ source });
  const { log } = captured();

  await runArchivePhase({ ...PLAN, phase: "archive" }, manifestOf(), { fetch: fs.fetch, log });
  await runDeletePhase({ ...PLAN, phase: "delete" }, manifestOf(), { fetch: fs.fetch, log });

  const firstDelete = fs.calls.findIndex((c) => c.method === "DELETE");
  assert.ok(firstDelete > 0, "no delete was issued");

  // Every archive write, and every verifying read of the archive, happens
  // before any delete. This is the ordering guarantee, asserted directly on
  // the request log rather than inferred from the code.
  const posts = fs.calls.filter((c) => c.method === "POST");
  assert.equal(posts.length, 16);
  for (const p of posts) {
    assert.ok(fs.calls.indexOf(p) < firstDelete, "an archive write happened after a delete");
  }
  const archiveReads = fs.calls.filter(
    (c) => c.method === "GET" && c.collection === "archive",
  );
  assert.equal(archiveReads.length, 48, "16 pre-checks + 16 verifications + 16 re-verifications");

  assert.equal(fs.store.source.size, 0);
  assert.equal(fs.store.archive.size, 16);
});

test("the copy matches the original field for field, including the audio URL", async () => {
  const source = populated();
  const fs = fakeFirestore({ source });
  const { log } = captured();
  await runArchivePhase(PLAN, manifestOf(), { fetch: fs.fetch, log });

  for (const id of IDS) {
    assert.ok(fieldsMatch(fs.store.archive.get(id), legacyFields(id)), `${id} was altered in the copy`);
    // The archive is a full copy: the URL string is preserved so the audio
    // can be reattached later. It is the LOG that must not carry it.
    assert.equal(
      fs.store.archive.get(id).audioUrl.stringValue,
      legacyFields(id).audioUrl.stringValue,
    );
  }
});

test("a copy that does not match aborts the archive phase", async () => {
  const source = populated(["a"]);
  const fs = fakeFirestore({ source });
  // The archive already holds a DIFFERENT document under the same id.
  fs.store.archive.set("a", { duaId: { stringValue: "something-else" } });
  const { log } = captured();
  await assert.rejects(
    runArchivePhase(PLAN, manifestOf(["a"]), { fetch: fs.fetch, log }),
    /already exists and does NOT match/,
  );
  assert.equal(fs.calls.filter((c) => c.method === "POST").length, 0);
});

test("nothing is deleted when a single archive copy is missing", async () => {
  const source = populated(IDS);
  const fs = fakeFirestore({ source });
  const { log } = captured();
  await runArchivePhase(PLAN, manifestOf(), { fetch: fs.fetch, log });

  // Lose exactly one copy — the last one, so a naive implementation would
  // already have deleted the other fifteen by the time it noticed.
  fs.store.archive.delete(IDS[15]);
  fs.calls.length = 0;

  await assert.rejects(
    runDeletePhase({ ...PLAN, phase: "delete" }, manifestOf(), { fetch: fs.fetch, log }),
    /has no copy in supplications_legacy_archive/,
  );
  assert.equal(fs.calls.filter((c) => c.method === "DELETE").length, 0);
  assert.equal(fs.store.source.size, 16, "a document was deleted despite the abort");
});

test("nothing is deleted when a copy exists but differs", async () => {
  const fs = fakeFirestore({ source: populated(IDS) });
  const { log } = captured();
  await runArchivePhase(PLAN, manifestOf(), { fetch: fs.fetch, log });
  fs.store.archive.set(IDS[3], { duaId: { stringValue: "tampered" } });
  fs.calls.length = 0;

  await assert.rejects(
    runDeletePhase({ ...PLAN, phase: "delete" }, manifestOf(), { fetch: fs.fetch, log }),
    /archive copy does not match/,
  );
  assert.equal(fs.calls.filter((c) => c.method === "DELETE").length, 0);
  assert.equal(fs.store.source.size, 16);
});

// ── Exactly the manifest, and nothing else ───────────────────────────────

test("a source document outside the manifest is neither read, copied nor deleted", async () => {
  const source = populated(IDS);
  source.set("bystander-01", legacyFields("bystander-01"));
  source.set("umrah-talbiyah", legacyFields("umrah-talbiyah"));
  const fs = fakeFirestore({ source });
  const { log } = captured();

  await runArchivePhase(PLAN, manifestOf(), { fetch: fs.fetch, log });
  await runDeletePhase({ ...PLAN, phase: "delete" }, manifestOf(), { fetch: fs.fetch, log });

  for (const bystander of ["bystander-01", "umrah-talbiyah"]) {
    assert.ok(fs.store.source.has(bystander), `${bystander} was deleted`);
    assert.ok(!fs.store.archive.has(bystander), `${bystander} was archived`);
    assert.equal(
      fs.calls.filter((c) => c.id === bystander).length,
      0,
      `${bystander} was contacted at all`,
    );
  }
  assert.equal(fs.store.source.size, 2, "only the two bystanders should remain");
});

test("exactly as many deletes as manifest ids — no more, for any count", async () => {
  for (const n of [1, 5, 16, 30]) {
    const ids = IDS.slice(0, 1).concat(
      Array.from({ length: n - 1 }, (_, i) => `extra-${i}`),
    );
    const source = populated(ids);
    source.set("not-in-manifest", legacyFields("not-in-manifest"));
    const fs = fakeFirestore({ source });
    const { log } = captured();
    await runArchivePhase(PLAN, manifestOf(ids), { fetch: fs.fetch, log });
    await runDeletePhase({ ...PLAN, phase: "delete" }, manifestOf(ids), { fetch: fs.fetch, log });

    const deletes = fs.calls.filter((c) => c.method === "DELETE");
    assert.equal(deletes.length, n, `${n} ids produced ${deletes.length} deletes`);
    assert.deepEqual([...new Set(deletes.map((d) => d.id))].sort(), [...ids].sort());
    assert.ok(fs.store.source.has("not-in-manifest"));
  }
});

test("a delete is refused even if an id reaches the delete call directly", async () => {
  const { deleteSource } = await import("./retire_legacy_records.mjs");
  const fs = fakeFirestore({ source: populated(["a"]) });
  await assert.rejects(
    deleteSource(PLAN, "a", manifestOf(["b"]), { fetch: fs.fetch }),
    /Refusing to delete "a"/,
  );
  assert.equal(fs.calls.length, 0, "a refused delete still issued a request");
});

// ── Storage is never contacted ───────────────────────────────────────────

test("no request in either phase goes anywhere but Firestore", async () => {
  const urls = [];
  const inner = fakeFirestore({ source: populated() });
  const spy = async (url, init) => {
    urls.push(url);
    return inner.fetch(url, init);
  };
  const { log } = captured();
  await runArchivePhase(PLAN, manifestOf(), { fetch: spy, log });
  await runDeletePhase({ ...PLAN, phase: "delete" }, manifestOf(), { fetch: spy, log });

  assert.ok(urls.length > 0);
  for (const url of urls) {
    assert.ok(
      url.startsWith("https://firestore.googleapis.com/v1/projects/"),
      `a request left Firestore: ${url}`,
    );
    for (const host of FORBIDDEN_HOSTS) {
      assert.ok(!url.includes(host), `a request reached ${host}`);
    }
  }
});

test("the script's own source names no Storage host and no Storage API", () => {
  for (const host of FORBIDDEN_HOSTS) {
    // The constant list itself is the one legitimate mention.
    const withoutList = SCRIPT.replace(/export const FORBIDDEN_HOSTS[\s\S]*?\]\);/, "");
    assert.ok(!withoutList.includes(host), `the script references ${host}`);
  }
  for (const api of ["storage.objects", "getSignedUrl", "@google-cloud/storage", "firebase-admin/storage"]) {
    assert.ok(!SCRIPT.includes(api), `the script references ${api}`);
  }
});

test("the log carries field names and ids, never a field value", async () => {
  const fs = fakeFirestore({ source: populated() });
  const { log, output } = captured();
  await runArchivePhase(PLAN, manifestOf(), { fetch: fs.fetch, log });
  await runDeletePhase({ ...PLAN, phase: "delete" }, manifestOf(), { fetch: fs.fetch, log });
  const out = output();

  assert.ok(out.includes("legacy-00"), "the log should name the ids it acted on");
  assert.ok(out.includes("audioUrl"), "the log should name the fields it copied");
  for (const secret of ["SECRET-legacy-00", "firebasestorage.googleapis.com", "نص legacy-00", PLAN.token]) {
    assert.ok(!out.includes(secret), `the log printed: ${secret}`);
  }
});

test("describeFields lists names only", () => {
  const d = describeFields(legacyFields("x"));
  assert.match(d, /6 field\(s\)/);
  assert.match(d, /audioUrl/);
  assert.ok(!d.includes("SECRET"));
});

// ── Dry run is the default ───────────────────────────────────────────────

test("a dry-run archive writes nothing", async () => {
  const dry = { ...PLAN, execute: false };
  const fs = fakeFirestore({ source: populated() });
  const { log } = captured();

  await runArchivePhase(dry, manifestOf(), { fetch: fs.fetch, log });

  for (const method of ["POST", "PATCH", "PUT", "DELETE"]) {
    assert.equal(
      fs.calls.filter((c) => c.method === method).length,
      0,
      `a dry run issued a ${method}`,
    );
  }
  assert.equal(fs.store.archive.size, 0);
  assert.equal(fs.store.source.size, 16);
});

test("a dry-run delete deletes nothing, even with every copy in place", async () => {
  const fs = fakeFirestore({ source: populated() });
  const { log } = captured();
  await runArchivePhase(PLAN, manifestOf(), { fetch: fs.fetch, log });
  fs.calls.length = 0;

  const result = await runDeletePhase(
    { ...PLAN, phase: "delete", execute: false },
    manifestOf(),
    { fetch: fs.fetch, log },
  );

  assert.equal(result.verified, 16);
  assert.equal(result.deleted, 0);
  for (const method of ["POST", "PATCH", "PUT", "DELETE"]) {
    assert.equal(fs.calls.filter((c) => c.method === method).length, 0);
  }
  assert.equal(fs.store.source.size, 16, "a dry run deleted a document");
});

test("a dry-run delete still refuses when nothing has been archived", async () => {
  const fs = fakeFirestore({ source: populated() });
  const { log } = captured();
  await assert.rejects(
    runDeletePhase({ ...PLAN, phase: "delete", execute: false }, manifestOf(), {
      fetch: fs.fetch,
      log,
    }),
    /has no copy in supplications_legacy_archive/,
  );
  assert.equal(fs.store.source.size, 16);
});

test("resolvePlan defaults to a dry run and demands the confirmation to execute", () => {
  const argv = (...a) => ["node", "retire_legacy_records.mjs", ...a];
  assert.equal(resolvePlan(argv("--phase=archive"), {}).execute, false);
  assert.equal(resolvePlan(argv("--phase=delete"), {}).execute, false);

  assert.throws(
    () => resolvePlan(argv("--phase=delete", "--execute"), { FIREBASE_PROJECT_ID: "p", FIREBASE_ADMIN_TOKEN: "t" }),
    /CONFIRM_RETIREMENT=RETIRE_LEGACY_RECORDS/,
  );
  const ok = resolvePlan(argv("--phase=delete", "--execute"), {
    CONFIRM_RETIREMENT: "RETIRE_LEGACY_RECORDS",
    FIREBASE_PROJECT_ID: "p",
    FIREBASE_ADMIN_TOKEN: "t",
  });
  assert.equal(ok.execute, true);
  assert.equal(ok.phase, "delete");
});

test("an unknown or missing phase is refused", () => {
  const argv = (...a) => ["node", "retire_legacy_records.mjs", ...a];
  for (const bad of [[], ["--phase="], ["--phase=purge"], ["--phase=prune"], ["--execute"]]) {
    assert.throws(() => resolvePlan(argv(...bad), {}), /--phase must be one of/);
  }
  assert.deepEqual([...PHASES], ["archive", "delete"]);
});

// ── Comparison primitives ────────────────────────────────────────────────

test("stableJson is key-order independent but value-exact", () => {
  assert.equal(stableJson({ a: 1, b: 2 }), stableJson({ b: 2, a: 1 }));
  assert.notEqual(stableJson({ a: 1 }), stableJson({ a: "1" }));
  assert.notEqual(stableJson([1, 2]), stableJson([2, 1]), "array order matters");
  // No normalisation: a differently-composed string is a different value.
  assert.notEqual(stableJson("آ"), stableJson("آ"));
});

test("fieldsMatch treats a missing document and an empty one alike", () => {
  assert.ok(fieldsMatch(undefined, {}));
  assert.ok(!fieldsMatch({ a: { stringValue: "x" } }, {}));
});

test("an id present in the manifest but missing from the collection aborts", async () => {
  const fs = fakeFirestore({ source: populated(["a"]) });
  const { log } = captured();
  await assert.rejects(
    runArchivePhase(PLAN, manifestOf(["a", "gone"]), { fetch: fs.fetch, log }),
    /is in the manifest but not in the collection/,
  );
});

test("a non-404 read error is not mistaken for an absent document", async () => {
  const fs = fakeFirestore({
    source: populated(["a"]),
    fail: ({ collection }) => (collection === "archive" ? 403 : null),
  });
  const { log } = captured();
  await assert.rejects(
    runArchivePhase(PLAN, manifestOf(["a"]), { fetch: fs.fetch, log }),
    /HTTP 403/,
  );
  assert.equal(fs.calls.filter((c) => c.method === "POST").length, 0);
});
