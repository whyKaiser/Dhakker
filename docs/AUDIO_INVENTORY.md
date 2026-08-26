# Audio inventory and the canonical-text rule

## Current state, stated precisely

There are **zero audio files in this repository**. Every record has an empty
`audioUrl` and an unset `audioMode`, so every playback today goes through
device TTS.

That is **not** a claim that no audio exists. The project owner has existing
AI-generated audio files **outside the repository**. They cannot be matched
to records yet: matching needs either the filenames, the files themselves, or
a hash of each file's source text. Until one of those is supplied, no
statement can be made about how many of the 59 needed recitations are already
covered.

## How many files are needed

| | count |
|---|---|
| records in the pack | 85 |
| recitable (`specific_text`, `general_dua`, `general_dhikr`, `mosque_entry`) | 60 |
| non-recitable — guidance and evidence, **never** voiced | 25 |
| **unique canonical texts among the recitable 60** | **59** |

59, not 60, because two records hold the same canonical text:
`moia-mukhtasar-1446-tawaf-between-corners` (p69, location-specific, between
the two corners) and `moia-mukhtasar-1446-general-001` (p94, general dua) both
carry البقرة 201. They stay two records — the ministry prints the ayah twice
under different classifications, and collapsing them would erase a real
distinction — but they must **share one audio file**. One text, one
recitation, one set of bytes.

All 60 are `ar` only; **no record has `text.en`**, so no English audio is
implied by the current pack.

## Matching key

Use the same content hash the ledger and the admin screen already use:

```
sha256( text.ar + U+0000 + text.en )
```

Naming files by that hash makes the shared pair collapse to one file
automatically, and makes a changed text produce a changed filename — so a
corrected transcription can never keep playing the old recitation.

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
