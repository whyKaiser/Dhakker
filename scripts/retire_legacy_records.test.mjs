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
  KNOWN_ARGUMENTS,
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

test("a manifest still awaiting its ids refuses to run at all", () => {
  // The state this file shipped in before the reconciliation report was
  // transcribed. It must stay a hard refusal: if the ids are ever cleared
  // out again, the tool goes back to doing nothing rather than to deleting
  // an empty set quietly.
  const read = () =>
    JSON.stringify({
      status: "awaiting_ids",
      sourceCollection: SOURCE_COLLECTION,
      archiveCollection: ARCHIVE_COLLECTION,
      expectedCount: 16,
      documentIds: [],
    });
  assert.throws(() => loadManifest("x", read), /status "awaiting_ids", not "ready"/);
});

test("only the literal status 'ready' unlocks the tool", () => {
  for (const status of ["", "READY", " ready", "yes", "true", null, undefined]) {
    const read = () =>
      JSON.stringify({
        status,
        sourceCollection: SOURCE_COLLECTION,
        archiveCollection: ARCHIVE_COLLECTION,
        expectedCount: 1,
        documentIds: ["a"],
      });
    assert.throws(() => loadManifest("x", read), /not "ready"/, `status ${JSON.stringify(status)} was accepted`);
  }
});

