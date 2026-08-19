# Quranic text authority — U5 / U12

## The split this establishes

Twenty-three records in the MOIA source pack quote the Qur'an. Their text was
transcribed by eye from scans, which is precisely the method that cannot
settle a question about a superscript yā' or a waqf mark. So the two roles
are separated:

| Role | Source |
|---|---|
| **Text** — every character and diacritic | مجمع الملك فهد لطباعة المصحف الشريف · حفص عن عاصم · الرسم العثماني · <https://qurancomplex.gov.sa/techquran/dev/> |
| **Context** — which āyah belongs to which rite, and on which page | وزارة الشؤون الإسلامية والدعوة والإرشاد — المختصر في صفة الحج والعمرة والزيارة، الطبعة الأولى 1446هـ/2025م · <https://ebook.moia.gov.sa/lib/book/582> |

## Status: the official text is NOT in this branch

**No comparison has been performed, and no record claims King Fahd Complex
authority.** The official platform is unreachable from the environment this
branch was prepared in — every request to `qurancomplex.gov.sa` is refused by
the network egress policy with `HTTP 403 (CONNECT tunnel failed)`.

The text was **not** substituted from a mirror, from OCR, or from a model's
memory. An āyah reproduced from memory looks correct and cannot be trusted;
writing one here would have created the exact defect this work exists to
remove, while making it invisible. So the branch ships the machinery and
leaves the text slot empty and explicitly marked unfetched.

## Finishing it

From a network that can reach the official platform:

```sh
export QURAN_AUTHORITY_ENDPOINT='<the text endpoint documented at qurancomplex.gov.sa/techquran/dev>'
export QURAN_AUTHORITY_EDITION='<the edition/version label the platform reports>'
node scripts/fetch_quran_authority.mjs
flutter test test/quran_text_authority_test.dart
```

The script refuses any host other than the King Fahd Complex domains, refuses
to run without an edition label, and writes nothing at all if any single āyah
fails — a blocked fetch must never degrade into a guess.

Once the text is present, the comparison in
`test/quran_text_authority_test.dart` becomes binding: each of the 23 records
is compared to the official text **without normalisation**, because
normalising would hide the very code-point differences U5 and U12 are about.

## What the tests enforce today

- All 23 Quranic records are enumerated, each with surah, āyah number(s), and
  the Ministry page that supplies its context.
- The manifest declares authority, riwāyah, rasm, and both source URLs.
- **A record may not claim `مجمع الملك فهد` as its text authority unless that
  āyah was actually fetched.** This is the invariant that stops the gap from
  being closed with an unverified provenance claim.
- Text cannot appear in the manifest without being marked fetched, so a hand
  edit or paste is caught.
- The manifest cannot be marked `fetched` while any āyah is empty or the
  edition label is missing.
- Unfetched āyāt are reported as **PENDING**, never as passing.

## The 23 records

All are `unverified`, none is citable in production, and none was modified by
this branch.

| # | Record | Surah : āyah | Ministry page | U |
|---|---|---|---|---|
| 1 | `moia-mukhtasar-1446-general-001` | البقرة: 201 | 94 | U5 |
| 2 | `moia-mukhtasar-1446-general-002` | البقرة: 286 | 94 | U5 |
| 3 | `moia-mukhtasar-1446-general-003` | آل عمران: 8 | 94 | U5 |
| 4 | `moia-mukhtasar-1446-general-004` | آل عمران: 16 | 95 | U5 |
| 5 | `moia-mukhtasar-1446-general-005` | آل عمران: 38 | 95 | U5 |
| 6 | `moia-mukhtasar-1446-general-006` | آل عمران: 147 | 95 | U5 |
| 7 | `moia-mukhtasar-1446-general-007` | آل عمران: 193، 194 | 95 | U5 |
| 8 | `moia-mukhtasar-1446-general-008` | الأعراف: 23 | 95 | U5 |
| 9 | `moia-mukhtasar-1446-general-009` | التوبة: 129 | 95 | U5 |
| 10 | `moia-mukhtasar-1446-general-010` | إبراهيم: 35 | 95 | U5 |
| 11 | `moia-mukhtasar-1446-general-011` | إبراهيم: 40، 41 | 96 | U5 |
| 12 | `moia-mukhtasar-1446-general-012` | الكهف: 10 | 96 | U5 |
| 13 | `moia-mukhtasar-1446-general-013` | طه: 25، 26 | 96 | U5 |
| 14 | `moia-mukhtasar-1446-general-014` | طه: 114 | 96 | U5 |
| 15 | `moia-mukhtasar-1446-general-015` | الأنبياء: 87 | 96 | U5 |
| 16 | `moia-mukhtasar-1446-general-016` | الأنبياء: 89 | 96 | U5 |
| 17 | `moia-mukhtasar-1446-general-017` | المؤمنون: 97، 98 | 96 | U5 |
| 18 | `moia-mukhtasar-1446-general-018` | الفرقان: 65، 66 | 96 | U5 |
| 19 | `moia-mukhtasar-1446-general-019` | الفرقان: 74 | 96 | U5 |
| 20 | `moia-mukhtasar-1446-general-020` | النمل: 19 | 96 | U5 |
| 21 | `moia-mukhtasar-1446-general-021` | الأحقاف: 15 | 97 | U5 |
| 22 | `moia-mukhtasar-1446-general-022` | الحشر: 10 | 97 | U5 |
| 23 | `moia-1446-maqam-ayah` | البقرة: 125 | 71 | U12 |

Two scoping corrections from the earlier review sheet: the Quranic records
end at printed page **97**, not 102 (pages 98–102 are non-Quranic
supplications), and `general-012` / `general-014` carry no alif-waṣla or
verse glyph but are Quranic and therefore in scope.
