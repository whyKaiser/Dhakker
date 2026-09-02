#!/usr/bin/env node
//
// Retire legacy `supplications` documents: copy them to an archive
// collection, verify the copy, and only then delete the originals.
//
// ── Why this exists ──────────────────────────────────────────────────────
//
// The production reconciliation of 2026-08-28 reported no overlap at all
// between the live collection and the source pack: 0 expected_and_present,
// 73 expected_missing, 16 present_but_removed_from_pack. The 16 live
// documents predate the pack, carry no verificationStatus and no
// contentKind, and nothing in the review ledger accounts for them. The
// importer cannot help: writing more records never retracts one already
// live. Retraction is a deliberate human act, and this is the tool for it.
//
// ── The safety model, in order of strength ───────────────────────────────
//
// 1. IAM. This tool needs read, create and delete on Firestore, and NOTHING
//    on Cloud Storage. The service account it runs as must hold no
//    `roles/storage.*` binding at all, so the audio objects are not merely
//    un-referenced by this code — they are unreachable by the credential it
//    holds. See docs/LEGACY_RETIREMENT_SETUP.md.
//
// 2. The manifest. review/legacy_retirement_manifest.json is the only
//    source of ids. There is no flag, input or environment variable that
//    adds one. An id not in it is refused at the moment of deletion, not
//    merely absent from the loop.
//
// 3. Phase separation. Archiving and deleting are different runs behind
//    different confirmations. A delete run re-reads both copies and
//    compares them again before it deletes anything, so approving the
//    archive is not the same act as approving the deletion.
//
// 4. All-or-nothing ordering. Every id is verified before ANY id is
//    deleted. A single mismatch aborts the run with nothing deleted, rather
//    than leaving a half-retired collection.
//
// 5. Dry-run by default. --execute is required for any write. Without it
//    the tool performs only GETs and prints what it would do.
//
// ── Fidelity ─────────────────────────────────────────────────────────────
//
// The archive stores the raw Firestore `fields` object exactly as the API
// returned it — no decode/encode round-trip. A round-trip would have to
// guess integerValue vs doubleValue, would coerce timestamps to strings,
// and would silently drop any value type this repository has never seen.
// Copying the wire representation verbatim cannot lose what it does not
// understand, and it makes "the copy matches" an exact comparison rather
// than an approximate one.

import { readFileSync } from "node:fs";

export const SOURCE_COLLECTION = "supplications";
export const ARCHIVE_COLLECTION = "supplications_legacy_archive";
export const MANIFEST_PATH = "review/legacy_retirement_manifest.json";
export const PHASES = Object.freeze(["archive", "delete"]);

/** Hosts this tool must never contact. Asserted in the tests against the
 *  source text of this file, so a future edit that reaches for an audio
 *  object fails a test rather than deleting one. */
export const FORBIDDEN_HOSTS = Object.freeze([
  "storage.googleapis.com",
  "firebasestorage.googleapis.com",
  "firebasestorage.app",
]);

// ── Manifest ─────────────────────────────────────────────────────────────

/**
 * Loads and fully validates the allowlist. Every failure here is fatal:
 * a manifest this tool cannot completely understand is a manifest it must
 * not act on.
 */
