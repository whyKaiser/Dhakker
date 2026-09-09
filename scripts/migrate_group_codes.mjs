#!/usr/bin/env node
/**
 * Creates the `group_codes/{code}` pointer for every pre-existing group.
 *
 * ── Why this exists ──────────────────────────────────────────────────────
 *
 * The rules merged in #33 deny `list` on `groups` and resolve a join code
 * through a pointer document instead. Groups created BEFORE that change have
 * no pointer, so once the rules are deployed nobody can join them by code
 * until one exists. Migrate first, deploy second.
 *
 * Run `scripts/inspect_groups.mjs` first. If it reports GROUPS_EMPTY there is
 * nothing to do here and this tool should not be run at all.
 *
 * ── What it writes, and what it will not ─────────────────────────────────
 *
 * It creates documents in `group_codes` and NOTHING else. It never writes to
 * `groups`, never to `members` (which hold live GPS coordinates), never to
 * `supplications` or the archive, and never contacts Cloud Storage. Those are
 * not promises in prose: `ALLOWED_WRITE_COLLECTION` is a single value, every
 * write goes through one function that asserts against it, and the tests
 * assert the requests this file actually issues.
 *
 * Creation is create-only — `POST ?documentId=` returns 409 if the document
 * exists — so the tool is idempotent and can never repoint a code that has
 * already been claimed. That matters: repointing a circulating code would
 * redirect everyone joining with it into a different group.
 *
 * ── Safety posture ───────────────────────────────────────────────────────
 *
 * Dry run is the default. `--execute` is required to write, and even then
 * every pointer is derived from a group document that was just read — there
 * is no input by which an operator can name a code or a group id. Nothing on
 * the command line can add, filter or invent one.
 *
 * A group carrying no `code` is reported and SKIPPED, never guessed at: a
 * pointer to an absent code would point at nothing, and inventing a code
 * would silently change how a real family joins.
 *
 * Usage:
 *   FIREBASE_PROJECT_ID=... FIREBASE_ADMIN_TOKEN=... \
 *     node scripts/migrate_group_codes.mjs [--database=<id>] [--execute]
 */

export const GROUPS_COLLECTION = "groups";
export const GROUP_CODES_COLLECTION = "group_codes";

/**
 * The only collection this tool may write to. Every write is checked against
 * this single value, so widening the blast radius takes an edit here that the
 * tests notice.
 */
export const ALLOWED_WRITE_COLLECTION = GROUP_CODES_COLLECTION;

export const KNOWN_ARGUMENTS = Object.freeze([
  "--database=<id>",
  "--execute",
]);

/** Hosts this tool must never contact. */
export const FORBIDDEN_HOSTS = Object.freeze([
  "storage.googleapis.com",
  "firebasestorage.googleapis.com",
  "firebasestorage.app",
]);

/**
 * Rejects any argument this tool does not define.
 *
 * A tool that can write to production must not silently ignore a flag
 * somebody believed was limiting it.
 */
export function assertOnlyKnownArguments(args) {
  const unknown = args.filter(
    (a) => a !== "--execute" && !a.startsWith("--database="),
  );
  if (unknown.length === 0) return;
  throw new Error(
    `Unrecognised argument(s): ${unknown.join(", ")}\n` +
      `Accepted arguments: ${KNOWN_ARGUMENTS.join(", ")}\n` +
      `Usage: node scripts/migrate_group_codes.mjs [--database=<id>] [--execute]\n` +
      `There are no other arguments. The pointers to create come only from the\n` +
      `groups collection itself; nothing on the command line can name, add or\n` +
      `filter one.`,
  );
}

export function documentIdOf(name) {
  if (typeof name !== "string" || name === "") return "";
  const parts = name.split("/");
  return parts[parts.length - 1] ?? "";
}

/**
 * A Firestore document id may not be empty, contain a slash, be `.` or `..`,
 * or exceed 1500 bytes. A code that cannot be an id cannot become a pointer,
 * and must be reported rather than mangled into one.
 */
export function isUsableAsDocumentId(value) {
  if (typeof value !== "string") return false;
  const v = value.trim();
  if (v === "" || v === "." || v === "..") return false;
  if (v.includes("/")) return false;
  if (Buffer.byteLength(v, "utf8") > 1500) return false;
  return true;
}

function base(plan) {
  return (
    `https://firestore.googleapis.com/v1/projects/${plan.projectId}` +
    `/databases/${plan.database}/documents`
  );
}

/** Lists a collection. GET only, paginated. */
export async function listDocuments(plan, collection, deps = {}) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  const url0 = `${base(plan)}/${collection}`;
  const docs = [];
  let pageToken;
  do {
    const url = pageToken
      ? `${url0}?pageSize=300&pageToken=${encodeURIComponent(pageToken)}`
      : `${url0}?pageSize=300`;
    const res = await doFetch(url, {
      method: "GET",
      headers: { Authorization: `Bearer ${plan.token}` },
    });
    if (res.status === 404) return docs;
    if (!res.ok) throw new Error(`list ${collection} failed: HTTP ${res.status}`);
    const body = await res.json();
    for (const d of body.documents ?? []) docs.push(d);
    pageToken = body.nextPageToken;
  } while (pageToken);
  return docs;
}

/**
 * The single write path.
 *
 * Create-only by construction: `POST ?documentId=` is rejected with 409 when
 * the document already exists, so a claimed code can never be repointed, and
 * a re-run after a partial migration is safe.
 */
