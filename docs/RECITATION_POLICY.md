# `recitationPolicy` — how a text is performed

`contentKind` decides **whether** a record may be recited at all, and stays
authoritative. `recitationPolicy` only describes **how** a recitable text is
performed: once or three times, at which moment, whether the pilgrim's own
dua goes between the repetitions, and whether the app is allowed to start it
without being asked.

A policy never grants recitability. Putting `repeatCount: 3` on a
`procedural_guidance` record does not make it playable, and there is a test
that says so.

## The semantic trigger gap at Safa

`masaa` is one polygon covering the whole Sa'i corridor. Entering it proves
the pilgrim is *somewhere* in the Sa'i — it does **not** prove they are on
their first approach to Safa. The app has no event that means "first Safa
approach": the only automatic signal is `Geolocator.getPositionStream` →
`ZoneDetectionService.detectBestZone(...)` → a single `ZoneModel`, and
`currentRitual` returns `'tawaf'` / `'sai'` / `null` — a zone classifier,
not a ritual session identity.

So `moia-1446-safa-ayah` and `moia-1446-safa-dhikr` declare:

```json
"autoPlayCapability": "manual_only_until_trigger_supported"
```

which sets `RecitationPolicy.blocksAutoPlay`, which removes them from
`HomeDuaController.autoPlayableDuas`.

The block is **fail-closed in one direction only**:

| path | Safa records |
|---|---|
| location-driven auto-play | blocked |
| the pilgrim's audio button | works |
| voice search | works (guarded on `canPlayManually`) |
| visible in the dua section | yes, with the instruction note |

Blocking a text from being read **to** someone is not blocking them from
reading it. The two are separated in the model:

- `canPlayManually` — `contentKind` only.
- `isAutoPlayable` — `canPlayManually` **and** the usage qualifier permits
  it **and** the policy does not block it.

`duas_screen.dart` guards `_playDua` on `canPlayManually`; the controller
selects auto-play on `isAutoPlayable`.

The capability is written explicitly in the pack. It is never inferred from
a record's id, title, zone, or trigger — and `test/safa_trigger_gap_test.dart`
asserts no source file branches on those record ids.

The importer enforces the pairing from the other side: a record declaring
`trigger: "first_safa_approach"` **must** also declare the manual-only
capability, or the import fails. A future trigger the app can genuinely
detect is added by adding the event first, then dropping the capability.

## `once_per_ritual` is not fully enforced

`HomeDuaController._playedOncePerRitual` is an in-memory `Set<String>` on the
controller instance. It is never persisted, and `resetRitualPlaybackState()`
is never called — the app has **no durable ritual-session identifier**
anywhere. Two consequences, neither of which may be claimed away:

- restarting the app mid-Umrah clears the set;
- a controller alive across two Umrahs keeps it, suppressing in the second.

So `once_per_ritual` is today (1) an instruction shown to the pilgrim, and
(2) a within-session brake on auto-play. The `manual_only_...` capability is
what makes this limitation harmless right now for the two records that carry
it — not what makes it absent. `resetRitualPlaybackState()` is left as an
explicit hook for whoever adds a ritual session id.

## `repeatCount` is informational

`repeatCount: 3` is displayed («يُكرَّر 3 مرات، ويدعو بين المرات») and
nothing else. No code loops audio:

- one button press = exactly one playback;
- neither voice search nor a location event can start three repetitions;
- the stored `text.ar` holds **one** recitation, never three concatenated;
- `autoRepeat` is `false` on every policy in the pack, and parsing forces it
  false whenever an `interleave` is present.

`test/recitation_policy_test.dart` asserts that
`dua_playback_service.dart`, `home_dua_controller.dart` and `duas_screen.dart`
contain no reference to `repeatCount` at all. A player that "helpfully"
repeated three times would speak over the dua the pilgrim is meant to make
between them.

## Strict importer, lenient client — on purpose

The two sides of the vocabulary behave differently, and the asymmetry is the
design, not an inconsistency:

**The importer (`scripts/import_source_pack.mjs`) is strict.** An unknown
`frequency`, `trigger`, `interleave`, `autoPlayCapability`, `contentKind`,
`usageQualifier`, `zoneKey`, reference type/kind, or an unexpected key inside
`recitationPolicy` is a **hard error** that aborts the import. Nothing
unrecognised reaches the database. The pack is authored by hand, so a typo
there is a mistake to be caught, not a value to be tolerated.

**The client (`SupplicationModel` / `RecitationPolicy.fromJson`) is
lenient.** An unknown value is **dropped and read as absent**, never carried
and never guessed:

- an unknown `frequency` (including a fabricated `"mandatory"`) → the whole
  policy reads as `null`;
- an unknown `trigger`, `interleave`, or `autoPlayCapability` → that field is
  `null`, the rest of the policy survives;
- a missing policy → previous behaviour, unchanged.

This is safe in one direction only, and only because every value in this
vocabulary is a **restriction**. An older client that has never heard of a
newer capability loses the restriction, not the text — so a newer restriction
must always be paired with a server- or importer-side guarantee if it must
hold on old clients. An old client is never made to honour a rule it cannot
understand, and it is never allowed to invent one.

Tests hold both halves: the importer suite asserts the hard errors, and
`recitation_policy_test.dart` / `safa_trigger_gap_test.dart` assert the
client's silent drop.