export function loadManifest(path = MANIFEST_PATH, readFile = readFileSync) {
  const raw = JSON.parse(readFile(path, "utf8"));

  if (raw.status !== "ready") {
    throw new Error(
      `Refusing to run: ${path} has status "${raw.status}", not "ready".\n` +
        "The 16 document ids must be transcribed literally from a production\n" +
        "reconciliation report before this tool will do anything at all.\n" +
        "Nothing about them can be guessed or derived from the source pack —\n" +
        "the reconciliation proved production and the pack do not overlap.",
    );
  }
  if (raw.sourceCollection !== SOURCE_COLLECTION) {
    throw new Error(
      `Manifest sourceCollection must be "${SOURCE_COLLECTION}", got "${raw.sourceCollection}".`,
    );
  }
  if (raw.archiveCollection !== ARCHIVE_COLLECTION) {
    throw new Error(
      `Manifest archiveCollection must be "${ARCHIVE_COLLECTION}", got "${raw.archiveCollection}".`,
    );
  }

  const ids = raw.documentIds;
  if (!Array.isArray(ids) || ids.length === 0) {
    throw new Error("Manifest documentIds must be a non-empty array.");
  }
  for (const id of ids) {
    if (typeof id !== "string" || id.trim() === "") {
      throw new Error(`Manifest documentIds contains a non-id entry: ${JSON.stringify(id)}`);
    }
    // A slash would address a different collection entirely; a "." or ".."
    // would address the collection itself or its parent.
    if (id.includes("/") || id === "." || id === "..") {
      throw new Error(`Manifest documentIds contains an unusable id: ${JSON.stringify(id)}`);
    }
  }
  if (new Set(ids).size !== ids.length) {
    throw new Error("Manifest documentIds contains duplicates.");
  }

  // The count is declared separately and must agree. Two independent
  // statements of the same fact catch a half-finished edit that a single
  // list cannot.
  if (raw.expectedCount !== ids.length) {
    throw new Error(
      `Manifest expectedCount is ${raw.expectedCount} but documentIds has ${ids.length}. ` +
        "Refusing to act on a manifest whose own two counts disagree.",
    );
  }

  return {
    ids: Object.freeze([...ids]),
    idSet: new Set(ids),
    expectedCount: raw.expectedCount,
    reconciledAt: raw.reconciledAt ?? null,
    reconciliationRunUrl: raw.reconciliationRunUrl ?? null,
  };
}

/**
 * The last gate before a delete. Called immediately before each DELETE with
 * the id about to be removed, so an id that reached that point by any route
 * — a bug, a mutated array, a future refactor — is still refused.
 */
export function assertDeletable(id, manifest) {
  if (!manifest.idSet.has(id)) {
    throw new Error(
      `Refusing to delete "${id}": it is not in ${MANIFEST_PATH}. ` +
        "Only the manifest decides what may be deleted.",
    );
  }
}

// ── Comparison ───────────────────────────────────────────────────────────

/** Key-sorted JSON. No normalisation of any kind: this compares the wire
 *  representation, and a copy that differs by so much as a Unicode form is
 *  not a copy. */
export function stableJson(value) {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;
  const keys = Object.keys(value).sort();
  return `{${keys
    .map((k) => `${JSON.stringify(k)}:${stableJson(value[k])}`)
    .join(",")}}`;
}

export function fieldsMatch(a, b) {
  return stableJson(a ?? {}) === stableJson(b ?? {});
}

/** Presence-only summary, for logs. The archive holds full documents; the
 *  LOG must not, for the same reason the reconcile report does not: an
 *  audioUrl can carry a Storage download token. */
export function describeFields(fields = {}) {
  const keys = Object.keys(fields).sort();
  return `${keys.length} field(s): ${keys.join(", ")}`;
}

// ── Firestore REST ───────────────────────────────────────────────────────

function base(plan) {
  return (
    `https://firestore.googleapis.com/v1/projects/${plan.projectId}` +
    `/databases/${plan.database}/documents`
  );
}

export function documentPath(plan, collection, id) {
  return `${base(plan)}/${collection}/${encodeURIComponent(id)}`;
}

/**
 * Reads one document and returns its RAW `fields` object, or null on 404.
 * Any other non-ok status throws: a 403 or a 500 must not be mistaken for
 * "the document is not there", which in the archive phase would look like
 * permission to create it.
 */
export async function getRaw(plan, collection, id, deps = {}) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  const res = await doFetch(documentPath(plan, collection, id), {
    headers: { Authorization: `Bearer ${plan.token}` },
  });
  if (res.status === 404) return null;
  if (!res.ok) {
    throw new Error(`GET ${collection}/${id} failed: HTTP ${res.status}`);
  }
  const body = await res.json();
  return body.fields ?? {};
}

/**
 * Creates the archive document. POST with `documentId` is create-only:
 * Firestore returns 409 if it already exists, so this can never overwrite
 * an archive entry — including one written by an earlier, different run.
 */
