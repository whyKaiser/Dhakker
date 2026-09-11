# Audio inventory and the canonical-text rule

## Current state, stated precisely

**Audio is live.** All 53 approved records carry an `audioUrl` and play a
stored recording; device TTS is now only the fallback for a record that has
none. The files were generated with the Google Cloud Text-to-Speech voice
`ar-XA-Chirp3-HD-Algieba` and published by
`review/publish-algieba-audio.mjs`.

Still true, and worth keeping straight: there are **zero audio files in this
repository**. They live in Cloud Storage under `audio/duas/`, and the repo
holds only the tools that put them there.

The bucket also contains older objects from before this run — hand-uploaded
recordings named by document id, and four seed files (`D_TAWAF_01.mp3` and
friends). They are unreferenced by any current record. Harmless, and not yet
cleaned up.

## How many files are needed

| | count |
|---|---|
| records in the pack | 85 |
| recitable (`specific_text`, `general_dua`, `general_dhikr`, `mosque_entry`) | 59 |
| non-recitable — guidance and evidence, **never** voiced | 26 |
| **unique canonical texts among the recitable 59** | **58** |

58, not 59, because two records hold the same canonical text:
`moia-mukhtasar-1446-tawaf-between-corners` (p69, location-specific, between
the two corners) and `moia-mukhtasar-1446-general-001` (p94, general dua) both
carry البقرة 201. They stay two records — the ministry prints the ayah twice
under different classifications, and collapsing them would erase a real
distinction — but they must **share one audio file**. One text, one
recitation, one set of bytes.

These were 60 and 59 until the page-64 review. The mosque-entry hadith
(`…-entering-masjid-hadith`) was reclassified `contextual_evidence`: the
ministry uses that narration as the evidence for the wording set out just
above it, not as a wording to recite, and voicing it would read the narrator's
instructions — «إذا دخل أحدكم … وإذا خرج فليقل …» — to the pilgrim as though
they were his supplication. So it needs no audio file, and one recitable text
left the set. The record it evidences, `…-entering-masjid`, stays recitable
and still needs its own file.

All 59 are `ar` only; **no record has `text.en`**, so no English audio is
implied by the current pack.

## How many are eligible to record today

The 58 above is the **whole** canonical set. It is not the number of files
that can be produced now: four recitable records are held back, and a held
record must not be voiced while it is held — an audio file is a second
playback path around the hold.

| | count |
|---|---|
| unique canonical recitable texts (total) | **58** |
| unique texts **eligible for audio today** | **54** |

The four held recitable records, with the reason on each:

| record | why it is held |
|---|---|
| `moia-mukhtasar-1446-general-009` | `reviewStatus: blocked` — ministry_source_omits_end_of_quranic_phrase; also excludedFromImport |
| `moia-mukhtasar-1446-umrah-talbiyah-ziyadah` | `deploymentBlocked` — optionality_not_yet_supported; excludedFromImport |
| `moia-1446-safa-ayah` | `deploymentBlocked` — recitation_policy_not_yet_deployed; excludedFromImport |
| `moia-1446-safa-dhikr` | `deploymentBlocked` — recitation_policy_not_yet_deployed; excludedFromImport |

58 − 4 = 54 here only because none of the four shares its text with another
record. The one shared text in the pack —
`moia-mukhtasar-1446-tawaf-between-corners` and
`moia-mukhtasar-1446-general-001`, both البقرة 201 — is intact on the
eligible side: two records, one file, counted once in both numbers. Had a
held record shared a text with a free one, the text would still be needed and
subtracting per record would have undercounted; the eligible figure is
therefore counted over distinct texts, not by subtraction.

Both numbers move whenever a hold lifts or a classification changes, and both
are recomputed from the pack and the ledger — there is a test that recounts
them rather than trusting this table.

## Matching key

Use the same content hash the ledger and the admin screen already use:

```
sha256( text.ar + U+0000 + text.en )
```

Naming files by that hash makes the shared pair collapse to one file
automatically, and makes a changed text produce a changed filename — so a
corrected transcription can never keep playing the old recitation.

> **What was actually built.** Production uses
> `audio/duas/<voice>-<sha256 of the audio bytes>.mp3` — written first by
> `review/publish-algieba-audio.mjs`, and now by
> `scripts/generate_dua_audio.mjs`, which was realigned to match rather than
> leave two naming schemes in one folder. The 53 approved records occupy 52
> objects: البقرة 201 is printed twice in the pack under two
> classifications, and hashing the bytes collapses the pair into one file
> exactly as this section intended.
>
> One correction to what this section claims. Hashing does **not**, on its
> own, stop a corrected transcription from playing its old recitation: a new
> name for the new audio does not change the `audioUrl` a record already
> holds. That protection is separate and explicit —
> `lib/shared/audio/audio_staleness.dart` drops the stored file when the text
> it recites is edited. The hash earns its place for deduplication and for
> never overwriting a recording in place; the staleness guard is what keeps a
> pilgrim from hearing words the record no longer contains.
>
> The admin console still uploads hand-made audio to
> `audio/duas/<duaId>.mp3`. That is deliberate: a person choosing a file has
> no audio bytes to hash until after the upload, and their recording is
> theirs to name.

## Rules

- Guidance and evidence get **no** audio file, ever. A file existing for them
  would be a second playback path around `canPlayManually`.
- A record whose text is later corrected needs its audio regenerated; the
  hash change is the signal.
- Audio does not confer verification, and a record with audio is still
  governed by `contentKind`, `recitationPolicy`, and the review ledger.

## Pronunciation notes for recitation

Some records reproduce a typographic feature of the printed page that a
reader resolves silently but a voice engine will not. They are listed here so
whoever records or synthesises the audio does not inherit the artefact.

| record | as printed / stored | must be voiced as |
|---|---|---|
| `moia-mukhtasar-1446-general-048` (p101–102) | `وَقِنِي شَرَّمَا قَضَيْتَ` — no space between `شَرَّ` and `مَا` | `وَقِنِي شَرَّ مَا قَضَيْتَ` — two words |

The missing space is real and measured, not a transcription slip: on that
line of page 102 the word gaps run 87–112 px at 450 dpi, while the gap inside
`شَرَّمَا` is 18 px — a letter gap, not a word gap. The text stays as the
ministry set it; only the recitation separates the two words.

This table is documentation, not schema. Nothing in the pack, the importer,
or the app reads it, and no field was added to carry it.
