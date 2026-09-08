#!/usr/bin/env node
/**
 * Read-only inspection of the `groups` collection.
 *
 * ── The one question this answers ────────────────────────────────────────
 *
 * The rules merged in #33 deny `list` on `groups` and resolve a join code
 * through a `group_codes/{code}` pointer document instead. Groups created
 * BEFORE that change have no pointer, so once the rules are deployed nobody
 * can join them by code until one is created for them.
 *
 * The ordering is therefore load-bearing: migrate first, deploy second. But
 * migrating is only necessary if any group exists at all, and the app has not
 * launched, so the expected answer is "none". That expectation is not
 * evidence. This script goes and looks.
 *
 * ── What it does NOT do ──────────────────────────────────────────────────
 *
 * It writes nothing. There is no code path here that issues anything but GET:
 * no PATCH, no POST, no DELETE, no `--write`, no `--execute`. It creates no
 * pointer documents — the migration is a separate, deliberate act.
 *
 * As with the reconciler, the real guarantee is IAM, not this file: the
 * service account it runs as holds `roles/datastore.viewer` and nothing else,
 * and a write issued with its token is refused by Google. This file is the
 * second layer, and inspect_groups.test.mjs asserts its properties so an edit
 * that adds a write turns a test red.
 *
 * ── What it must never print ─────────────────────────────────────────────
 *
 * The join code IS the secret. #33 exists precisely because the code used to
 * be discoverable; printing it into a job summary — which is far more widely
 * readable than the database — would hand back what that change took away.
 * So the code is reported as PRESENT or ABSENT and never by value.
 *
 * Member documents are not read at all. They hold live GPS coordinates of
 * pilgrims, and nothing about this question needs them.
 *
 * Usage:
 *   FIREBASE_PROJECT_ID=... FIREBASE_ADMIN_TOKEN=... \
 *     node scripts/inspect_groups.mjs [--database="(default)"]
 */

export const GROUPS_COLLECTION = "groups";
export const GROUP_CODES_COLLECTION = "group_codes";

/** Arguments this tool accepts. Anything else is refused — see below. */
export const KNOWN_ARGUMENTS = Object.freeze(['--database=<id>']);

/**
 * The only keys a report row may carry.
 *
 * `hasCode` and `hasPointer` are presence booleans, never values. There is
 * deliberately no `code` key: the tests assert this list AND the values, so
 * adding one here is not enough to leak a code.
 */
export const REPORT_FIELDS = Object.freeze([
  "documentId",
  "hasCode",
  "hasPointer",
  "needsPointer",
]);

/** Hosts this tool must never contact. Groups live in Firestore alone. */
export const FORBIDDEN_HOSTS = Object.freeze([
  "storage.googleapis.com",
  "firebasestorage.googleapis.com",
  "firebasestorage.app",
]);

/**
 * Rejects any argument this tool does not define.
 *
 * A tool pointed at production should not silently ignore a flag someone
 * believed was doing something. There is nothing to select here: the
 * collection is fixed, and the only knob is which database to read.
 */
export function assertOnlyKnownArguments(args) {
  const unknown = args.filter(
    (a) => a !== "--database" && !a.startsWith("--database="),
  );
  if (unknown.length === 0) return;
  throw new Error(
    `Unrecognised argument(s): ${unknown.join(", ")}\n` +
      `Accepted arguments: ${KNOWN_ARGUMENTS.join(", ")}\n` +
      `Usage: node scripts/inspect_groups.mjs [--database=<id>]\n` +
      `This tool only reads. It has no write, execute or filter flag.`,
  );
}

/** Firestore document ids are the last path segment of `name`. */
export function documentIdOf(name) {
  if (typeof name !== "string" || name === "") return "";
  const parts = name.split("/");
  return parts[parts.length - 1] ?? "";
}

/** True when a Firestore string field is present and non-blank. */
export function presentString(value) {
  return typeof value === "string" && value.trim() !== "";
}

/**
 * Builds one report row from a raw Firestore group document.
 *
 * `pointerIds` is the set of document ids present in `group_codes`. A group
 * needs a pointer when it has a code and no pointer names that code.
 *
 * A group with NO code at all is reported too: it cannot be joined by code
 * before or after the rules change, so a pointer would point at nothing. It
 * needs a human, not a migration.
 */
export function reportRow(doc, pointerIds) {
  const code = doc?.fields?.code?.stringValue;
  const hasCode = presentString(code);
  const hasPointer = hasCode && pointerIds.has(code.trim());
  return {
    documentId: documentIdOf(doc?.name ?? ""),
    hasCode,
    hasPointer,
    needsPointer: hasCode && !hasPointer,
  };
}

