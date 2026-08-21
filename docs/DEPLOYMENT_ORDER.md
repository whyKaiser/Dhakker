# Deployment order — the read gate

`firestore.rules` now gates reads of `supplications` on three fields:
`isActive == true`, `verificationStatus == 'verified'`, `revokedAt == null`.
Every pilgrim-facing query must carry all three, because **Firestore rules
are not filters**: a query matching one document that fails the rule is
rejected in full with `permission-denied`. It does not return fewer results.

That makes the order of deployment a correctness issue, not a preference.
Ship the rules first and every already-installed copy of the app breaks at
once — the old build issues queries constrained only on `isActive`, and every
one of them starts failing.

## The order

### 1. Indexes first, and wait for READY

```
firebase deploy --only firestore:indexes
```

Then wait until every index reports **Enabled/READY** in the Firebase console
(Firestore → Indexes). A large collection can take minutes.

**Do not move on while any index is still building.** A building index fails
queries with `failed-precondition`, which reaches the pilgrim as an empty dua
list — the same thing they would see in a zone that genuinely has no texts.

Of the three indexes added for this gate, only the `appliesToZoneKeys` one is
strictly required (array-contains cannot be combined with equality filters
without a composite index). The `zoneKey` and `zoneId` variants would be
served by merging single-field indexes; they are declared for predictable
performance. Deploy all three anyway — the cost is nothing and the failure
mode is silent.

### 2. App and Worker that carry the new queries

Release the client build whose queries include all three constraints, and the
Worker alongside it. **Wait for real adoption** before step 4: an old build
still in a pilgrim's pocket does not update because a new one exists.

The queries are safe to run *before* the rules tighten — they are strictly
narrower than what the current rules already permit. That asymmetry is what
makes this order work: new queries against old rules succeed, old queries
against new rules fail.

### 3. Test on an actual device

Not in the emulator, and not only in CI:

- duas appear at a zone with verified content;
- the Talbiyah appears at **all three** mawaqit (`miqat_dhul_hulayfah`,
  `miqat_yalamlam`, `miqat_qarn_manazil`);
- an unverified record appears nowhere;
- the search screen (`duas_screen`) still lists results — it is a fourth
  retrieval path and is easy to forget;
- no `permission-denied` or `failed-precondition` in the logs.

### 4. Rules last

```
firebase deploy --only firestore:rules
```

Only after steps 1–3. This is the step that cannot be half-done: from the
moment it lands, any client still sending an under-constrained query gets
`permission-denied`.

## Rolling back

Rules roll back cleanly — redeploy the previous `firestore.rules` and old
clients work again. Indexes do not need rolling back; an unused index is
harmless.

What does **not** roll back is a record imported in the meantime. Keep the
import gates in place while any of this is in flight.

## If something goes wrong

`getSupplicationsByZone` records a `SupplicationQueryFailure` and logs a
diagnostic instead of returning a bare empty list. Two codes matter:

| code | meaning | fix |
|---|---|---|
| `failed-precondition` | a composite index is missing or still building | finish step 1, wait for READY |
| `permission-denied` | rules deployed ahead of the app, or a query is missing a constraint | roll the rules back, or fix the query |

Both otherwise present as "no duas here", which is why the diagnostic exists.
An empty list with **no** recorded failure means exactly what it says: this
zone has no verified texts.

## A note on what this gate will show today

All 85 records in the source pack are `unverified`, and nothing has been
imported. With the gate in place the app will show **no** supplications until
records are verified by an admin.

That is the intended behaviour, not a regression. Content nobody has checked
against the printed page does not reach a pilgrim, and an empty list is the
correct output of that rule — not a reason to loosen it.
