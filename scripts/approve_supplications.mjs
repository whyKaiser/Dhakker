#!/usr/bin/env node
/**
 * Applies a review that already happened, to the records it was recorded for.
 *
 * ── What this is, and what it is not ─────────────────────────────────────
 *
 * `docs/CONTENT_APPROVAL.md` forbids bulk approval, and it is right to: a
 * script cannot read a printed page, and marking a text `verified` because
 * some other text was checked is how a supplication nobody vouched for
 * reaches a pilgrim.
 *
 * This does something narrower. `review/human_review_ledger.json` already
 * records, per record, that a named human read it against a named edition
 * and page — and stores `reviewedTextHash`, the sha256 of the exact text
 * they read. That review is a fact that occurred. What never happened was
 * the second, clerical step of stamping it into Firestore one screen at a
 * time.
 *
 * So the rule here is: a record is approved ONLY if the text living in
 * Firestore right now hashes to the value the reviewer recorded. A single
 * changed character and the hashes diverge, the record is refused, and it
 * stays unverified. The script cannot approve a text nobody read, because it
 * has nothing to compare such a text against.
 *
 * It is still a bulk action, and it says so. Every record it touches gets a
 * line appended to `reviewNotes` naming the ledger entry it rests on — the
 * reviewer, the edition, the page and the date — and stating plainly that
 * the page was not re-read at the moment of stamping. A record that claims
 * more than what happened is worse than one that claims less.
 *
 * ── What it refuses ──────────────────────────────────────────────────────
 *
 *   no ledger entry            nothing records that anyone read it
 *   reviewStatus blocked       something is wrong with the TEXT
 *   deploymentBlocked          the app cannot present it correctly yet
 *   excludedFromImport         an explicit instruction not to ship it
 *   text hash mismatch         the live text is not the text reviewed
 *   already verified           nothing to do; never re-stamped
 *   revoked                    a withdrawal is not undone in bulk
 *   incomplete provenance      firestore.rules would reject the write
 *
 * ── Usage ────────────────────────────────────────────────────────────────
 *
 * DRY RUN IS THE DEFAULT.
 *
 *   export FIREBASE_PROJECT_ID=dhakker-160d0
 *   export GOOGLE_ACCESS_TOKEN="$(gcloud auth print-access-token)"
 *
 *   node scripts/approve_supplications.mjs --production \
 *     --verified-by=<the admin account's uid>
 *
 *   ... --write --confirm-project=<id> --confirm-count=<n>
 */

import { createHash } from "node:crypto";
import { readFileSync, existsSync } from "node:fs";

import { fromFirestoreValue, listCollection } from "./import_source_pack.mjs";

export const LEDGER_PATH = "review/human_review_ledger.json";

/** The fields firestore.rules requires before a record may be `verified`. */
export const REQUIRED_PROVENANCE = Object.freeze([
  "authority",
  "sourceUrl",
  "sourceVersion",
  "sourceLanguage",
]);

/** The fields this script writes. Nothing else is touched. */
export const APPROVAL_WRITE_FIELDS = Object.freeze([
  "verificationStatus",
  "verifiedAt",
  "verifiedBy",
  "contentHash",
  "reviewNotes",
  "updatedAt",
]);

export const KNOWN_ARGUMENTS = Object.freeze([
  "--production",
  "--staging",
  "--verified-by=<uid>",
  "--write",
  "--confirm-project=<id>",
  "--confirm-count=<n>",
]);

export function assertOnlyKnownArguments(args) {
  const known = new Set(["--production", "--staging", "--write"]);
  const prefixes = ["--verified-by=", "--confirm-project=", "--confirm-count="];
  const unknown = args.filter(
    (a) => !known.has(a) && !prefixes.some((p) => a.startsWith(p)),
  );
  if (unknown.length === 0) return;
  throw new Error(
    `Unrecognised argument(s): ${unknown.join(", ")}\n` +
      `Accepted: ${KNOWN_ARGUMENTS.join(", ")}\n` +
      "There is no flag that approves a record the ledger does not cover.",
  );
}

