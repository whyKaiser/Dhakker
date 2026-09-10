// Guard tests for the bulk approval tool.
//
// `docs/CONTENT_APPROVAL.md` forbids bulk approval, and it is right to. This
// tool is narrower than that prohibition: it applies a review that is already
// recorded, and it can only do so for a record whose LIVE text still hashes
// to the value the reviewer wrote down.
//
// That hash comparison is the whole justification. If it can be bypassed,
// weakened, or made to pass for a text nobody read, the tool becomes the
// thing the document forbids. Most of what follows tests exactly that.

import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";

import {
  APPROVAL_WRITE_FIELDS,
  REQUIRED_PROVENANCE,
  approvalNote,
  assertOnlyKnownArguments,
  buildApprovalWrite,
  contentHashOf,
  ledgerIndex,
  parseArguments,
  refusalReason,
  run,
  selectRecords,
  verifyApproved,
} from "./approve_supplications.mjs";

const SOURCE = readFileSync("scripts/approve_supplications.mjs", "utf8");

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
  assert.ok(SOURCE.includes("forbids bulk approval"));
  assert.equal(codeOnly(SOURCE).includes("forbids bulk approval"), false);
  assert.ok(codeOnly(SOURCE).includes("reviewedTextHash"));
});

const AR = "اللهم لبيك";
const HASH = createHash("sha256")
  .update(`${AR}\u0000`, "utf8")
  .digest("hex");

const PLAN = {
  projectId: "p",
  database: "(default)",
  collection: "supplications",
  token: "ya29.SECRET",
  verifiedBy: "UID-123",
};

/** A record that is approvable in every respect, for mutation by each test. */
function approvable(extra = {}) {
  return {
    documentId: "dua-1",
    verificationStatus: "unverified",
    revokedAt: null,
    text: { ar: AR, en: "" },
    authority: "وزارة الشؤون الإسلامية",
    sourceUrl: "https://example.test/book.pdf",
    sourceVersion: "1446",
    sourceLanguage: "ar",
    reviewNotes: "",
    ...extra,
  };
}

function review(extra = {}) {
  return {
    recordId: "dua-1",
    reviewer: "whyKaiser",
    reviewStatus: "passed",
    textReviewStatus: "passed",
    reviewedTextHash: HASH,
    reviewedPage: 66,
    reviewedEdition: "المختصر — الطبعة الأولى 1446هـ",
    reviewedAt: "2026-08-21T06:20:00Z",
    ...extra,
  };
}

// ── The hash is the whole argument ────────────────────────────────────────

test("the hash matches the construction the ledger and the app use", () => {
  // Digests computed OUTSIDE this code. If this formula drifts, every
  // comparison below silently starts refusing (or worse, accepting) the
  // wrong records.
  assert.equal(
    contentHashOf({ text: { ar: "x", en: "y" } }),
    "ce3890a816f5237a17aa7e1436113bbac398dfe216cf965537cd035bdbad900a",
  );
  assert.equal(
    contentHashOf({ text: { ar: "", en: "" } }),
    "6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d",
  );
  assert.equal(contentHashOf({}), contentHashOf({ text: {} }));
});

test("a record whose text still matches what was reviewed is approvable", () => {
  assert.equal(refusalReason(approvable(), review()), null);
});

test("ONE changed character refuses the record", () => {
  // THE check. A text that drifted from what the reviewer read is a text
  // nobody read.
  const reason = refusalReason(
    approvable({ text: { ar: `${AR}.`, en: "" } }),
    review(),
  );
  assert.match(String(reason), /does not match the text that was reviewed/);
});

test("a changed English body also refuses, not just the Arabic", () => {
  assert.match(
    String(refusalReason(approvable({ text: { ar: AR, en: "added" } }), review())),
    /does not match/,
  );
});

test("a record with no ledger entry is refused", () => {
  // There is no recorded reading to apply, so there is nothing to apply.
  assert.match(
    String(refusalReason(approvable(), undefined)),
    /no ledger entry/,
  );
  assert.match(String(refusalReason(approvable(), null)), /no ledger entry/);
});