export async function createArchive(plan, id, fields, deps = {}) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  const url =
    `${base(plan)}/${ARCHIVE_COLLECTION}` +
    `?documentId=${encodeURIComponent(id)}`;
  const res = await doFetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${plan.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) {
    throw new Error(`archive create ${id} failed: HTTP ${res.status}`);
  }
}

export async function deleteSource(plan, id, manifest, deps = {}) {
  assertDeletable(id, manifest);
  const doFetch = deps.fetch ?? globalThis.fetch;
  const res = await doFetch(documentPath(plan, SOURCE_COLLECTION, id), {
    method: "DELETE",
    headers: { Authorization: `Bearer ${plan.token}` },
  });
  if (!res.ok) {
    throw new Error(`delete ${id} failed: HTTP ${res.status}`);
  }
}

// ── Phase 1: archive ─────────────────────────────────────────────────────

/**
 * Copies every manifest document into the archive, then verifies every copy
 * by reading it back. Deletes nothing — this phase has no delete path.
 *
 * An id missing from the source is fatal rather than skipped: the manifest
 * was transcribed from a reconciliation of this same collection, so a
 * missing id means the manifest and the collection disagree, and the
 * operator must find out why before anything is deleted.
 */
export async function runArchivePhase(plan, manifest, deps = {}) {
  const log = deps.log ?? console.log;
  const results = [];

  for (const id of manifest.ids) {
    const source = await getRaw(plan, SOURCE_COLLECTION, id, deps);
    if (source === null) {
      throw new Error(
        `${SOURCE_COLLECTION}/${id} is in the manifest but not in the collection. ` +
          "Refusing to continue: re-run the reconciliation.",
      );
    }

    const existing = await getRaw(plan, ARCHIVE_COLLECTION, id, deps);
    if (existing !== null) {
      // Already archived by an earlier run. Identical is a no-op; different
      // is a conflict no automation should resolve.
      if (!fieldsMatch(existing, source)) {
        throw new Error(
          `${ARCHIVE_COLLECTION}/${id} already exists and does NOT match the live document. ` +
            "Refusing to overwrite an archive entry.",
        );
      }
      log(`  already archived  ${id}  (${describeFields(source)})`);
      results.push({ id, action: "already_archived" });
      continue;
    }

    if (!plan.execute) {
      log(`  would archive     ${id}  (${describeFields(source)})`);
      results.push({ id, action: "would_archive" });
      continue;
    }

    await createArchive(plan, id, source, deps);
    log(`  archived          ${id}  (${describeFields(source)})`);
    results.push({ id, action: "archived" });
  }

  if (!plan.execute) {
    log("\nDry run: no document was created, and none was deleted.");
    return results;
  }

  // Verify every copy by reading it back through the same credential. An
  // unverified archive is not an archive.
  log("\nVerifying every copy against its original…");
  for (const id of manifest.ids) {
    const source = await getRaw(plan, SOURCE_COLLECTION, id, deps);
    const copy = await getRaw(plan, ARCHIVE_COLLECTION, id, deps);
    if (copy === null) {
      throw new Error(`verification failed: ${ARCHIVE_COLLECTION}/${id} is not there.`);
    }
    if (!fieldsMatch(copy, source)) {
      throw new Error(`verification failed: ${ARCHIVE_COLLECTION}/${id} does not match the original.`);
    }
    log(`  verified          ${id}`);
  }

  log(`\n${manifest.ids.length} document(s) archived and verified.`);
  log("No document was deleted by this phase, and no audio file was touched.");
  return results;
}

// ── Phase 2: delete ──────────────────────────────────────────────────────

/**
 * Deletes the originals — but only after re-proving, for EVERY id, that a
 * matching archive copy exists right now. The verification loop completes
 * in full before the first delete is issued, so a mismatch on the last id
 * leaves the first fifteen documents intact.
 */
