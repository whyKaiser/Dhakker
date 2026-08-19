# Source packs — review sheets

Staging area for content prepared from an official publication, **before** it
enters Firestore. Nothing here is live, and nothing here is verified.

## MOIA — المختصر في صفة الحج والعمرة والزيارة (1446هـ / 2025م)

| | |
|---|---|
| **File** | `moia_mukhtasar_1446_umrah.json` |
| **Title** | المختصر في صفة الحج والعمرة والزيارة في ضوء الكتاب والسنة |
| **Authority** | وزارة الشؤون الإسلامية والدعوة والإرشاد - المكتب العلمي لمعالي الوزير |
| **Edition** | الطبعة الأولى، 1446هـ / 2025م |
| **Source URL** | https://ebook.moia.gov.sa/lib/book/582 |
| **Scope** | Umrah section only |
| **Status** | ⚠️ **Scaffold — no text transcribed** |

### Why the text fields are empty

The publication was **not available** when this pack was prepared:

- No PDF or page images were attached to the session.
- `ebook.moia.gov.sa` was unreachable from the preparing environment
  (proxy returned HTTP 403 on CONNECT).
- The source is image-based, so OCR would require page-by-page visual
  confirmation regardless.

Every passage was therefore left unfilled. Writing these texts from memory or
from any non-official copy would put unverified religious content under this
Ministry's name, edition and page numbers — content that would then *look*
checked. That is precisely the failure mode the app's provenance gate exists
to prevent, so it was not done.

### Review table

Text column is empty by design. Fill it only by transcribing the printed page.

| # | Topic | Printed page | `sourceSection` | Text status |
|---|---|---|---|---|
| 1 | Talbiyah | 59 | قسم العمرة — التلبية — صفحة 59 | ⬜ Not transcribed |
| 2 | Entering Al-Masjid Al-Haram | 64 | قسم العمرة — دخول المسجد الحرام — صفحة 64 | ⬜ Not transcribed |
| 3 | What is touched during Tawaf | 69 | قسم العمرة — ما يُستلم في الطواف — صفحة 69 | ⬜ Not transcribed |
| 4 | Between Yemeni Corner & Black Stone | 69 | قسم العمرة — الدعاء بين الركن اليماني والحجر الأسود — صفحة 69 | ⬜ Not transcribed · ⚠️ Quranic text |
| 5 | Shaving and shortening | 74 | قسم العمرة — الحلق والتقصير — صفحة 74 | ⬜ Not transcribed |
| 6 | General selected supplications | 94 onward | أدعية عامة مختارة — صفحة 94 وما بعدها | ⬜ Not transcribed · one record per supplication |

Shared by every record above:

- **Authority** — وزارة الشؤون الإسلامية والدعوة والإرشاد - المكتب العلمي لمعالي الوزير
- **Source URL** — https://ebook.moia.gov.sa/lib/book/582
- **Edition** — الطبعة الأولى، 1446هـ / 2025م
- **`verificationStatus`** — `unverified` (all six)

### Tags assigned

| # | `tagsAr` | `tagsEn` |
|---|---|---|
| 1 | تلبية · لبيك · إحرام · عمرة | talbiyah · ihram · umrah |
| 2 | دخول · المسجد الحرام · الحرم · عمرة | entering · masjid · haram · umrah |
| 3 | طواف · استلام · الحجر الأسود · الركن اليماني | tawaf · touching · black-stone · yemeni-corner |
| 4 | دعاء · الركن اليماني · الحجر الأسود · طواف | supplication · yemeni-corner · black-stone · tawaf |
| 5 | حلق · تقصير · تحلل · عمرة | shaving · shortening · halq · taqsir · umrah |
| 6 | أدعية · أدعية عامة · مختارة | supplications · general · selected |

### Structural rules applied

- **No per-circuit Tawaf duas.** Entries 3 and 4 are each a single record for
  the whole Tawaf, not bound to any circuit number.
- **Entry 6 is general.** Its `zoneId` is deliberately **empty** so it can
  never fire as a location-triggered dua, and it carries
  `isGeneralSupplication: true`.
- Entry 6 must be **split into one record per supplication** (`…-001`,
  `…-002`, …), each with its own exact printed page — 94 is only the start of
  the range.

### Uncertain passages

None flagged, because **nothing was read**. Flagging requires having seen the
page. Once transcription happens, flag in `reviewNotes` any passage where the
printed glyphs are ambiguous — especially diacritics, and any Quranic text
(entry 4 in particular).

### To complete this pack

1. Provide the PDF or page images for pages 59, 64, 69, 74 and 94+.
2. Transcribe each passage exactly, preserving Quranic rasm and all
   diacritics; replace the `<<< UNFILLED … >>>` placeholders.
3. Set `zoneId` on entries 1–5 from the live `zones` collection. Leave entry
   6's empty.
4. Split entry 6 per supplication with exact per-item pages.
5. Leave `verificationStatus: "unverified"`. **Do not** hand-edit it.
6. Import, then verify each record in the admin console after matching it
   against the printed page. The console stamps `verifiedAt`, `verifiedBy`
   and `contentHash`; `firestore.rules` rejects a `verified` record with
   incomplete provenance.

Until step 6 is done per record, the assistant will not cite any of this —
by design.
