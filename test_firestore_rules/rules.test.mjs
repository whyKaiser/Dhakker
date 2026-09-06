// Firestore security-rules tests, run against the Firebase emulator.
//
//   npm --prefix test_firestore_rules install
//   npm --prefix test_firestore_rules test
//
// The `test` script boots the emulator via `firebase emulators:exec`, so no
// emulator needs to be running beforehand and no real project is touched.
//
// Focus: the provenance/verification contract. `supplications` records are
// ordinary CONTENT records — nothing about being in the collection implies
// any authority approved them. These tests pin down that (a) ordinary users
// can never write verification metadata, and (b) not even an admin can mark
// a record verified without complete provenance.

import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc,
  collection, query, where, getDocs,
} from "firebase/firestore";

const here = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(here, "..", "firestore.rules"), "utf8");

const ADMIN_UID = "admin-user";
const PILGRIM_UID = "pilgrim-user";

let testEnv;

/// Complete, valid provenance — the only shape that may be marked verified.
function completeProvenance(overrides = {}) {
  return {
    duaId: "dua-1",
    zoneId: "zone-1",
    title: { ar: "PLACEHOLDER AR", en: "PLACEHOLDER EN" },
    text: { ar: "PLACEHOLDER AR BODY", en: "PLACEHOLDER EN BODY" },
    tagsAr: ["tag"],
    tagsEn: ["tag"],
    languageCodes: ["ar", "en"],
    isActive: true,
    usage_count: 0,
    verificationStatus: "verified",
    authority: "Example Approving Authority",
    sourceUrl: "https://example.org/official/doc",
    sourceVersion: "2026-01",
    sourceLanguage: "ar",
    sourceSection: "p. 42",
    verifiedAt: new Date(),
    verifiedBy: ADMIN_UID,
    contentHash: "a".repeat(64),
    reviewNotes: "Matched against the official published edition.",
    ...overrides,
  };
}

/// An ordinary legacy record: real content, zero provenance.
function legacyRecord(overrides = {}) {
  return {
    duaId: "dua-legacy",
    zoneId: "zone-1",
    title: { ar: "PLACEHOLDER AR", en: "PLACEHOLDER EN" },
    text: { ar: "PLACEHOLDER AR BODY", en: "PLACEHOLDER EN BODY" },
    tagsAr: ["tag"],
    tagsEn: ["tag"],
    languageCodes: ["ar", "en"],
    isActive: true,
    usage_count: 0,
    ...overrides,
  };
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "dhakker-rules-test",
    firestore: {
      rules,
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  // Seed the role documents the rules read via get().
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users", ADMIN_UID), { role: "admin" });
    await setDoc(doc(db, "users", PILGRIM_UID), { role: "pilgrim" });
  });
});

const adminDb = () => testEnv.authenticatedContext(ADMIN_UID).firestore();
const pilgrimDb = () => testEnv.authenticatedContext(PILGRIM_UID).firestore();
const anonDb = () => testEnv.unauthenticatedContext().firestore();

async function seed(id, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "supplications", id), data);
  });
}

// ── Reads ────────────────────────────────────────────────────────────────

test("a signed-in pilgrim reads only verified, active, unrevoked records", async () => {
  // This test used to assert that any signed-in user could read ANY
  // supplication. That was the gap: a legacy record carries no
  // verificationStatus at all, and it was readable by document id no matter
  // how carefully the app filtered its queries.
  //
  // The gate now lives on the document. A bare legacy record fails it —
  // deliberately, and this is the fail-closed behaviour we want: content
  // nobody has verified does not reach a pilgrim, even when that means
  // showing nothing at all.
  await seed("d1", legacyRecord());
  await assertFails(getDoc(doc(pilgrimDb(), "supplications", "d1")));

  // The same record, once verified and explicitly unrevoked, is readable.
  await seed("d2", { ...completeProvenance({ duaId: "d2" }), revokedAt: null });
  await assertSucceeds(getDoc(doc(pilgrimDb(), "supplications", "d2")));
});

test("unauthenticated users cannot read supplications", async () => {
  await seed("d1", legacyRecord());
  await assertFails(getDoc(doc(anonDb(), "supplications", "d1")));
});

// ── Admin-only writes ────────────────────────────────────────────────────

test("a pilgrim cannot create a supplication", async () => {
  await assertFails(
    setDoc(doc(pilgrimDb(), "supplications", "new"), legacyRecord())
  );
});

test("a pilgrim cannot delete a supplication", async () => {
  await seed("d1", legacyRecord());
  await assertFails(deleteDoc(doc(pilgrimDb(), "supplications", "d1")));
});

test("an admin can create an unverified record", async () => {
  await assertSucceeds(
    setDoc(doc(adminDb(), "supplications", "new"), legacyRecord())
  );
});

