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

test("signed-in users can read supplications", async () => {
  await seed("d1", legacyRecord());
  await assertSucceeds(getDoc(doc(pilgrimDb(), "supplications", "d1")));
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
  await seed("d1", legacyRecord());
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
      zoneKey: "",
      ritualKey: "ihram",
      appliesToZoneKeys: MIQATS,
    });
    // Unverified: reviewed by nobody, must never surface.
    await setDoc(doc(db, "supplications/unreviewed"), {
      ...completeProvenance({ duaId: "unreviewed" }),
      verificationStatus: "unverified",
      verifiedAt: null,
      verifiedBy: null,
      zoneKey: "",
      appliesToZoneKeys: MIQATS,
    });
    // Verified but withdrawn from display.
    await setDoc(doc(db, "supplications/retired"), {
      ...completeProvenance({ duaId: "retired" }),
      isActive: false,
      zoneKey: "",
      appliesToZoneKeys: MIQATS,
    });
    // Verified and active, but scoped to one miqat only.
    await setDoc(doc(db, "supplications/one-miqat-only"), {
      ...completeProvenance({ duaId: "one-miqat-only" }),
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