export function parseArguments(args) {
  assertOnlyKnownArguments(args);

  const production = args.includes("--production");
  const staging = args.includes("--staging");
  if (production === staging) {
    throw new Error("Name exactly one of --production or --staging.");
  }
  const collection = production ? "supplications" : "supplications_staging";

  const byArg = args.find((a) => a.startsWith("--verified-by="));
  const verifiedBy = byArg ? byArg.slice("--verified-by=".length).trim() : "";
  if (!verifiedBy) {
    throw new Error(
      "--verified-by=<uid> is required.\n" +
        "It records WHO is accountable for these approvals, and it is written " +
        "into every record. It must be a real account, not a label.",
    );
  }
  if (verifiedBy.length > 128 || /[\s/]/.test(verifiedBy)) {
    throw new Error("--verified-by does not look like a Firebase Auth uid.");
  }

  const write = args.includes("--write");
  const projectArg = args.find((a) => a.startsWith("--confirm-project="));
  const countArg = args.find((a) => a.startsWith("--confirm-count="));
  const confirmProject = projectArg
    ? projectArg.slice("--confirm-project=".length).trim()
    : null;
  const confirmCount = countArg
    ? Number(countArg.slice("--confirm-count=".length).trim())
    : null;

  if (write && (!confirmProject || confirmCount === null)) {
    throw new Error(
      "--write requires --confirm-project=<id> and --confirm-count=<n>, " +
        "both matching the plan a dry run printed.",
    );
  }
  if (!write && (confirmProject || countArg)) {
    throw new Error("Confirmations were passed without --write.");
  }

  return { collection, production, verifiedBy, write, confirmProject, confirmCount };
}

/** sha256(ar + NUL + en) — the ledger's construction, and the app's. */
export function contentHashOf(doc) {
  const ar = doc?.text?.ar ?? "";
  const en = doc?.text?.en ?? "";
  return createHash("sha256").update(`${ar}\u0000${en}`, "utf8").digest("hex");
}

export function loadLedger(path = LEDGER_PATH) {
  if (!existsSync(path)) {
    throw new Error(
      `No review ledger at ${path}. Without it nothing records that a human ` +
        "read anything, and there is no review for this script to apply.",
    );
  }
  return JSON.parse(readFileSync(path, "utf8"));
}

export function ledgerIndex(ledger) {
  const byId = new Map();
  for (const r of ledger?.reviews ?? []) byId.set(r.recordId, r);
  return byId;
}

/**
 * Why a record may not be approved, or null when it may.
 *
 * The hash comparison is the load-bearing check. Everything else refuses
 * records for reasons already recorded elsewhere; this one is what makes the
 * whole operation an APPLICATION of a review rather than a substitute for
 * one.
 */
export function refusalReason(doc, review) {
  if (!doc || typeof doc !== "object") return "not a document";
  const id = String(doc.documentId ?? doc.duaId ?? "").trim();
  if (!id) return "no document id";

  if (doc.verificationStatus === "verified") return "already verified";
  if (doc.revokedAt !== null && doc.revokedAt !== undefined && doc.revokedAt !== "") {
    return "revoked — a withdrawal is not undone in bulk";
  }
  if (!review) return "no ledger entry — nobody recorded reading it";
  if (review.reviewStatus === "blocked" || review.reviewStatus === "failed") {
    return `review blocked (${review.blockReason || "no reason recorded"})`;
  }
  if (review.deploymentBlocked === true) {
    return `deployment blocked (${review.deploymentBlockReason || "no reason recorded"})`;
  }
  if (review.excludedFromImport === true) return "excludedFromImport";

  const passed =
    review.reviewStatus === "passed" || review.textReviewStatus === "passed";
  if (!passed) return "ledger does not record a passing text review";

  const recorded = String(review.reviewedTextHash ?? "").trim();
  if (!recorded) return "ledger entry records no reviewedTextHash";
  const live = contentHashOf(doc);
  if (live !== recorded) {
    // Deliberately does not print either hash or any text: the fact of the
    // mismatch is the whole message, and the fix is a human re-reading the
    // page, not comparing digests in a terminal.
    return "live text does not match the text that was reviewed";
  }

  for (const f of REQUIRED_PROVENANCE) {
    const v = doc[f];
    if (typeof v !== "string" || v.trim() === "") {
      return `missing ${f} — firestore.rules would reject the write`;
    }
  }
  if (!/^https:\/\/.+/.test(String(doc.sourceUrl))) {
    return "sourceUrl is not an https URL — firestore.rules would reject it";
  }
  return null;
}