test("an admin can delete a record", async () => {
  await seed("d1", legacyRecord());
  await assertSucceeds(deleteDoc(doc(adminDb(), "supplications", "d1")));
});

// ── Pilgrims may only bump usage_count ───────────────────────────────────

test("a pilgrim may increment usage_count", async () => {
  await seed("d1", legacyRecord());
  await assertSucceeds(
    updateDoc(doc(pilgrimDb(), "supplications", "d1"), { usage_count: 1 })
  );
});

test("a pilgrim may not edit content while bumping usage_count", async () => {
  await seed("d1", legacyRecord());
  await assertFails(
    updateDoc(doc(pilgrimDb(), "supplications", "d1"), {
      usage_count: 1,
      text: { ar: "TAMPERED", en: "TAMPERED" },
    })
  );
});

// ── Ordinary users can never touch verification metadata ─────────────────

test("a pilgrim cannot mark a record verified", async () => {
  await seed("d1", legacyRecord());
  await assertFails(
    updateDoc(doc(pilgrimDb(), "supplications", "d1"), {
      verificationStatus: "verified",
    })
  );
});

test("a pilgrim cannot set any individual provenance field", async () => {
  await seed("d1", legacyRecord());
  const forbidden = [
    { verificationStatus: "verified" },
    { authority: "Self-declared Authority" },
    { sourceUrl: "https://attacker.example/fake" },
    { sourceVersion: "9999" },
    { sourceLanguage: "ar" },
    { sourceSection: "p. 1" },
    { verifiedBy: PILGRIM_UID },
    { verifiedAt: new Date() },
    { contentHash: "b".repeat(64) },
    { reviewNotes: "looks fine to me" },
    { revokedAt: null },
  ];
  for (const patch of forbidden) {
    await assertFails(
      updateDoc(doc(pilgrimDb(), "supplications", "d1"), patch),
      `pilgrim must not write ${Object.keys(patch)[0]}`
    );
  }
});

test("a pilgrim cannot smuggle provenance alongside a usage_count bump", async () => {
  await seed("d1", legacyRecord());
  await assertFails(
    updateDoc(doc(pilgrimDb(), "supplications", "d1"), {
      usage_count: 1,
      verificationStatus: "verified",
      authority: "Self-declared Authority",
    })
  );
});

test("a pilgrim cannot create a record that is born verified", async () => {
  await assertFails(
    setDoc(doc(pilgrimDb(), "supplications", "new"), completeProvenance())
  );
});

// ── Incomplete records cannot be marked verified, even by an admin ───────

test("an admin CAN mark a record verified when provenance is complete", async () => {
  await assertSucceeds(
    setDoc(doc(adminDb(), "supplications", "ok"), completeProvenance())
  );
});

test("an admin cannot mark a record verified with a missing field", async () => {
  const required = [
    "authority",
    "sourceUrl",
    "sourceVersion",
    "sourceLanguage",
    "verifiedBy",
    "verifiedAt",
  ];
  for (const field of required) {
    const data = completeProvenance();
    delete data[field];
    await assertFails(
      setDoc(doc(adminDb(), "supplications", `missing-${field}`), data),
      `verified record must not be accepted without ${field}`
    );
  }
});

test("an admin cannot mark a record verified with an empty field", async () => {
  for (const field of [
    "authority",
    "sourceUrl",
    "sourceVersion",
    "sourceLanguage",
    "verifiedBy",
  ]) {
    await assertFails(
      setDoc(
        doc(adminDb(), "supplications", `empty-${field}`),
        completeProvenance({ [field]: "" })
      ),
      `verified record must not be accepted with an empty ${field}`
    );
  }
});

test("an admin cannot mark a record verified with a non-HTTPS source URL", async () => {
  for (const url of [
    "http://example.org/doc",
    "ftp://example.org/doc",
    "example.org/doc",
    "javascript:alert(1)",
  ]) {
    await assertFails(
      setDoc(
        doc(adminDb(), "supplications", "bad-url"),
        completeProvenance({ sourceUrl: url })
      ),
      `sourceUrl ${url} must be rejected`
    );
  }
});

test("an admin cannot flip an existing legacy record to verified without provenance", async () => {
  await seed("legacy", legacyRecord());
  await assertFails(
    updateDoc(doc(adminDb(), "supplications", "legacy"), {
      verificationStatus: "verified",
    })
  );
});

test("an admin CAN flip a legacy record to verified when supplying full provenance", async () => {
  await seed("legacy", legacyRecord());
  await assertSucceeds(
    updateDoc(doc(adminDb(), "supplications", "legacy"), {
      verificationStatus: "verified",
      authority: "Example Approving Authority",
      sourceUrl: "https://example.org/official/doc",
      sourceVersion: "2026-01",
      sourceLanguage: "ar",
      sourceSection: "p. 42",
      verifiedAt: new Date(),
      verifiedBy: ADMIN_UID,
      contentHash: "c".repeat(64),
    })
  );
});