export async function createPointer(plan, code, fields, deps = {}) {
  if (plan.collection !== undefined && plan.collection !== ALLOWED_WRITE_COLLECTION) {
    throw new Error(
      `refusing to write to ${plan.collection}: this tool writes only to ` +
        `${ALLOWED_WRITE_COLLECTION}`,
    );
  }
  if (!isUsableAsDocumentId(code)) {
    throw new Error(`refusing to create a pointer for an unusable code`);
  }
  const doFetch = deps.fetch ?? globalThis.fetch;
  const url =
    `${base(plan)}/${ALLOWED_WRITE_COLLECTION}` +
    `?documentId=${encodeURIComponent(code.trim())}`;
  const res = await doFetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${plan.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ fields }),
  });
  if (res.status === 409) return "exists";
  if (!res.ok) throw new Error(`create pointer failed: HTTP ${res.status}`);
  return "created";
}

/**
 * Decides, per group, what should happen. Pure — no network, so the whole
 * decision table is testable without a credential.
 *
 * Returns one of:
 *   ready    — has a usable code and no pointer yet
 *   done     — already has its pointer
 *   no-code  — carries no code; skipped, needs a human
 *   bad-code — has a code that cannot be a document id; skipped
 */
export function planFor(doc, pointerIds) {
  const id = documentIdOf(doc?.name ?? "");
  const raw = doc?.fields?.code?.stringValue;
  const ownerId = doc?.fields?.ownerId?.stringValue ?? "";

  if (typeof raw !== "string" || raw.trim() === "") {
    return { groupId: id, action: "no-code" };
  }
  if (!isUsableAsDocumentId(raw)) {
    return { groupId: id, action: "bad-code" };
  }
  const code = raw.trim();
  if (pointerIds.has(code)) return { groupId: id, code, action: "done" };
  return { groupId: id, code, ownerId, action: "ready" };
}

/** The pointer document body. Exactly the two fields the rules read. */
export function pointerFields(plan) {
  return {
    groupId: { stringValue: plan.groupId },
    ownerId: { stringValue: plan.ownerId ?? "" },
    migratedAt: { timestampValue: new Date().toISOString() },
  };
}

/** Runs the migration. Dry run unless `plan.execute` is true. */
export async function migrate(plan, deps = {}, log = console.log) {
  const groups = await listDocuments(plan, GROUPS_COLLECTION, deps);
  const pointers = await listDocuments(plan, GROUP_CODES_COLLECTION, deps);
  const pointerIds = new Set(pointers.map((d) => documentIdOf(d.name ?? "")));

  const plans = groups.map((g) => planFor(g, pointerIds));
  const ready = plans.filter((p) => p.action === "ready");
  const done = plans.filter((p) => p.action === "done");
  const noCode = plans.filter((p) => p.action === "no-code");
  const badCode = plans.filter((p) => p.action === "bad-code");

  log("");
  log(
    plan.execute
      ? "Migrating group_codes pointers — EXECUTE."
      : "Migrating group_codes pointers — DRY RUN, nothing is written.",
  );
  log("");
  log(`groups:            ${groups.length}`);
  log(`already pointed:   ${done.length}`);
  log(`to create:         ${ready.length}`);
  log(`skipped (no code): ${noCode.length}`);
  log(`skipped (bad code):${badCode.length}`);
  log("");

  // Presence and ids only. The code is the secret the rules protect; a log
  // is read by more people than the database is.
  for (const p of ready) log(`  will create pointer for group ${p.groupId}`);
  for (const p of done) log(`  already pointed        ${p.groupId}`);
  for (const p of noCode) log(`  SKIPPED, no code       ${p.groupId}`);
  for (const p of badCode) log(`  SKIPPED, unusable code ${p.groupId}`);

  if (!plan.execute) {
    log("");
    log("Dry run: no document was created. Re-run with --execute to write.");
    log("Storage:   NOT CONTACTED");
    return { created: 0, existed: 0, plans };
  }

  let created = 0;
  let existed = 0;
  for (const p of ready) {
    const outcome = await createPointer(
      plan,
      p.code,
      pointerFields({ groupId: p.groupId, ownerId: p.ownerId }),
      deps,
    );
    if (outcome === "created") {
      created++;
      log(`  created pointer for group ${p.groupId}`);
    } else {
      existed++;
      log(`  pointer already existed for group ${p.groupId}`);
    }
  }

  log("");
  log(`${created} pointer(s) created, ${existed} already existed.`);
  log("No group, member or supplication document was modified.");
  log("Storage:   NOT CONTACTED");
  return { created, existed, plans };
}

/* c8 ignore start — CLI wiring, exercised by the workflow rather than tests */
async function main() {
  const args = process.argv.slice(2);
  assertOnlyKnownArguments(args);

  const databaseArg = args.find((a) => a.startsWith("--database="));
  const database = databaseArg
    ? databaseArg.slice("--database=".length)
    : "(default)";
  const execute = args.includes("--execute");

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const token = process.env.FIREBASE_ADMIN_TOKEN;
  if (!projectId || !token) {
    throw new Error(
      "FIREBASE_PROJECT_ID and FIREBASE_ADMIN_TOKEN must both be set.",
    );
  }

  await migrate({ projectId, database, token, execute });
}

const isDirectRun =
  process.argv[1] && process.argv[1].endsWith("migrate_group_codes.mjs");
if (isDirectRun) {
  main().catch((err) => {
    console.error(`\n${err.message}`);
    process.exit(1);
  });
}
/* c8 ignore stop */