/**
 * The line appended to `reviewNotes`.
 *
 * States what actually happened: the approval rests on a recorded review, and
 * the page was NOT re-read at the moment of stamping. Written in Arabic
 * because that is the language of the console where it will be read.
 */
export function approvalNote(review, now = new Date()) {
  const bits = [];
  if (review?.reviewer) bits.push(`المراجع: ${review.reviewer}`);
  if (review?.reviewedEdition) bits.push(`الطبعة: ${review.reviewedEdition}`);
  if (review?.reviewedPage) bits.push(`الصفحة: ${review.reviewedPage}`);
  if (review?.reviewedAt) bits.push(`تاريخ المراجعة: ${review.reviewedAt}`);
  return (
    `[اعتماد جماعي ${now.toISOString()}] ` +
    "طُبِّق استنادًا إلى سجلّ المراجعة البشرية، بعد التثبّت من أن النص " +
    "المخزَّن يطابق بصمة النص الذي قُرئ. لم تُقرأ الصفحة المطبوعة مجددًا " +
    `وقت الاعتماد. ${bits.join(" · ")}`
  );
}

/** Splits the live collection into what will be approved and what is refused. */
export function selectRecords(docs, byId) {
  const approving = [];
  const refused = [];
  for (const doc of docs ?? []) {
    const id = String(doc?.documentId ?? doc?.duaId ?? "").trim() || "(no id)";
    const review = byId.get(id);
    const reason = refusalReason(doc, review);
    if (reason) {
      refused.push({ documentId: id, reason });
      continue;
    }
    approving.push({ documentId: id, doc, review });
  }
  return { approving, refused };
}

export function documentUrl(plan, duaId) {
  return (
    `https://firestore.googleapis.com/v1/projects/${plan.projectId}` +
    `/databases/${plan.database}/documents/${plan.collection}` +
    `/${encodeURIComponent(duaId)}`
  );
}