test("an admin may freely save a record as unverified", async () => {
  await seed("d1", legacyRecord());
  await assertSucceeds(
    updateDoc(doc(adminDb(), "supplications", "d1"), {
      verificationStatus: "unverified",
      reviewNotes: "not yet matched to an official source",
    })
  );
});

// ── knowledge_* registry ─────────────────────────────────────────────────

test("pilgrims can read but not write knowledge_chunks", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "knowledge_chunks", "c1"), {
      documentId: "d1",
      content: "PLACEHOLDER",
    });
  });
  await assertSucceeds(getDoc(doc(pilgrimDb(), "knowledge_chunks", "c1")));
  await assertFails(
    setDoc(doc(pilgrimDb(), "knowledge_chunks", "c2"), { content: "x" })
  );
});

test("admins can write knowledge_chunks", async () => {
  await assertSucceeds(
    setDoc(doc(adminDb(), "knowledge_chunks", "c3"), { content: "PLACEHOLDER" })
  );
});

// ── supplications_staging: unreachable by every client ──────────────────
//
// Import trials write here through the Firestore REST API with a service
// account, which bypasses rules entirely. No CLIENT should ever reach it:
// the collection holds unreviewed records that must not surface to a
// pilgrim, and it is not the collection the app reads.
//
// These tests exercise the COMPLETE ruleset against the emulator, so they
// are the real regression guard. The explicit `match` block in
// firestore.rules is documentation and present-day defence — it cannot
// override anything, because Firestore combines matching rules with OR: a
// future broader `match` carrying a true `allow` would grant access no
// matter what that block says. Only behaviour catches that, and behaviour is
// what is asserted below.

const STAGING = "supplications_staging";

async function seedStaging(id, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), STAGING, id), data);
  });
}

/// Every client identity the rules distinguish.
function everyIdentity() {
  return [
    ["an unauthenticated user", anonDb()],
    ["an ordinary pilgrim", pilgrimDb()],
    // Admin matters most: `isAdmin()` is the widest grant in this file, so if
    // any future rule leaks the collection it will very likely leak it here
    // first.
    ["an admin", adminDb()],
  ];
}

test("no client identity can READ supplications_staging", async () => {
  await seedStaging("s1", legacyRecord({ duaId: "staging-1" }));
  for (const [who, db] of everyIdentity()) {
    await assertFails(getDoc(doc(db, STAGING, "s1")), `${who} could read`);
  }
});

test("no client identity can CREATE in supplications_staging", async () => {
  for (const [who, db] of everyIdentity()) {
    await assertFails(
      setDoc(doc(db, STAGING, `new-${who.replace(/\s/g, "-")}`), legacyRecord()),
      `${who} could create`,
    );
  }
});

test("no client identity can UPDATE in supplications_staging", async () => {
  await seedStaging("s1", legacyRecord({ duaId: "staging-1" }));
  for (const [who, db] of everyIdentity()) {
    await assertFails(
      updateDoc(doc(db, STAGING, "s1"), { usage_count: 99 }),
      `${who} could update`,
    );
  }
});

test("no client identity can DELETE from supplications_staging", async () => {
  await seedStaging("s1", legacyRecord({ duaId: "staging-1" }));
  for (const [who, db] of everyIdentity()) {
    await assertFails(
      deleteDoc(doc(db, STAGING, "s1")),
      `${who} could delete`,
    );
  }
});

test("an admin cannot promote a staging record to verified", async () => {
  // The staging collection is not a back door around the provenance gate.
  await seedStaging("s1", legacyRecord({ duaId: "staging-1" }));
  await assertFails(
    updateDoc(doc(adminDb(), STAGING, "s1"), {
      verificationStatus: "verified",
      verifiedBy: ADMIN_UID,
    }),
  );
});

// ── Regression guard: behaviour of the WHOLE ruleset ────────────────────

test("supplications_staging stays unreachable at every path shape", async () => {
  // A future `match` might be written at a different depth — a nested
  // subcollection, a wildcard segment, an oddly named document. Each shape
  // is checked, because a broader rule added at any of them would grant
  // access under Firestore's OR semantics regardless of the explicit deny.
  const paths = [
    [STAGING, "plain-id"],
    [STAGING, "id.with.dots"],
    [STAGING, "id-with-dashes"],
    [STAGING, "doc", "nested", "child"],
    [STAGING, "doc", "nested", "child", "deeper", "grandchild"],
  ];

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    for (const segments of paths) {
      await setDoc(doc(ctx.firestore(), ...segments), { seeded: true });
    }
  });

  for (const [who, db] of everyIdentity()) {
    for (const segments of paths) {
      const where = segments.join("/");
      await assertFails(
        getDoc(doc(db, ...segments)),
        `${who} could read ${where}`,
      );
      await assertFails(
        setDoc(doc(db, ...segments), { written: true }),
        `${who} could write ${where}`,
      );
    }
  }
});