test("a ledger entry with no recorded hash is refused", () => {
  // Without the hash the tool cannot tell whether the live text is the
  // reviewed text, and "probably" is not a standard for this.
  for (const h of [undefined, null, "", "   "]) {
    assert.match(
      String(refusalReason(approvable(), review({ reviewedTextHash: h }))),
      /records no reviewedTextHash/,
    );
  }
});

test("the mismatch message carries neither hash nor text", () => {
  const reason = String(
    refusalReason(approvable({ text: { ar: "totally other", en: "" } }), review()),
  );
  assert.equal(reason.includes(HASH), false);
  assert.equal(reason.includes("totally other"), false);
});

// ── Every other refusal ───────────────────────────────────────────────────

test("a blocked review is never approved in bulk", () => {
  assert.match(
    String(
      refusalReason(
        approvable(),
        review({ reviewStatus: "blocked", blockReason: "omits_end_of_phrase" }),
      ),
    ),
    /review blocked \(omits_end_of_phrase\)/,
  );
});

test("a deployment hold is never lifted by an approval", () => {
  assert.match(
    String(
      refusalReason(
        approvable(),
        review({
          deploymentBlocked: true,
          deploymentBlockReason: "content_kind_not_yet_deployed",
        }),
      ),
    ),
    /deployment blocked \(content_kind_not_yet_deployed\)/,
  );
});

test("an explicit exclusion is honoured", () => {
  assert.equal(
    refusalReason(approvable(), review({ excludedFromImport: true })),
    "excludedFromImport",
  );
});

test("a ledger entry that does not record a pass is refused", () => {
  assert.match(
    String(
      refusalReason(
        approvable(),
        review({ reviewStatus: "pending", textReviewStatus: "pending" }),
      ),
    ),
    /does not record a passing text review/,
  );
});

test("an already-verified record is left alone", () => {
  assert.equal(
    refusalReason(approvable({ verificationStatus: "verified" }), review()),
    "already verified",
  );
});

test("a revoked record is not un-revoked in bulk", () => {
  // A withdrawal is a human decision; reversing it silently is the same
  // disrespect as ignoring an approval.
  assert.match(
    String(refusalReason(approvable({ revokedAt: "2026-01-01" }), review())),
    /revoked/,
  );
});

test("incomplete provenance is refused before the rules can reject it", () => {
  for (const field of REQUIRED_PROVENANCE) {
    const reason = refusalReason(approvable({ [field]: "" }), review());
    assert.match(String(reason), new RegExp(`missing ${field}`));
  }
});

test("a non-https source URL is refused", () => {
  for (const url of ["http://x.test/a", "example.test", "ftp://x"]) {
    assert.match(
      String(refusalReason(approvable({ sourceUrl: url }), review())),
      /not an https URL/,
    );
  }
});

test("selection separates the two lists and loses nothing", () => {
  const byId = ledgerIndex({
    reviews: [review(), review({ recordId: "dua-2" })],
  });
  const docs = [
    approvable(),
    approvable({ documentId: "dua-2", text: { ar: "changed", en: "" } }),
    approvable({ documentId: "dua-3" }),
  ];
  const { approving, refused } = selectRecords(docs, byId);
  assert.deepEqual(approving.map((a) => a.documentId), ["dua-1"]);
  assert.deepEqual(
    refused.map((r) => r.documentId),
    ["dua-2", "dua-3"],
  );
  assert.equal(approving.length + refused.length, docs.length);
});

// ── The write ─────────────────────────────────────────────────────────────

test("the write touches exactly six fields", () => {
  assert.deepEqual(
    [...APPROVAL_WRITE_FIELDS],
    [
      "verificationStatus",
      "verifiedAt",
      "verifiedBy",
      "contentHash",
      "reviewNotes",
      "updatedAt",
    ],
  );
  const req = buildApprovalWrite(
    { documentId: "dua-1", doc: approvable(), review: review() },
    PLAN,
    new Date(0),
  );
  const masked = [...req.url.matchAll(/updateMask\.fieldPaths=([^&]+)/g)].map((m) =>
    decodeURIComponent(m[1]),
  );
  assert.deepEqual(masked, [...APPROVAL_WRITE_FIELDS]);
  assert.deepEqual(Object.keys(req.fields), [...APPROVAL_WRITE_FIELDS]);
});