export async function runDeletePhase(plan, manifest, deps = {}) {
  const log = deps.log ?? console.log;

  log("Re-verifying every archive copy before deleting anything…");
  const deletable = [];
  for (const id of manifest.ids) {
    const source = await getRaw(plan, SOURCE_COLLECTION, id, deps);
    const copy = await getRaw(plan, ARCHIVE_COLLECTION, id, deps);

    if (source === null) {
      // Already deleted by an earlier run; the archive copy must still be
      // there, or this id has been lost.
      if (copy === null) {
        throw new Error(
          `${id} is in neither collection. Refusing to continue: it has no archive copy.`,
        );
      }
      log(`  already deleted   ${id}`);
      continue;
    }
    if (copy === null) {
      throw new Error(
        `Refusing to delete ${id}: it has no copy in ${ARCHIVE_COLLECTION}. ` +
          "Run the archive phase first.",
      );
    }
    if (!fieldsMatch(copy, source)) {
      throw new Error(
        `Refusing to delete ${id}: its archive copy does not match the live document.`,
      );
    }
    log(`  verified          ${id}`);
    deletable.push(id);
  }

  if (!plan.execute) {
    for (const id of deletable) log(`  would delete      ${id}`);
    log("\nDry run: nothing was deleted.");
    return { verified: deletable.length, deleted: 0 };
  }

  // Only now, with every copy proven, does anything get deleted.
  let deleted = 0;
  for (const id of deletable) {
    await deleteSource(plan, id, manifest, deps);
    log(`  deleted           ${id}`);
    deleted += 1;
  }

  log(`\n${deleted} document(s) deleted from ${SOURCE_COLLECTION}.`);
  log("Every one of them remains in full in " + ARCHIVE_COLLECTION + ".");
  log("No audio file was touched: this tool never contacts Cloud Storage.");
  return { verified: deletable.length, deleted };
}

// ── CLI ──────────────────────────────────────────────────────────────────

export function resolvePlan(argv, env = {}) {
  const args = argv.slice(2);
  const phaseArg = args.find((a) => a.startsWith("--phase="));
  const phase = phaseArg ? phaseArg.slice("--phase=".length) : null;

  if (!PHASES.includes(phase)) {
    throw new Error(`--phase must be one of: ${PHASES.join(", ")}`);
  }

  const execute = args.includes("--execute");
  const projectId = env.FIREBASE_PROJECT_ID;
  const database = env.FIREBASE_DATABASE_ID ?? "(default)";
  const token = env.FIREBASE_ADMIN_TOKEN;

  if (execute) {
    // Deleting production documents is not something an environment
    // variable should be able to arrange on its own.
    if (env.CONFIRM_RETIREMENT !== "RETIRE_LEGACY_RECORDS") {
      throw new Error(
        "--execute requires CONFIRM_RETIREMENT=RETIRE_LEGACY_RECORDS.",
      );
    }
    if (!projectId) throw new Error("FIREBASE_PROJECT_ID is required.");
    if (!token) throw new Error("FIREBASE_ADMIN_TOKEN is required.");
  }

  return { phase, execute, projectId, database, token };
}

export function printHeader(plan, manifest, log = console.log) {
  log(`\nLegacy retirement — phase: ${plan.phase}`);
  log(`Mode:      ${plan.execute ? "EXECUTE" : "DRY RUN (default)"}`);
  log(`Source:    ${SOURCE_COLLECTION}`);
  log(`Archive:   ${ARCHIVE_COLLECTION}`);
  log(`Manifest:  ${MANIFEST_PATH}  (${manifest.ids.length} document(s))`);
  if (manifest.reconciliationRunUrl) {
    log(`Evidence:  ${manifest.reconciliationRunUrl}`);
  }
  log("Storage:   NOT CONTACTED — audio files are out of scope.\n");
}

export async function main(argv = process.argv, env = process.env) {
  const plan = resolvePlan(argv, env);
  const manifest = loadManifest();
  printHeader(plan, manifest);

  if (plan.phase === "archive") {
    await runArchivePhase(plan, manifest);
  } else {
    await runDeletePhase(plan, manifest);
  }
}

// Only run when invoked directly, so importing this module in a test does
// nothing at all.
if (process.argv[1] && process.argv[1].endsWith("retire_legacy_records.mjs")) {
  main().catch((err) => {
    console.error(`\n${err.message}\n`);
    process.exit(1);
  });
}