test("the staging denial does not depend on the document existing", async () => {
  // An absent document must be as unreadable as a present one; otherwise a
  // client could probe the collection for which ids exist.
  for (const [who, db] of everyIdentity()) {
    await assertFails(
      getDoc(doc(db, STAGING, "definitely-absent")),
      `${who} could read an absent doc`,
    );
  }
});

test("production supplications behaviour is unchanged by the staging rule", async () => {
  // Guards the other direction: adding the staging block must not have
  // altered the collection the app actually reads.
  await seed("d1", { ...completeProvenance({ duaId: "d1" }), revokedAt: null });
  await assertSucceeds(getDoc(doc(pilgrimDb(), "supplications", "d1")));
  await assertFails(getDoc(doc(anonDb(), "supplications", "d1")));
});

// ── Ritual-scoped retrieval at the mawaqit ──────────────────────────────
//
// The Talbiyah carries `zoneKey: ""` because the source ties it to the rite,
// not to a place. It reaches a miqat through `appliesToZoneKeys`, and the
// app queries that together with `isActive` and `verificationStatus`.
//
// Why those two filters live in the QUERY and not in the client: this
// ruleset allows `allow read: if isSignedIn()` on `supplications`, with no
// per-document predicate. Rules are not filters. Anything the query does not
// constrain genuinely arrives on the device, so dropping unverified records
// after the fetch would ship them to the handset first.
//
// What this test does and does not prove: it exercises the real ruleset
// against the emulator, so it proves the query is permitted and that the
// filters select the right documents. It does NOT prove the composite index
// exists — the emulator serves any query without one. That index is declared
// in firestore.indexes.json and must be deployed; without it the production
// query fails and `getSupplicationsByZone` swallows the error into an empty
// list, so the Talbiyah would silently vanish from every miqat.

const MIQATS = [
  "miqat_dhul_hulayfah",
  "miqat_yalamlam",
  "miqat_qarn_manazil",
];

async function seedRitualFixtures() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    // Verified + active: the only one a pilgrim may be shown.
    await setDoc(doc(db, "supplications/talbiyah"), {
      ...completeProvenance({ duaId: "talbiyah" }),
      revokedAt: null,
      zoneKey: "",
      ritualKey: "ihram",
      appliesToZoneKeys: MIQATS,
    });
    // Unverified: reviewed by nobody, must never surface.
    await setDoc(doc(db, "supplications/unreviewed"), {
      ...completeProvenance({ duaId: "unreviewed" }),
      revokedAt: null,
      verificationStatus: "unverified",
      verifiedAt: null,
      verifiedBy: null,
      zoneKey: "",
      appliesToZoneKeys: MIQATS,
    });
    // Verified but withdrawn from display.
    await setDoc(doc(db, "supplications/retired"), {
      ...completeProvenance({ duaId: "retired" }),
      revokedAt: null,
      isActive: false,
      zoneKey: "",
      appliesToZoneKeys: MIQATS,
    });
    // Verified and active, but scoped to one miqat only.
    await setDoc(doc(db, "supplications/one-miqat-only"), {
      ...completeProvenance({ duaId: "one-miqat-only" }),
      revokedAt: null,
      zoneKey: "",
      appliesToZoneKeys: ["miqat_yalamlam"],
    });
  });
}

/** Exactly the query the app issues. */
function ritualQuery(db, zoneKey) {
  return query(
    collection(db, "supplications"),
    where("appliesToZoneKeys", "array-contains", zoneKey),
    where("isActive", "==", true),
    where("verificationStatus", "==", "verified"),
    where("revokedAt", "==", null),
  );
}

for (const miqat of MIQATS) {
  test(`a verified, active ritual text is retrievable at ${miqat}`, async () => {
    await seedRitualFixtures();
    const snap = await assertSucceeds(getDocs(ritualQuery(pilgrimDb(), miqat)));
    const ids = snap.docs.map((d) => d.id).sort();

    assert.ok(
      ids.includes("talbiyah"),
      `the Talbiyah must be reachable at ${miqat}`,
    );
    // Neither the unverified nor the retired record may come back, and the
    // query — not the client — is what excluded them.
    assert.ok(!ids.includes("unreviewed"));
    assert.ok(!ids.includes("retired"));
  });
}

test("a text scoped to one miqat does not appear at the others", async () => {
  await seedRitualFixtures();
  const at = async (m) =>
    (await getDocs(ritualQuery(pilgrimDb(), m))).docs.map((d) => d.id);

  assert.ok((await at("miqat_yalamlam")).includes("one-miqat-only"));
  assert.ok(!(await at("miqat_dhul_hulayfah")).includes("one-miqat-only"));
  assert.ok(!(await at("miqat_qarn_manazil")).includes("one-miqat-only"));
});