test("the text and the audio are outside the write", () => {
  const req = buildApprovalWrite(
    { documentId: "dua-1", doc: approvable(), review: review() },
    PLAN,
  );
  const serialised = req.url + JSON.stringify(req.fields);
  for (const f of ["text", "audioUrl", "audioMode", "isActive", "revokedAt"]) {
    assert.equal(serialised.includes(f), false, `${f} must not be written`);
  }
});

test("verifiedBy is the account named on the command line", () => {
  const req = buildApprovalWrite(
    { documentId: "dua-1", doc: approvable(), review: review() },
    PLAN,
  );
  assert.equal(req.fields.verifiedBy.stringValue, "UID-123");
  assert.equal(req.fields.verificationStatus.stringValue, "verified");
});

test("contentHash is derived from the live text, not copied from the ledger", () => {
  // If it were copied, a weakened refusal would let the stored hash describe
  // a text the document does not hold.
  const doc = approvable();
  const req = buildApprovalWrite(
    { documentId: "dua-1", doc, review: review({ reviewedTextHash: "WRONG" }) },
    PLAN,
  );
  assert.equal(req.fields.contentHash.stringValue, contentHashOf(doc));
  assert.notEqual(req.fields.contentHash.stringValue, "WRONG");
});

// ── Saying what actually happened ─────────────────────────────────────────

test("the note states that the page was not re-read", () => {
  // A record that claims more than what happened is worse than one that
  // claims less. This is the sentence that keeps the claim honest.
  const note = approvalNote(review(), new Date(0));
  assert.match(note, /اعتماد جماعي/);
  assert.match(note, /لم تُقرأ الصفحة المطبوعة مجددًا/);
});

test("the note names the review it rests on", () => {
  const note = approvalNote(review(), new Date(0));
  assert.match(note, /whyKaiser/);
  assert.match(note, /66/);
  assert.match(note, /2026-08-21/);
  assert.match(note, /الطبعة الأولى 1446هـ/);
});

test("an existing reviewNote is appended to, never replaced", () => {
  // The reviewer's own words about how they matched the text are the most
  // valuable thing in the record. Overwriting them would destroy the audit
  // trail this whole operation depends on.
  const req = buildApprovalWrite(
    {
      documentId: "dua-1",
      doc: approvable({ reviewNotes: "طوبق على ص66 من المطبوع" }),
      review: review(),
    },
    PLAN,
  );
  const notes = req.fields.reviewNotes.stringValue;
  assert.ok(notes.startsWith("طوبق على ص66 من المطبوع"));
  assert.match(notes, /اعتماد جماعي/);
});

// ── Arguments ─────────────────────────────────────────────────────────────

test("an unrecognised flag is refused, not ignored", () => {
  assert.throws(() => assertOnlyKnownArguments(["--force"]), /Unrecognised/);
  assert.throws(
    () => parseArguments(["--production", "--verified-by=u", "--all"]),
    /Unrecognised/,
  );
});

test("an accountable account must be named", () => {
  // verifiedBy is written into every record. There is no default and no
  // placeholder: somebody's name goes on this.
  assert.throws(
    () => parseArguments(["--production"]),
    /--verified-by=<uid> is required/,
  );
  assert.throws(
    () => parseArguments(["--production", "--verified-by=   "]),
    /required/,
  );
  assert.throws(
    () => parseArguments(["--production", "--verified-by=has space"]),
    /does not look like/,
  );
});

test("the destination is named explicitly", () => {
  assert.throws(() => parseArguments(["--verified-by=u"]), /exactly one/);
  assert.throws(
    () => parseArguments(["--production", "--staging", "--verified-by=u"]),
    /exactly one/,
  );
});