/** Renders one row. Presence only — never a code, never a coordinate. */
export function formatRow(row) {
  const mark = (b) => (b ? "present" : "absent");
  return (
    `  - ${row.documentId} ` +
    `code=${mark(row.hasCode)} ` +
    `pointer=${mark(row.hasPointer)} ` +
    `needsPointer=${row.needsPointer ? "YES" : "no"}`
  );
}

/**
 * Lists every document id in a collection.
 *
 * GET only. Paginated, because a partial answer to "is it empty?" is worse
 * than no answer: reading one page and reporting zero would be wrong exactly
 * when it matters.
 */
export async function listDocuments(
  { projectId, database, collection, token },
  deps = {},
) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  const base =
    `https://firestore.googleapis.com/v1/projects/${projectId}` +
    `/databases/${database}/documents/${collection}`;
  const docs = [];
  let pageToken;
  do {
    const url = pageToken
      ? `${base}?pageSize=300&pageToken=${encodeURIComponent(pageToken)}`
      : `${base}?pageSize=300`;
    const res = await doFetch(url, {
      method: "GET",
      headers: { Authorization: `Bearer ${token}` },
    });
    // A collection that has never held a document is not an error: Firestore
    // returns 200 with no `documents` key. 404 is treated the same way, since
    // "there is nothing there" is the answer either way.
    if (res.status === 404) return docs;
    if (!res.ok) {
      throw new Error(`list ${collection} failed: HTTP ${res.status}`);
    }
    const body = await res.json();
    for (const d of body.documents ?? []) docs.push(d);
    pageToken = body.nextPageToken;
  } while (pageToken);
  return docs;
}

/** The whole inspection. Returns the rows and the counts. */
export async function inspectGroups(plan, deps = {}) {
  const groups = await listDocuments(
    { ...plan, collection: GROUPS_COLLECTION },
    deps,
  );
  const pointers = await listDocuments(
    { ...plan, collection: GROUP_CODES_COLLECTION },
    deps,
  );
  const pointerIds = new Set(pointers.map((d) => documentIdOf(d.name ?? "")));
  const rows = groups.map((g) => reportRow(g, pointerIds));
  return {
    groupCount: groups.length,
    pointerCount: pointers.length,
    rows,
    needsPointer: rows.filter((r) => r.needsPointer).length,
    withoutCode: rows.filter((r) => !r.hasCode).length,
  };
}

/**
 * Prints the report and returns the verdict line.
 *
 * The verdict is a single machine-readable token so the decision cannot be
 * lost in prose — it is the entire point of running this.
 */
export function printReport(result, log = console.log) {
  log("");
  log("Groups inspection — READ ONLY, nothing is written.");
  log("");
  log(`groups:       ${result.groupCount}`);
  log(`group_codes:  ${result.pointerCount}`);
  log("");
  if (result.rows.length > 0) {
    log("Documents (presence only — no join code is ever printed):");
    for (const row of result.rows) log(formatRow(row));
    log("");
  }
  log("No document was written, created or deleted.");
  log("Storage:   NOT CONTACTED");
  log("");

  if (result.groupCount === 0) {
    log("GROUPS_EMPTY — safe to deploy rules without migration");
    return "GROUPS_EMPTY";
  }
  log("GROUPS_PRESENT — migration required before rules deploy");
  log(
    `${result.needsPointer} group(s) need a group_codes/{code} pointer ` +
      `created BEFORE the new rules are deployed.`,
  );
  if (result.withoutCode > 0) {
    log(
      `${result.withoutCode} group(s) carry no code at all — a pointer ` +
        `cannot be made for those, and they need a human decision.`,
    );
  }
  return "GROUPS_PRESENT";
}

/* c8 ignore start — CLI wiring, exercised by the workflow rather than tests */
async function main() {
  assertOnlyKnownArguments(process.argv.slice(2));

  const databaseArg = process.argv
    .slice(2)
    .find((a) => a.startsWith("--database="));
  const database = databaseArg
    ? databaseArg.slice("--database=".length)
    : "(default)";

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const token = process.env.FIREBASE_ADMIN_TOKEN;
  if (!projectId || !token) {
    throw new Error(
      "FIREBASE_PROJECT_ID and FIREBASE_ADMIN_TOKEN must both be set.",
    );
  }

  const result = await inspectGroups({ projectId, database, token });
  const verdict = printReport(result);
  // Exit 0 either way: both answers are valid findings, and a non-zero exit
  // would make "no migration needed" look like a failure.
  return verdict;
}

const isDirectRun =
  process.argv[1] && process.argv[1].endsWith("inspect_groups.mjs");
if (isDirectRun) {
  main().catch((err) => {
    console.error(`\n${err.message}`);
    process.exit(1);
  });
}
/* c8 ignore stop */
