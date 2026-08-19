# KFGQPC Hafs Uthmanic Data — third-party data, not this project's work

This directory holds an **unmodified copy** of data published by
**مجمع الملك فهد لطباعة المصحف الشريف** (King Fahd Glorious Qur'an Printing
Complex). It is **not authored by, owned by, or attributable to the Dhakker
project**, and no claim of authorship over it is made or implied.

| | |
|---|---|
| Publisher | مجمع الملك فهد لطباعة المصحف الشريف |
| Product | KFGQPC Hafs Uthmanic Data |
| Version | **2.0** |
| Date | **2022-09-07** (Update 13.0) |
| Riwāyah | حفص عن عاصم |
| Rasm | الرسم العثماني |
| Developer platform | <https://qurancomplex.gov.sa/techquran/dev/> |
| Archive as supplied | `UthmanicHafs_v2-0.zip` |

## Files

| File | SHA-256 | Note |
|---|---|---|
| `hafsData_v2-0.json` | `d2960b3217962e7e4252abdcece67bea3d6b48271e4cd3af45bbbb2dd5c872ca` | 6236 āyāt, byte-identical to the archive |
| `README.kfgqpc.txt` | — | the publisher's own `read.me`, kept verbatim |

`README.kfgqpc.txt` is the file the Complex ships inside the archive; it
records the version, the date, and the per-release change list. It is kept
unedited so the edition can always be identified from the repository alone.

## Terms of use

The archive as supplied contains **no separate licence file** — its only
accompanying document is the `read.me` preserved here. Terms of use are
those published by the King Fahd Complex on its developer platform; consult
that platform before redistributing this data. Nothing in this repository
grants any right over the data, and this note does not restate or summarise
terms that were not supplied with it.

## What this data is used for here

Reference for tests only. `test/quran_text_authority_test.dart` compares the
23 Quranic records in the MOIA source pack against this file, and
`scripts/rebuild_quran_authority.mjs` rebuilds those records from it.

**It is not shipped in the application.** `third_party/` is not declared as
a Flutter asset in `pubspec.yaml` and is not imported by any file under
`lib/`, so it is not bundled into an APK/IPA and adds nothing to the app's
download size. `test/no_bundled_third_party_test.dart` fails if that ever
changes.