export function buildApprovalWrite(row, plan, now = new Date()) {
  const existingNotes = String(row.doc.reviewNotes ?? "").trim();
  const note = approvalNote(row.review, now);
  const notes = existingNotes ? `${existingNotes}\n${note}` : note;

  const mask = APPROVAL_WRITE_FIELDS.map(
    (f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`,
  ).join("&");
  return {
    url: `${documentUrl(plan, row.documentId)}?${mask}`,
    fields: {
      verificationStatus: { stringValue: "verified" },
      verifiedAt: { timestampValue: now.toISOString() },
      verifiedBy: { stringValue: plan.verifiedBy },
      // Recomputed from the live text, not copied from the ledger. They are
      // equal by the time we get here — the refusal above guarantees it — and
      // deriving it here means the stored hash always describes the stored
      // text even if that guarantee were ever weakened.
      contentHash: { stringValue: contentHashOf(row.doc) },
      reviewNotes: { stringValue: notes },
      updatedAt: { timestampValue: now.toISOString() },
    },
  };
}

export async function approveOne(row, plan, deps = {}) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  const req = buildApprovalWrite(row, plan, deps.now ?? new Date());
  const res = await doFetch(req.url, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${plan.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ fields: req.fields }),
  });
  if (!res.ok) {
    throw new Error(`approval of ${row.documentId} failed: HTTP ${res.status}`);
  }
  return true;
}

/** Reads the record back. A 200 proves acceptance, not correctness. */
export async function verifyApproved(row, plan, deps = {}) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  const res = await doFetch(documentUrl(plan, row.documentId), {
    headers: { Authorization: `Bearer ${plan.token}` },
  });
  if (!res.ok) {
    throw new Error(`read-back of ${row.documentId} failed: HTTP ${res.status}`);
  }
  const body = await res.json();
  const doc = {};
  for (const [k, v] of Object.entries(body.fields ?? {})) {
    doc[k] = fromFirestoreValue(v);
  }
  if (doc.verificationStatus !== "verified") {
    throw new Error(`${row.documentId}: still "${doc.verificationStatus}"`);
  }
  if (String(doc.verifiedBy ?? "") !== plan.verifiedBy) {
    throw new Error(`${row.documentId}: verifiedBy is not the account given`);
  }
  // The text must still be the reviewed text after the write, or the record
  // is verified against something nobody read.
  if (contentHashOf(doc) !== String(row.review.reviewedTextHash)) {
    throw new Error(
      `${row.documentId}: stored text no longer matches the reviewed text`,
    );
  }
  return true;
}

export async function run(plan, deps = {}, log = console.log) {
  const ledger = deps.ledger ?? loadLedger();
  const byId = ledgerIndex(ledger);
  const docs = await listCollection(plan, deps);
  const { approving, refused } = selectRecords(docs, byId);

  log("");
  log(`collection:  ${plan.collection}`);
  log(`project:     ${plan.projectId}`);
  log(`verifiedBy:  ${plan.verifiedBy}`);
  log(`live docs:   ${docs.length}`);
  log(`to approve:  ${approving.length}`);
  log(`refused:     ${refused.length}`);
  for (const r of refused) log(`  - ${r.documentId}: ${r.reason}`);

  if (!plan.write) {
    log("");
    log("DRY RUN — nothing was written.");
    log("Every record above was matched against the hash of the text its");
    log("reviewer recorded reading. Re-run with --write plus:");
    log(`  --confirm-project=${plan.projectId} --confirm-count=${approving.length}`);
    return { approved: 0, refused: refused.length, planned: approving.length };
  }

  if (plan.confirmProject !== plan.projectId) {
    throw new Error("--confirm-project does not match the project targeted.");
  }
  if (plan.confirmCount !== approving.length) {
    throw new Error(
      `--confirm-count=${plan.confirmCount} does not match the ` +
        `${approving.length} record(s) this run would approve. The collection ` +
        "changed since the dry run; read the plan again.",
    );
  }

  let approved = 0;
  for (const row of approving) {
    await approveOne(row, plan, deps);
    await verifyApproved(row, plan, deps);
    approved += 1;
    log(`approved ${row.documentId}`);
  }

  log("");
  log(`done: ${approved} approved, ${refused.length} refused.`);
  log("Each carries a reviewNotes line naming the review it rests on.");
  return { approved, refused: refused.length, planned: approving.length };
}

/* c8 ignore start — CLI wiring, exercised by hand rather than tests */
async function main() {
  const args = parseArguments(process.argv.slice(2));
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const token = process.env.GOOGLE_ACCESS_TOKEN;
  if (!projectId || !token) {
    throw new Error(
      "FIREBASE_PROJECT_ID and GOOGLE_ACCESS_TOKEN must both be set.\n" +
        "Get a short-lived token with: gcloud auth print-access-token",
    );
  }
  await run({ ...args, projectId, token, database: "(default)" });
}

const isDirectRun =
  process.argv[1] && process.argv[1].endsWith("approve_supplications.mjs");
if (isDirectRun) {
  main().catch((err) => {
    console.error(`\n${err.message}`);
    process.exitCode = 1;
  });
}
/* c8 ignore stop */
