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

## Status: 23/23 compared against the official data — resolved

The official archive **UthmanicHafs_v2-0.zip** was supplied directly and is
pinned in this repository at `third_party/kfgqpc/hafsData_v2-0.json`
(6236 āyāt, SHA-256 `d2960b32…`), together with its `read.me`.

| | |
|---|---|
| Edition | **KFGQPC Hafs Uthmanic Data v2.0** |
| Date | **2022-09-07** (Update 13.0) |
| Field used for display | `aya_text` |
| Field used for search/alignment only | `aya_text_emlaey` — never displayed |
| Trailing āyah-number marker | removed on storage; nothing else normalised |

**Result: 23/23 corrected.** Every one of the 23 records differed from the
official text, and every difference was in encoding — none was a difference
of wording. Each stored text is now a **verbatim contiguous span** of the
official `aya_text`: the span was located by aligning consonantal skeletons
(each of the 23 aligned uniquely), then sliced from the official string. No
character was typed, patched, or assembled by hand.

### What was wrong

| Difference | Records affected |
|---|---|
| sukūn `U+0652 ْ` → `U+06E1 ۡ` | 23 |
| madda `آ U+0622` → `ا U+0627` + `ٓ U+0653` | 12 |
| tanwīn `U+064B ً` → `U+0657 ٗ` | 13 |
| shadda/vowel ordering (`َ`+`ّ` → `ّ`+`َ`) | 3 |
| stray space before a waqf mark | 4 |
| missing waqf mark `U+06D6 ۖ` | 1 |

Not one difference was a difference of wording: every one is a code point.

**U12 is resolved, and the original reading was right.** The superscript yā'
in «إِبۡرَٰهِـۧمَ» (البقرة: 125) was transcribed **correctly**. The actual
defects in that record were the sukūn, the tanwīn, and a waqf mark
(`U+06D6 ۖ`) that the printed page carries and the transcription had dropped.

**20 of the 23 are portions of longer āyāt** — the Ministry's book quotes
part of the āyah (e.g. البقرة: 201 begins mid-āyah at «رَبَّنَآ»). Three are
whole āyāt: `general-003`, `general-007`, `general-011`. Each record records
`isPortionOfAyah`, and the manifest keeps the full official āyah alongside
the stored span so a reviewer can see exactly what was cut and verify the
cut was a slice, not an edit.

### Per-record result

| # | السجل | السورة:الآية | ص | النتيجة | نوع الفرق | جزء من آية؟ |
|---|---|---|---|---|---|---|
| 1 | `general-001` | البقرة: 201 | 94 | ✏️ صُحِّح | تنوين، سكون، مدّة | جزء |
| 2 | `general-002` | البقرة: 286 | 94 | ✏️ صُحِّح | ترتيب الشدّة، تنوين، سكون، مدّة، مسافة زائدة | جزء |
| 3 | `general-003` | آل عمران: 8 | 94 | ✏️ صُحِّح | سكون، مسافة زائدة | آية كاملة |
| 4 | `general-004` | آل عمران: 16 | 95 | ✏️ صُحِّح | سكون، مدّة | جزء |
| 5 | `general-005` | آل عمران: 38 | 95 | ✏️ صُحِّح | تنوين، سكون، مدّة، مسافة زائدة | جزء |
| 6 | `general-006` | آل عمران: 147 | 95 | ✏️ صُحِّح | سكون | جزء |
| 7 | `general-007` | آل عمران: 193، 194 | 95 | ✏️ صُحِّح | ترتيب الشدّة، تنوين، سكون، مدّة | آية كاملة |
| 8 | `general-008` | الأعراف: 23 | 95 | ✏️ صُحِّح | سكون، مدّة | جزء |
| 9 | `general-009` | التوبة: 129 | 95 | ✏️ صُحِّح | سكون، مدّة، مسافة زائدة | جزء |
| 10 | `general-010` | إبراهيم: 35 | 95 | ✏️ صُحِّح | تنوين، سكون | جزء |
| 11 | `general-011` | إبراهيم: 40، 41 | 96 | ✏️ صُحِّح | سكون، مدّة | آية كاملة |
| 12 | `general-012` | الكهف: 10 | 96 | ✏️ صُحِّح | تنوين، سكون، مدّة | جزء |
| 13 | `general-013` | طه: 25، 26 | 96 | ✏️ صُحِّح | سكون | جزء |
| 14 | `general-014` | طه: 114 | 96 | ✏️ صُحِّح | تنوين، سكون | جزء |
| 15 | `general-015` | الأنبياء: 87 | 96 | ✏️ صُحِّح | سكون، مدّة | جزء |
| 16 | `general-016` | الأنبياء: 89 | 96 | ✏️ صُحِّح | تنوين، سكون | جزء |
| 17 | `general-017` | المؤمنون: 97، 98 | 96 | ✏️ صُحِّح | سكون | جزء |
| 18 | `general-018` | الفرقان: 65، 66 | 96 | ✏️ صُحِّح | تنوين، سكون، مدّة | جزء |
| 19 | `general-019` | الفرقان: 74 | 96 | ✏️ صُحِّح | سكون | جزء |
| 20 | `general-020` | النمل: 19 | 96 | ✏️ صُحِّح | تنوين، سكون | جزء |
| 21 | `general-021` | الأحقاف: 15 | 97 | ✏️ صُحِّح | ترتيب الشدّة، تنوين، سكون | جزء |
| 22 | `general-022` | الحشر: 10 | 97 | ✏️ صُحِّح | تنوين، سكون، مدّة | جزء |
| 23 | `maqam-ayah` | البقرة: 125 | 71 | ✏️ صُحِّح | تنوين، سكون، علامة وقف ناقصة | جزء |

### Still true

All 23 remain `verificationStatus: unverified`. Establishing the text
authority is not verification — a human still confirms each record against
the printed page before any of it becomes citable.

## What the tests enforce

- All 23 Quranic records are enumerated with surah, āyah number(s), and the
  Ministry page that supplies their context.
- The pinned file is the v2.0 dataset (6236 āyāt) and the manifest names that
  edition and date.
- **Every stored text is a contiguous span of the official `aya_text`**,
  re-derived from the pinned file rather than trusted from the manifest — so
  a hand-assembled string cannot pass.
- The source pack carries exactly that span, compared **without
  normalisation**.
- Each record declares the full provenance split: text authority, riwāyah,
  rasm, edition, and the Ministry context URL with its printed page.
- No record may claim `مجمع الملك فهد` authority unless its āyah was
  actually taken from the official data.
- Every record is still `unverified`.