test("the committed manifest declares the collections the tool is compiled with", () => {
  const raw = JSON.parse(readFileSync(MANIFEST_PATH, "utf8"));
  assert.equal(raw.status, "ready");
  assert.equal(raw.expectedCount, 16);
  assert.equal(raw.documentIds.length, 16);
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

// ---------------------------------------------------------------------------
// The live manifest.
//
// From here the manifest is no longer a template: it names the 16 documents
// the production reconciliation of 2026-08-28 found in `supplications` that
// nothing in the source pack accounts for. These ids are the ONLY thing
// standing between this tool and a production collection, so the list is
// restated here independently and compared literally. If the two ever drift,
// one of them was edited without the other being looked at.

/** Transcribed independently of review/legacy_retirement_manifest.json, from
 *  the same reconciliation report. Order and case are significant:
 *  Firestore ids are case-sensitive. */
const LIVE_IDS = [
  "AdFPibtyp2hgUSiTGTlM",
  "D_MAQAM_01",
  "D_MARWAH_01",
  "D_SAFA_01",
  "D_TAWAF_01",
  "KrtoO8fVJ7efRTfm4qEL",
  "VJb72ru1SIxmT8HKRDMW",
  "fXwYcLDK3jLELDWb7XFb",
  "fah8Mp6J6iL0QpKKMQzB",
  "i8MeSW37qmpxOOsQ6OKn",
  "kry2IEcopLzT8Cqb2eYx",
  "mtKhdmU0JtS4fQ0IxgPR",
  "shQFcZYJ1FjvrSbCnqkp",
  "tqYFWXC1CISbU4Ey1m7C",
  "vCw2sYNEtILJkpp7ljti",
  "wVAQ2mYygE0kDT4BH1rx",
];

const live = () => loadManifest();

test("the manifest is ready and holds exactly 16 ids", () => {
  const m = live();
  assert.equal(m.ids.length, 16);
  assert.equal(m.expectedCount, 16);
  assert.equal(m.idSet.size, 16);
});

test("the manifest matches the reconciliation list literally, in order", () => {
  // deepEqual on the arrays, not the sets: a reordering would still be the
  // same documents, but it would also mean someone rewrote the file by hand,
  // and that is worth failing on.
  assert.deepEqual([...live().ids], LIVE_IDS);
  // And byte-exact, so a homoglyph or a stray zero-width character cannot
  // pass as a match.
  assert.equal(JSON.stringify([...live().ids]), JSON.stringify(LIVE_IDS));
});

test("no id is duplicated, in any letter case", () => {
  const ids = [...live().ids];
  assert.equal(new Set(ids).size, 16, "a duplicate id is present");
  // Firestore ids are case-sensitive, so two ids differing only in case are
  // legal — but they would almost certainly be a transcription slip.
  const lowered = ids.map((i) => i.toLowerCase());
  assert.equal(new Set(lowered).size, 16, "two ids differ only by letter case");
});

test("no id is empty, blank, a wildcard, a prefix or a path", () => {
  for (const id of live().ids) {
    assert.equal(typeof id, "string");
    assert.notEqual(id.trim(), "", "an empty or blank id");
    assert.equal(id, id.trim(), `${id} has surrounding whitespace`);
    for (const meta of ["*", "?", "**", "/", "\\", "..", "%", "[", "]", "{", "}"]) {
      assert.ok(!id.includes(meta), `${id} contains the metacharacter ${meta}`);
    }
    // A plain, complete Firestore document id: letters, digits, - and _.
    assert.match(id, /^[A-Za-z0-9_-]+$/, `${id} is not a plain document id`);
    assert.ok(id.length >= 8, `${id} is short enough to look like a prefix`);
  }
});

test("no id is a prefix of another, so none can stand in for a range", () => {
  const ids = [...live().ids];
  for (const a of ids) {
    for (const b of ids) {
      if (a === b) continue;
      assert.ok(!b.startsWith(a), `${a} is a prefix of ${b}`);
    }
  }
});

test("the manifest's ids are disjoint from the source pack, as reconciled", () => {
  // The reconciliation reported expected_and_present: 0 — production and the
  // pack share nothing. If an id here also appeared in the pack, the two
  // statements would contradict each other and the deletion would be
  // removing a record the ledger cleared.
  const pack = JSON.parse(
    readFileSync("source_packs/moia_mukhtasar_1446_umrah.json", "utf8"),
  );
  const packIds = new Set((pack.records ?? []).map((r) => r.duaId));
  for (const id of live().ids) {
    assert.ok(!packIds.has(id), `${id} is in the source pack; it must not be deleted`);
  }
});

// ── The CLI cannot add an id ─────────────────────────────────────────────

test("no CLI argument can introduce an id — each is refused outright", () => {
  const argv = (...a) => ["node", "retire_legacy_records.mjs", ...a];
  const attempts = [
    ["--phase=archive", "--id=intruder-01"],
    ["--phase=delete", "--ids=intruder-01,intruder-02"],
    ["--phase=delete", "intruder-01"],
    ["--phase=archive", "--document=intruder-01"],
    ["--phase=delete", "--manifest=/tmp/other.json"],
    ["--phase=delete", "--all"],
    ["--phase=delete", "--limit=999"],
  ];
  for (const args of attempts) {
    // Refused, not ignored: the run ends rather than quietly doing something
    // other than what was typed.
    assert.throws(
      () => resolvePlan(argv(...args), {}),
      /Unrecognised argument\(s\)/,
      `not refused: ${args.join(" ")}`,
    );
    // And the manifest is unchanged by any of it.
    assert.deepEqual([...loadManifest().ids], LIVE_IDS);
  }
});

test("the plan has no field an argument could put an id into", () => {
  const plan = resolvePlan(["node", "retire_legacy_records.mjs", "--phase=archive"], {});
  assert.deepEqual(
    Object.keys(plan).sort(),
    ["database", "execute", "phase", "projectId", "token"],
  );
});

test("an unrecognised argument is refused with a message naming it", () => {
  const argv = (...a) => ["node", "retire_legacy_records.mjs", ...a];
  for (const bad of [
    "--dry-run",
    "--force",
    "--yes",
    "--only=D_SAFA_01",
    "--exclude=D_SAFA_01",
    "--collection=users",
    "--archive-collection=elsewhere",
    "-e",
    "--Execute",
    "--EXECUTE",
    "--execute=true",
    "supplications",
    "",
  ]) {
    let message = "";
    assert.throws(
      () => resolvePlan(argv("--phase=archive", bad), {}),
      (err) => {
        message = err.message;
        return /Unrecognised argument\(s\)/.test(message);
      },
      `${JSON.stringify(bad)} was accepted`,
    );
    assert.ok(message.includes(bad), `the error does not name ${JSON.stringify(bad)}`);
    // The message must tell the operator what IS accepted.
    assert.match(message, /Accepted arguments: --phase=<archive\|delete>, --execute/);
    assert.match(message, /come only from\s+review\/legacy_retirement_manifest\.json/);
  }
});

test("--execute is matched exactly, so a near-miss cannot silently dry-run", () => {
  const argv = (...a) => ["node", "retire_legacy_records.mjs", ...a];
  // Each of these once would have been ignored, leaving the operator with a
  // dry run they believed was a real one.
  for (const near of ["--execute=true", "--Execute", "--exec", "-x", "execute"]) {
    assert.throws(() => resolvePlan(argv("--phase=delete", near), {}), /Unrecognised argument/);
  }
});

test("a repeated argument is refused rather than resolved to the first", () => {
  const argv = (...a) => ["node", "retire_legacy_records.mjs", ...a];
  // Two phases is two intentions. Honouring the first silently would run the
  // archive when the operator's last word was delete, or the reverse.
  assert.throws(
    () => resolvePlan(argv("--phase=archive", "--phase=delete"), {}),
    /--phase was given 2 times: --phase=archive, --phase=delete/,
  );
  assert.throws(
    () => resolvePlan(argv("--phase=delete", "--execute", "--execute"), {}),
    /--execute was given 2 times/,
  );
});

test("the two accepted argument forms still work, in either order", () => {
  const argv = (...a) => ["node", "retire_legacy_records.mjs", ...a];
  const env = {
    CONFIRM_RETIREMENT: "RETIRE_LEGACY_RECORDS",
    FIREBASE_PROJECT_ID: "p",
    FIREBASE_ADMIN_TOKEN: "t",
  };
  for (const args of [
    ["--phase=archive"],
    ["--phase=delete"],
    ["--phase=archive", "--execute"],
    ["--execute", "--phase=delete"],
  ]) {
    const plan = resolvePlan(argv(...args), env);
    assert.ok(PHASES.includes(plan.phase));
    assert.equal(plan.execute, args.includes("--execute"));
  }
});

test("KNOWN_ARGUMENTS is the whole accepted surface, and matches the phases", () => {
  assert.deepEqual([...KNOWN_ARGUMENTS], ["--phase=<archive|delete>", "--execute"]);
  for (const p of PHASES) {
    assert.ok(KNOWN_ARGUMENTS[0].includes(p), `phase ${p} is missing from the usage line`);
  }
});

test("the tool reads the manifest from a fixed path, not from an argument", () => {
  assert.equal(MANIFEST_PATH, "review/legacy_retirement_manifest.json");
  // main() calls loadManifest() with no argument, so the path cannot be
  // redirected by anything the operator types.
  assert.match(SCRIPT, /const manifest = loadManifest\(\);/);
});

// ── A dry-run archive against the live manifest ──────────────────────────

test("a dry-run archive targets exactly these 16 and writes nothing", async () => {
  const m = live();
  // A collection holding the 16 plus plausible bystanders.
  const source = new Map(m.ids.map((id) => [id, legacyFields(id)]));
  for (const bystander of ["D_TAWAF_02", "umrah-talbiyah", "AdFPibtyp2hgUSiTGTlN"]) {
    source.set(bystander, legacyFields(bystander));
  }
  const fs = fakeFirestore({ source });
  const { log, output } = captured();

  await runArchivePhase({ ...PLAN, execute: false }, m, { fetch: fs.fetch, log });

  const contacted = [...new Set(fs.calls.map((c) => c.id))].sort();
  assert.deepEqual(contacted, [...LIVE_IDS].sort(), "the dry run contacted the wrong set");
  assert.equal(contacted.length, 16);

  for (const method of ["POST", "PATCH", "PUT", "DELETE"]) {
    assert.equal(fs.calls.filter((c) => c.method === method).length, 0, `a dry run issued a ${method}`);
  }
  assert.equal(fs.store.archive.size, 0, "a dry run created an archive document");
  assert.equal(fs.store.source.size, 19, "a dry run removed a document");

  // Every one of the 16 is named in the report, and no bystander is.
  for (const id of LIVE_IDS) assert.ok(output().includes(id), `${id} missing from the report`);
  for (const b of ["D_TAWAF_02", "umrah-talbiyah", "AdFPibtyp2hgUSiTGTlN"]) {
    assert.ok(!output().includes(b), `bystander ${b} appeared in the report`);
  }
});

test("a dry-run archive against the live manifest contacts only Firestore", async () => {
  const m = live();
  const urls = [];
  const inner = fakeFirestore({ source: new Map(m.ids.map((id) => [id, legacyFields(id)])) });
  const spy = async (url, init) => {
    urls.push(url);
    return inner.fetch(url, init);
  };
  const { log } = captured();
  await runArchivePhase({ ...PLAN, execute: false }, m, { fetch: spy, log });

  assert.equal(urls.length, 32, "16 source reads + 16 archive pre-checks");
  for (const url of urls) {
    assert.ok(url.startsWith("https://firestore.googleapis.com/v1/projects/"), `left Firestore: ${url}`);
    for (const host of FORBIDDEN_HOSTS) {
      assert.ok(!url.includes(host), `a request reached ${host}`);
    }
  }
});

test("the live 16 archive, verify and delete without touching Storage", async () => {
  const m = live();
  const urls = [];
  const inner = fakeFirestore({ source: new Map(m.ids.map((id) => [id, legacyFields(id)])) });
  const spy = async (url, init) => {
    urls.push(url);
    return inner.fetch(url, init);
  };
  const { log } = captured();

  await runArchivePhase(PLAN, m, { fetch: spy, log });
  const result = await runDeletePhase({ ...PLAN, phase: "delete" }, m, { fetch: spy, log });

  assert.equal(result.deleted, 16);
  assert.equal(inner.store.source.size, 0);
  assert.equal(inner.store.archive.size, 16);
  for (const id of LIVE_IDS) {
    assert.ok(fieldsMatch(inner.store.archive.get(id), legacyFields(id)), `${id} was altered`);
  }
  for (const url of urls) {
    assert.ok(url.startsWith("https://firestore.googleapis.com/v1/projects/"), `left Firestore: ${url}`);
    for (const host of FORBIDDEN_HOSTS) assert.ok(!url.includes(host));
  }
});