test("the ritual query is not permission-denied for an ordinary pilgrim", async () => {
  await seedRitualFixtures();
  // The whole point: an ordinary signed-in user runs this on every zone
  // change. If the ruleset ever narrows, this fails loudly here rather than
  // silently emptying the dua list on a pilgrim's phone mid-Umrah.
  await assertSucceeds(getDocs(ritualQuery(pilgrimDb(), MIQATS[0])));
});

test("an unauthenticated client cannot run the ritual query at all", async () => {
  await seedRitualFixtures();
  await assertFails(getDocs(ritualQuery(anonDb(), MIQATS[0])));
});

test("a ritual text is returned once, even though two paths could match it", async () => {
  // A record carrying BOTH a zoneKey and an appliesToZoneKeys entry matches
  // the zoneKey query and the ritual query. The service merges by duaId, so
  // the pilgrim must not see it twice.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "supplications/double-match"), {
      ...completeProvenance({ duaId: "double-match" }),
      revokedAt: null,
      zoneKey: "miqat_yalamlam",
      appliesToZoneKeys: ["miqat_yalamlam"],
    });
  });
  const db = pilgrimDb();
  const byZoneKey = await getDocs(
    query(
      collection(db, "supplications"),
      where("zoneKey", "==", "miqat_yalamlam"),
      where("isActive", "==", true),
      where("verificationStatus", "==", "verified"),
      where("revokedAt", "==", null),
    ),
  );
  const byRitual = await getDocs(ritualQuery(db, "miqat_yalamlam"));

  const merged = new Map();
  for (const snap of [byZoneKey, byRitual]) {
    for (const d of snap.docs) {
      if (!merged.has(d.id)) merged.set(d.id, d);
    }
  }
  assert.equal(
    [...merged.keys()].filter((k) => k === "double-match").length,
    1,
    "a record matching two retrieval paths must be merged, not duplicated",
  );
});

// ── The read gate ───────────────────────────────────────────────────────
//
// `allow read: if isSignedIn()` used to let any signed-in user fetch any
// supplication BY DOCUMENT ID, however carefully the app filtered its
// queries. Client-side filtering never closed that door — it only stopped
// the app walking through it.
//
// The gate is now three conditions, applied to the document itself:
// isActive, verificationStatus == 'verified', revokedAt == null.

function readableDoc(overrides = {}) {
  return { ...completeProvenance(), revokedAt: null, ...overrides };
}

async function seedReadGateFixtures() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "supplications/ok"), readableDoc({ duaId: "ok" }));
    await setDoc(
      doc(db, "supplications/unverified-doc"),
      readableDoc({
        duaId: "unverified-doc",
        verificationStatus: "unverified",
        verifiedAt: null,
        verifiedBy: null,
      }),
    );
    await setDoc(
      doc(db, "supplications/inactive-doc"),
      readableDoc({ duaId: "inactive-doc", isActive: false }),
    );
    await setDoc(
      doc(db, "supplications/revoked-doc"),
      readableDoc({ duaId: "revoked-doc", revokedAt: new Date() }),
    );
  });
}

for (const id of ["unverified-doc", "inactive-doc", "revoked-doc"]) {
  test(`an ordinary pilgrim cannot get ${id} by document id`, async () => {
    await seedReadGateFixtures();
    await assertFails(getDoc(doc(pilgrimDb(), `supplications/${id}`)));
  });

  test(`an unauthenticated client cannot get ${id} either`, async () => {
    await seedReadGateFixtures();
    await assertFails(getDoc(doc(anonDb(), `supplications/${id}`)));
  });

  test(`an admin CAN get ${id}, because review requires reading it`, async () => {
    await seedReadGateFixtures();
    await assertSucceeds(getDoc(doc(adminDb(), `supplications/${id}`)));
  });
}

test("a pilgrim can still get a verified, active, unrevoked record", async () => {
  await seedReadGateFixtures();
  // The gate must not be so tight that approved content stops working.
  await assertSucceeds(getDoc(doc(pilgrimDb(), "supplications/ok")));
});

test("an unfiltered list is refused outright, not silently narrowed", async () => {
  await seedReadGateFixtures();
  // Rules are not filters: this query matches unverified documents, so the
  // WHOLE query fails. That is the behaviour the app's filters exist to
  // avoid, and the reason all three constraints are mandatory.
  await assertFails(getDocs(collection(pilgrimDb(), "supplications")));
});

test("a query missing the verificationStatus constraint fails", async () => {
  await seedReadGateFixtures();
  await assertFails(
    getDocs(
      query(
        collection(pilgrimDb(), "supplications"),
        where("isActive", "==", true),
        where("revokedAt", "==", null),
      ),
    ),
  );
});