test("dry run is the default and a write needs both confirmations", () => {
  assert.equal(
    parseArguments(["--production", "--verified-by=u"]).write,
    false,
  );
  assert.throws(
    () => parseArguments(["--production", "--verified-by=u", "--write"]),
    /confirm-project/,
  );
  assert.throws(
    () => parseArguments(["--production", "--verified-by=u", "--confirm-count=1"]),
    /without --write/,
  );
});

// ── The run ───────────────────────────────────────────────────────────────

function backend(docs, calls = []) {
  return async (url, init = {}) => {
    const u = String(url);
    const method = init.method ?? "GET";
    calls.push({ url: u, method });
    if (u.includes("pageSize=")) {
      return new Response(
        JSON.stringify({
          documents: docs.map((d) => ({
            name: `projects/p/databases/(default)/documents/supplications/${d.documentId}`,
            fields: {
              verificationStatus: { stringValue: d.verificationStatus },
              revokedAt: { nullValue: null },
              authority: { stringValue: d.authority },
              sourceUrl: { stringValue: d.sourceUrl },
              sourceVersion: { stringValue: d.sourceVersion },
              sourceLanguage: { stringValue: d.sourceLanguage },
              reviewNotes: { stringValue: d.reviewNotes ?? "" },
              text: {
                mapValue: {
                  fields: {
                    ar: { stringValue: d.text.ar },
                    en: { stringValue: d.text.en ?? "" },
                  },
                },
              },
            },
          })),
        }),
        { status: 200 },
      );
    }
    if (method === "GET") {
      return new Response(
        JSON.stringify({
          fields: {
            verificationStatus: { stringValue: "verified" },
            verifiedBy: { stringValue: PLAN.verifiedBy },
            text: {
              mapValue: {
                fields: {
                  ar: { stringValue: AR },
                  en: { stringValue: "" },
                },
              },
            },
          },
        }),
        { status: 200 },
      );
    }
    return new Response("{}", { status: 200 });
  };
}

const LEDGER = { reviews: [review()] };

test("a dry run writes nothing", async () => {
  const calls = [];
  const printed = [];
  const result = await run(
    { ...PLAN, write: false },
    { fetch: backend([approvable()], calls), ledger: LEDGER },
    (l) => printed.push(String(l)),
  );
  assert.equal(result.approved, 0);
  assert.equal(result.planned, 1);
  assert.deepEqual(calls.filter((c) => c.method !== "GET"), []);
  assert.match(printed.join("\n"), /DRY RUN/);
});

test("a count that no longer matches stops the run before any write", async () => {
  const calls = [];
  await assert.rejects(
    () =>
      run(
        { ...PLAN, write: true, confirmProject: "p", confirmCount: 9 },
        { fetch: backend([approvable()], calls), ledger: LEDGER },
        () => {},
      ),
    /does not match/,
  );
  assert.deepEqual(calls.filter((c) => c.method !== "GET"), []);
});

test("a real run approves and reads each record back", async () => {
  const calls = [];
  const result = await run(
    { ...PLAN, write: true, confirmProject: "p", confirmCount: 1 },
    { fetch: backend([approvable()], calls), ledger: LEDGER },
    () => {},
  );
  assert.equal(result.approved, 1);
  assert.ok(calls.some((c) => c.method === "PATCH"));
});

test("a record whose text drifted is never written, even among good ones", async () => {
  const calls = [];
  const docs = [
    approvable(),
    approvable({ documentId: "dua-2", text: { ar: "drifted", en: "" } }),
  ];
  const ledger = { reviews: [review(), review({ recordId: "dua-2" })] };
  const result = await run(
    { ...PLAN, write: true, confirmProject: "p", confirmCount: 1 },
    { fetch: backend(docs, calls), ledger },
    () => {},
  );
  assert.equal(result.approved, 1);
  assert.equal(result.refused, 1);
  const patched = calls.filter((c) => c.method === "PATCH").map((c) => c.url);
  assert.equal(patched.length, 1);
  assert.equal(patched[0].includes("dua-2"), false);
});

