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

## `relatedRecordIds` — pointing instead of copying

Printed page 73 says of Marwah: «ويقولَ مثل ما قال على الصفا». It prints no
independent text there. The wrong implementation is to copy the Safa dhikr
into a Marwah record — two copies of one religious text are two different
texts as soon as either is edited.

So `moia-1446-marwah-same` is `procedural_guidance` (an instruction, not a
recitation) and carries:

```json
"relatedRecordIds": ["moia-1446-safa-dhikr"]
```

The pointer is an **id**, never text. Rules:

- The importer is strict: the referenced id must exist **in the same pack**;
  no self-reference; no duplicates; entries must be non-empty strings. Each
  is a hard error. A dangling pointer would show the pilgrim an instruction
  to say something the app can no longer show them.
- The client is lenient in the one safe direction: a cached self-reference or
  duplicate is dropped (`SupplicationModel.sanitizeRelatedIds`), and an
  unresolvable pointer renders as no pointer at all rather than a dead link.
- The relationship affects **nothing** else: not recitability, not
  `verificationStatus`, not auto-play. `contentKind` still decides what a
  record is.
- The UI may only **point** at the canonical card («انظر: …»). It must never
  copy the target's text or offer its own play button — the pilgrim listens
  from the original card, so one text keeps one audio path.
- The Worker receives `relatedRecordIds` and is told it may say a record
  points elsewhere, but must not reproduce the pointed-to text under the
  pointing record's citation.

Because `masaa` is one polygon over the whole corridor, the single
`safa-dhikr` record is already reachable at Safa **and** at Marwah. The zone
geometry that created the trigger gap is what removes the need for a
duplicate.

## `usageNoteAr` — guidance lifted from the page

An optional per-record sentence taken from the printed source, displayed and
never spoken. It is not religious text and never joins what TTS reads: the
recitation is `text.ar` alone.

The scoping case it exists for: page 72 says the Safa Quran excerpt is read
once before Sa'i begins «ولا يقرؤها مرة أخرى», so «مثل ما قال على الصفا» at
Marwah reaches the dhikr and the pilgrim's own dua — not the verse. Both
cards say so explicitly rather than leaving the reader to infer the scope:

- `safa-ayah`: «تُقرأ عند الصفا مرة واحدة قبل بدء السعي، ولا تُعاد عند المروة.»
- `marwah-same`: names the Safa dhikr as what is repeated, and repeats the
  verse's exclusion.

The importer refuses an empty `usageNoteAr` — a blank instruction line reads
as "there is guidance here" while saying nothing. Omit the field instead.