test("a query missing the isActive constraint fails", async () => {
  await seedReadGateFixtures();
  await assertFails(
    getDocs(
      query(
        collection(pilgrimDb(), "supplications"),
        where("verificationStatus", "==", "verified"),
        where("revokedAt", "==", null),
      ),
    ),
  );
});

test("a query missing the revokedAt constraint fails", async () => {
  await seedReadGateFixtures();
  await assertFails(
    getDocs(
      query(
        collection(pilgrimDb(), "supplications"),
        where("isActive", "==", true),
        where("verificationStatus", "==", "verified"),
      ),
    ),
  );
});

test("the fully constrained query succeeds and returns only the good record", async () => {
  await seedReadGateFixtures();
  const snap = await assertSucceeds(
    getDocs(
      query(
        collection(pilgrimDb(), "supplications"),
        where("isActive", "==", true),
        where("verificationStatus", "==", "verified"),
        where("revokedAt", "==", null),
      ),
    ),
  );
  assert.deepEqual(snap.docs.map((d) => d.id), ["ok"]);
});

test("an admin may list records awaiting review", async () => {
  await seedReadGateFixtures();
  const snap = await assertSucceeds(
    getDocs(
      query(
        collection(adminDb(), "supplications"),
        where("verificationStatus", "==", "unverified"),
      ),
    ),
  );
  assert.ok(snap.docs.some((d) => d.id === "unverified-doc"));
});

// ── supplications_legacy_archive: unreachable by every client ───────────
//
// The archive holds full copies of documents retired from `supplications`.
// It is written once, by hand, with a service-account credential that
// bypasses rules entirely; no client has any business reading it.
//
// The stakes are the mirror image of the staging collection's. Staging holds
// records not yet fit to publish; the archive holds records judged unfit and
// withdrawn. A rule that leaked it would put exactly the text the retirement
// removed back in front of a pilgrim — and it would do so with the original
// audioUrl attached, since the archive copy is complete by design.
//
// As with staging, the `if false` block in firestore.rules cannot override a
// future broader rule (Firestore combines matching rules with OR). These
// behavioural tests over the complete ruleset are the actual guard.

const ARCHIVE = "supplications_legacy_archive";

async function seedArchive(id, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), ARCHIVE, id), data);
  });
}

/** A retired legacy document: unverified, no contentKind, audio attached —
 *  the shape the live reconciliation reported for all 16. */
function retiredRecord(overrides = {}) {
  return legacyRecord({
    duaId: "legacy-archived-1",
    audioMode: "file",
    audioUrl: "https://firebasestorage.googleapis.com/v0/b/x/o/a.mp3?token=T",
    ...overrides,
  });
}

test("no client identity can READ supplications_legacy_archive", async () => {
  await seedArchive("a1", retiredRecord());
  for (const [who, db] of everyIdentity()) {
    await assertFails(getDoc(doc(db, ARCHIVE, "a1")), `${who} could read`);
  }
});

test("no client identity can LIST supplications_legacy_archive", async () => {
  await seedArchive("a1", retiredRecord());
  await seedArchive("a2", retiredRecord({ duaId: "legacy-archived-2" }));
  for (const [who, db] of everyIdentity()) {
    await assertFails(getDocs(collection(db, ARCHIVE)), `${who} could list`);
  }
});

test("no client identity can CREATE, UPDATE or DELETE in the archive", async () => {
  await seedArchive("a1", retiredRecord());
  for (const [who, db] of everyIdentity()) {
    await assertFails(
      setDoc(doc(db, ARCHIVE, `new-${who.replace(/\s/g, "-")}`), retiredRecord()),
      `${who} could create`,
    );
    await assertFails(
      updateDoc(doc(db, ARCHIVE, "a1"), { usage_count: 99 }),
      `${who} could update`,
    );
    await assertFails(deleteDoc(doc(db, ARCHIVE, "a1")), `${who} could delete`);
  }
});

test("an admin cannot resurrect an archived record by marking it verified", async () => {
  // The archive is not a back door around the provenance gate, and not a
  // staging area for republishing. Restoring a record is a deliberate act
  // that goes back through the normal write path, not an edit in place.
  await seedArchive("a1", retiredRecord());
  await assertFails(
    updateDoc(doc(adminDb(), ARCHIVE, "a1"), {
      verificationStatus: "verified",
      verifiedBy: ADMIN_UID,
    }),
  );
});

test("the archive stays unreachable at every path shape", async () => {
  const paths = [
    [ARCHIVE, "plain-id"],
    [ARCHIVE, "id.with.dots"],
    [ARCHIVE, "id-with-dashes"],
    [ARCHIVE, "doc", "nested", "child"],
    [ARCHIVE, "doc", "nested", "child", "deeper", "grandchild"],
  ];

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    for (const segments of paths) {
      await setDoc(doc(ctx.firestore(), ...segments), { seeded: true });
    }
  });

  for (const [who, db] of everyIdentity()) {
    for (const segments of paths) {
      const where = segments.join("/");
      await assertFails(getDoc(doc(db, ...segments)), `${who} could read ${where}`);
      await assertFails(
        setDoc(doc(db, ...segments), { written: true }),
        `${who} could write ${where}`,
      );
    }
  }
});