test("the read-back refuses a write that did not take", async () => {
  const row = { documentId: "dua-1", doc: approvable(), review: review() };
  const cases = [
    [{ verificationStatus: { stringValue: "unverified" } }, /still "unverified"/],
    [
      {
        verificationStatus: { stringValue: "verified" },
        verifiedBy: { stringValue: "SOMEONE-ELSE" },
      },
      /verifiedBy is not the account given/,
    ],
    [
      {
        verificationStatus: { stringValue: "verified" },
        verifiedBy: { stringValue: PLAN.verifiedBy },
        text: { mapValue: { fields: { ar: { stringValue: "other" } } } },
      },
      /no longer matches the reviewed text/,
    ],
  ];
  for (const [fields, expected] of cases) {
    await assert.rejects(
      () =>
        verifyApproved(row, PLAN, {
          fetch: async () => new Response(JSON.stringify({ fields }), { status: 200 }),
        }),
      expected,
    );
  }
});

test("nothing it prints contains the access token", async () => {
  const printed = [];
  await run(
    { ...PLAN, token: "ya29.SUPER-SECRET", write: true, confirmProject: "p", confirmCount: 1 },
    { fetch: backend([approvable()]), ledger: LEDGER },
    (l) => printed.push(String(l)),
  );
  const all = printed.join("\n");
  assert.equal(all.includes("ya29"), false);
  assert.equal(all.includes("SUPER-SECRET"), false);
  assert.ok(all.includes("dua-1"));
});

// ── What the file must never contain ──────────────────────────────────────

test("there is no way to skip the hash comparison", () => {
  const code = codeOnly(SOURCE);
  for (const token of [
    "--force",
    "--skip-hash",
    "--no-verify",
    "skipHashCheck",
    "ignoreLedger",
  ]) {
    assert.equal(code.includes(token), false, `${token} must not exist`);
  }
  // The comparison itself, not a variable that could be set elsewhere.
  assert.ok(code.includes("live !== recorded"));
});

test("it reaches only Firestore", () => {
  const hosts = [...codeOnly(SOURCE).matchAll(/https:\/\/([a-z0-9.-]+)/g)].map(
    (m) => m[1],
  );
  assert.deepEqual([...new Set(hosts)], ["firestore.googleapis.com"]);
});

test("no key file and no ambient credential", () => {
  const code = codeOnly(SOURCE);
  for (const token of [
    "GOOGLE_APPLICATION_CREDENTIALS",
    "private_key",
    "serviceAccount.json",
    "firebase-admin",
  ]) {
    assert.equal(code.includes(token), false, `${token} must not appear`);
  }
});

// ── Against the real ledger ───────────────────────────────────────────────

test("the real ledger records a hash for every record it clears", () => {
  // If a cleared entry ever lacked one, this tool would silently refuse it
  // and the operator would not know why the count dropped.
  const ledger = JSON.parse(readFileSync("review/human_review_ledger.json", "utf8"));
  const cleared = ledger.reviews.filter(
    (r) =>
      (r.reviewStatus === "passed" || r.textReviewStatus === "passed") &&
      r.deploymentBlocked !== true &&
      r.excludedFromImport !== true &&
      r.reviewStatus !== "blocked",
  );
  assert.ok(cleared.length > 0, "the ledger clears nothing");
  const missing = cleared.filter((r) => !r.reviewedTextHash);
  assert.deepEqual(
    missing.map((r) => r.recordId),
    [],
    "cleared entries with no reviewedTextHash",
  );
});

test("every cleared entry names a human reviewer", () => {
  const ledger = JSON.parse(readFileSync("review/human_review_ledger.json", "utf8"));
  for (const r of ledger.reviews) {
    if (r.excludedFromImport === true) continue;
    assert.ok(
      typeof r.reviewer === "string" && r.reviewer.trim() !== "",
      `${r.recordId} has no reviewer`,
    );
  }
});