test("the archive denial does not depend on the document existing", async () => {
  for (const [who, db] of everyIdentity()) {
    await assertFails(
      getDoc(doc(db, ARCHIVE, "definitely-absent")),
      `${who} could probe for an absent archive doc`,
    );
  }
});

test("adding the archive rule left supplications itself unchanged", async () => {
  await seed("keep-1", { ...completeProvenance({ duaId: "keep-1" }), revokedAt: null });
  await assertSucceeds(getDoc(doc(pilgrimDb(), "supplications", "keep-1")));
  await assertSucceeds(getDoc(doc(adminDb(), "supplications", "keep-1")));
});

// ── Family groups: live GPS of pilgrims ──────────────────────────────────
//
// The most sensitive data in the product. These tests re-enact, in full, the
// three-step attack the previous rules allowed — proven against the emulator
// before the fix:
//
//   1. list `groups`            → every group, and every join code, visible
//   2. create members/{me}      → join any group with no code at all
//   3. list members             → read the family's live coordinates
//
// Each step is asserted closed. They fail if any future rule reopens one.

const OWNER_UID = "family-owner";
const RELATIVE_UID = "family-relative";
const STRANGER_UID = "unrelated-stranger";

const GROUP_ID = "group-1";
const GROUP_CODE = "HAJJ-4821";

const ownerDb = () => testEnv.authenticatedContext(OWNER_UID).firestore();
const relativeDb = () => testEnv.authenticatedContext(RELATIVE_UID).firestore();
const strangerDb = () => testEnv.authenticatedContext(STRANGER_UID).firestore();

/// A group whose owner and one relative are already members, the relative
/// sharing a live location. Seeded past the rules, as real usage would leave it.
async function seedGroup() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "groups", GROUP_ID), {
      name: "عائلتي", code: GROUP_CODE, ownerId: OWNER_UID,
    });
    await setDoc(doc(db, "group_codes", GROUP_CODE), {
      groupId: GROUP_ID, ownerId: OWNER_UID,
    });
    await setDoc(doc(db, "groups", GROUP_ID, "members", OWNER_UID), {
      name: "الأب", joinCode: GROUP_CODE,
    });
    await setDoc(doc(db, "groups", GROUP_ID, "members", RELATIVE_UID), {
      name: "الأم", joinCode: GROUP_CODE, lat: 21.4225, lng: 39.8262,
    });
  });
}

test("step 1 is closed: nobody can list groups, so no code can be harvested", async () => {
  await seedGroup();
  for (const [who, db] of [
    ["a stranger", strangerDb()], ["an admin", adminDb()],
    ["the owner", ownerDb()], ["an anonymous client", anonDb()],
  ]) {
    await assertFails(
      getDocs(collection(db, "groups")),
      `${who} could enumerate groups`,
    );
  }
});

test("step 1 is closed: a code cannot be found by querying the code field", async () => {
  await seedGroup();
  await assertFails(
    getDocs(query(collection(strangerDb(), "groups"), where("code", "==", GROUP_CODE))),
  );
});

test("step 1 is closed: group_codes cannot be enumerated either", async () => {
  await seedGroup();
  await assertFails(getDocs(collection(strangerDb(), "group_codes")));
});

test("step 2 is closed: a stranger cannot join without presenting the code", async () => {
  await seedGroup();
  await assertFails(
    setDoc(doc(strangerDb(), "groups", GROUP_ID, "members", STRANGER_UID), {
      name: "دخيل",
    }),
  );
});

test("step 2 is closed: a wrong or absent code is refused", async () => {
  await seedGroup();
  for (const joinCode of ["HAJJ-0000", "", "hajj-4821", null]) {
    await assertFails(
      setDoc(doc(strangerDb(), "groups", GROUP_ID, "members", STRANGER_UID), {
        name: "دخيل", joinCode,
      }),
      `joinCode ${JSON.stringify(joinCode)} was accepted`,
    );
  }
});

test("step 2 is closed: joining cannot be smuggled in as an update", async () => {
  // `update` is not gated on the code, so the question is whether it can
  // conjure a membership that `create` refuses. It cannot: Firestore rejects
  // an update to a document that does not exist. Asserted on the OUTCOME
  // rather than the error code — this one comes back NOT_FOUND, not
  // PERMISSION_DENIED, and the security property is that no membership
  // appears, not which of the two refusals fires.
  await seedGroup();
  await assert.rejects(
    updateDoc(doc(strangerDb(), "groups", GROUP_ID, "members", STRANGER_UID), {
      name: "دخيل",
    }),
  );
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const snap = await getDoc(
      doc(ctx.firestore(), "groups", GROUP_ID, "members", STRANGER_UID),
    );
    assert.equal(snap.exists(), false, "an update created a membership");
  });
});

test("step 3 is closed: a non-member cannot read the members' locations", async () => {
  await seedGroup();
  await assertFails(getDocs(collection(strangerDb(), "groups", GROUP_ID, "members")));
  await assertFails(
    getDoc(doc(strangerDb(), "groups", GROUP_ID, "members", RELATIVE_UID)),
  );
});

test("step 3 is closed: an admin is not a member and reads no locations", async () => {
  // Admin is a CONTENT role. It carries no entitlement to family locations.
  await seedGroup();
  await assertFails(getDocs(collection(adminDb(), "groups", GROUP_ID, "members")));
  await assertFails(getDoc(doc(adminDb(), "groups", GROUP_ID)));
});

test("the group document itself is not readable by a non-member", async () => {
  await seedGroup();
  await assertFails(getDoc(doc(strangerDb(), "groups", GROUP_ID)));
});

// ── The legitimate flows still work ──────────────────────────────────────

test("someone who knows the code resolves it and joins", async () => {
  await seedGroup();
  const db = strangerDb();
  const pointer = await assertSucceeds(getDoc(doc(db, "group_codes", GROUP_CODE)));
  assert.equal(pointer.data().groupId, GROUP_ID);
  await assertSucceeds(
    setDoc(doc(db, "groups", GROUP_ID, "members", STRANGER_UID), {
      name: "قريب", joinCode: GROUP_CODE,
    }),
  );
  // …and only then can read the group and its members.
  await assertSucceeds(getDocs(collection(db, "groups", GROUP_ID, "members")));
  await assertSucceeds(getDoc(doc(db, "groups", GROUP_ID)));
});

test("a member updates only their own location, never anyone else's", async () => {
  await seedGroup();
  await assertSucceeds(
    setDoc(doc(relativeDb(), "groups", GROUP_ID, "members", RELATIVE_UID),
      { lat: 21.4, lng: 39.8 }, { merge: true }),
  );
  await assertFails(
    setDoc(doc(relativeDb(), "groups", GROUP_ID, "members", OWNER_UID),
      { lat: 0, lng: 0 }, { merge: true }),
  );
});

test("a member leaves by deleting only their own membership", async () => {
  await seedGroup();
  await assertFails(
    deleteDoc(doc(relativeDb(), "groups", GROUP_ID, "members", OWNER_UID)),
  );
  await assertSucceeds(
    deleteDoc(doc(relativeDb(), "groups", GROUP_ID, "members", RELATIVE_UID)),
  );
});

test("the owner creates a group and claims its code", async () => {
  const db = ownerDb();
  await assertSucceeds(
    setDoc(doc(db, "groups", "new-group"), {
      name: "مجموعة", code: "HAJJ-1111", ownerId: OWNER_UID,
    }),
  );
  await assertSucceeds(
    setDoc(doc(db, "group_codes", "HAJJ-1111"), {
      groupId: "new-group", ownerId: OWNER_UID,
    }),
  );
});

test("a group cannot be created in someone else's name", async () => {
  await assertFails(
    setDoc(doc(strangerDb(), "groups", "forged"), {
      name: "مزوّرة", code: "HAJJ-2222", ownerId: OWNER_UID,
    }),
  );
  await assertFails(
    setDoc(doc(strangerDb(), "group_codes", "HAJJ-2222"), {
      groupId: "forged", ownerId: OWNER_UID,
    }),
  );
});

test("a claimed code can never be repointed or deleted", async () => {
  // Otherwise an attacker could hijack a circulating code and redirect
  // everyone who joins with it into a group they control.
  await seedGroup();
  for (const [who, db] of [
    ["the owner", ownerDb()], ["a stranger", strangerDb()], ["an admin", adminDb()],
  ]) {
    await assertFails(
      updateDoc(doc(db, "group_codes", GROUP_CODE), { groupId: "attacker-group" }),
      `${who} could repoint a claimed code`,
    );
    await assertFails(
      deleteDoc(doc(db, "group_codes", GROUP_CODE)),
      `${who} could delete a claimed code`,
    );
  }
});

test("an unauthenticated client touches none of it", async () => {
  await seedGroup();
  const db = anonDb();
  await assertFails(getDoc(doc(db, "group_codes", GROUP_CODE)));
  await assertFails(getDoc(doc(db, "groups", GROUP_ID)));
  await assertFails(getDocs(collection(db, "groups", GROUP_ID, "members")));
  await assertFails(
    setDoc(doc(db, "groups", GROUP_ID, "members", "anon"), { joinCode: GROUP_CODE }),
  );
});
