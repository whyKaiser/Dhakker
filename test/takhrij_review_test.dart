// The takhrij round — the last ten printed pages read for FOOTNOTES ONLY.
//
// Pages 59, 65, 66, 67, 69, 71, 94, 95, 96 and 97 were read for one question:
// does the printed page carry a footnote whose marker is anchored on this
// record's own paragraph? Nothing else was reviewed. No text was retranscribed,
// no hash recomputed, no review status touched.
//
// What the pages actually showed:
//
//   * 65, 71, 95, 96 and 97 carry no footnote rule at all, so no footnotes.
//     The bottom bands of 97 were opened individually to be sure they were
//     body text and not footnotes printed without a rule.
//   * On 66, 67, 69 and 94 the marker count equalled the footnote count, so
//     every footnote could be tied to the paragraph its marker sits on. That
//     is what licenses a «reviewed_none» for a record on a page that does
//     have footnotes: the markers land on other paragraphs.
//   * Page 94 has ONE footnote set over two lines, not two footnotes. There is
//     no marker (٢) on the page.
//   * The Quran is cited INSIDE the body between square brackets in this book
//     — «[البقرة: ٢٠١]» — and never in a footnote. So quranRef is not, and was
//     never treated as, evidence that the printed footnotes were reviewed.
//
// Three records changed. Two were empty and the page cites something; one held
// two references the page prints more fully than the pack recorded them.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pinned KFGQPC Hafs corpus — the only authority for Quran text here.
const String kCorpus = 'third_party/kfgqpc/hafsData_v2-0.json';

const String kTalbiyah = 'moia-mukhtasar-1446-umrah-talbiyah';
const String kZiyadah = 'moia-mukhtasar-1446-umrah-talbiyah-ziyadah';
const String kCrowding = 'moia-1446-hajar-crowding';
const String kUmar = 'moia-1446-hajar-umar';
const String kRakatayn = 'moia-1446-maqam-rakatayn';
const String kTasmiya = 'moia-1446-hajar-tasmiya';
const String kTakbirHajar = 'moia-mukhtasar-1446-tawaf-takbir-hajar';

/// The five records whose citation status this round resolved as
/// reviewed_present, with the reviewedTextHash each one carried BEFORE the
/// round. The round touched no text, so these must still hold — and they are
/// re-derived from text.ar + U+0000 + text.en below rather than trusted.
const Map<String, String> kUnchangedHashes = {
  kTalbiyah: '61dd4cbcb9a6f89b05dc7ddf63c6e1f203541cfca7747651cd1208667c75375e',
  kZiyadah: '2b148236c1bb7c0c81bd8914335e645b3e2f12022939910995738351ee89ea3d',
  kCrowding: '677007c1095e32103fb84ad5c0f113db685abc6f7e511d3e3c0f41402071a3c3',
  kUmar: '2729258088d33f8d5790541546725b0c848064f2b604875fff456baa369f7638',
  kRakatayn: 'ffb53bdc5c1355941e9709fdc7d003ca5d7915f6c914f81aa13ae2f5f87de5e4',
};

Map<String, dynamic> _pack() => jsonDecode(
      File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
    ) as Map<String, dynamic>;

List<Map<String, dynamic>> _entries() =>
    (_pack()['entries'] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> _entry(String id) =>
    _entries().firstWhere((e) => e['duaId'] == id);

List<Map<String, dynamic>> _refs(String id) =>
    ((_entry(id)['sourceReferences'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

Map<String, dynamic> _ledger() => jsonDecode(
      File('review/human_review_ledger.json').readAsStringSync(),
    ) as Map<String, dynamic>;

Map<String, Map<String, dynamic>> _reviews() => {
      for (final r
          in (_ledger()['reviews'] as List).cast<Map<String, dynamic>>())
        r['recordId'] as String: r
    };

Map<String, dynamic> _summaryCitations() =>
    ((_ledger()['summary'] as Map<String, dynamic>)['sourceReferencesReviewed'])
        as Map<String, dynamic>;

void main() {
  group('the round resolved every citation status', () {
    test('all 85 reviews carry a decided status, and none is left open', () {
      final reviews = _reviews();
      expect(reviews, hasLength(85));
      for (final r in reviews.values) {
        final v = r['sourceReferencesReviewStatus'];
        expect(v, isNotNull, reason: '${r['recordId']} still has no status');
        expect(const ['reviewed_none', 'reviewed_present'], contains(v),
            reason: '${r['recordId']} carries "$v"; "correction_required" and '
                '"unresolved" describe the proposal stage, not a final state');
      }
    });

    test('not_reviewed_count is zero and the lists total 85', () {
      final sr = _summaryCitations();
      expect(sr['not_reviewed_count'], 0);
      final present = (sr['reviewed_present'] as List).length;
      final none = (sr['reviewed_none'] as List).length;
      expect(present + none + (sr['not_reviewed_count'] as int), 85);
      // Not a hand-typed pair: the split as the pages actually read.
      expect(present, 11);
      expect(none, 74);
    });

    test('reviewed_none never coexists with a non-empty sourceReferences', () {
      // The whole point of the status: an empty list is not a finding, and a
      // finding may not contradict the record it describes.
      for (final e in _entries()) {
        final id = e['duaId'] as String;
        final status = _reviews()[id]?['sourceReferencesReviewStatus'];
        final refs = (e['sourceReferences'] as List?) ?? const [];
        if (status == 'reviewed_none') {
          expect(refs, isEmpty,
              reason: '$id says the page cites nothing yet holds references');
        }
        if (status == 'reviewed_present') {
          expect(refs, isNotEmpty,
              reason: '$id says the page cites something yet holds none');
        }
      }
    });

    test('every review carries a note naming the page it was read on', () {
      for (final id in [
        kTalbiyah,
        kZiyadah,
        kUmar,
        kCrowding,
        kRakatayn,
        kTasmiya,
        kTakbirHajar,
      ]) {
        final note = (_reviews()[id]!['sourceReferencesNote'] ?? '') as String;
        expect(note.trim(), isNotEmpty, reason: id);
        expect(RegExp(r'صفح').hasMatch(note), isTrue,
            reason: '$id: the evidence must name the page that was read');
      }
    });
  });

  group('the three corrected records hold exactly what page 59/67/68 print',
      () {
    test('umrah-talbiyah gains Muslim 1218 and nothing else', () {
      expect(_refs(kTalbiyah), [
        {
          'type': 'hadith',
          'collection': 'صحيح مسلم',
          'reference': '1218',
          'referenceKind': 'hadith_number',
          'citedBy': 'moia_1446',
          'citedOnPage': 59,
        }
      ]);
    });

    test('umrah-talbiyah-ziyadah gains Muslim 1184 and nothing else', () {
      expect(_refs(kZiyadah), [
        {
          'type': 'hadith',
          'collection': 'صحيح مسلم',
          'reference': '1184',
          'referenceKind': 'hadith_number',
          'citedBy': 'moia_1446',
          'citedOnPage': 59,
        }
      ]);
    });

    test('the two Muslim numbers are not swapped between the records', () {
      // 1218 is Jabir's hajj; 1184 is the athar for the addition. Reversing
      // them would still pass a shape check, so pin the pairing.
      expect(_refs(kTalbiyah).single['reference'], '1218');
      expect(_refs(kZiyadah).single['reference'], '1184');
    });

    test('hajar-crowding keeps its first two references untouched', () {
      final refs = _refs(kCrowding);
      expect(refs, hasLength(4));
      expect(refs[0], {
        'type': 'athar',
        'collection': 'مصنف عبد الرزاق',
        'reference': '5/36',
        'referenceKind': 'volume_page',
        'citedBy': 'moia_1446',
        'citedOnPage': 67,
      });
      expect(refs[1], {
        'type': 'athar',
        'collection': 'مصنف ابن أبي شيبة',
        'reference': '3/171',
        'referenceKind': 'volume_page',
        'citedBy': 'moia_1446',
        'citedOnPage': 67,
      });
    });

    test('the continued footnote keeps citedOnPage 68 for its own half', () {
      // Footnote (٤) opens at the foot of 67, ends in the continuation mark
      // «=», and finishes at the head of 68 where al-Shafi'i and Ahmad are
      // named with their numbers. Recording those two as page 67 would put
      // them on a page that does not print them.
      final refs = _refs(kCrowding);
      expect(refs[2], {
        'type': 'athar',
        'collection': 'السنن المأثورة للشافعي',
        'reference': '510',
        'referenceKind': 'hadith_number',
        'citedBy': 'moia_1446',
        'citedOnPage': 68,
      });
      expect(refs[3], {
        'type': 'athar',
        'collection': 'مسند أحمد',
        'reference': '190',
        'referenceKind': 'hadith_number',
        'citedBy': 'moia_1446',
        'citedOnPage': 68,
      });
      // One footnote, two pages: both halves stay on the same record.
      expect(refs.map((r) => r['citedOnPage']).toSet(), {67, 68});
      expect(refs.every((r) => r['type'] == 'athar'), isTrue);
      expect(refs.every((r) => r['citedBy'] == 'moia_1446'), isTrue);
      // The vague forms this round replaced must not come back.
      expect(refs.any((r) => r['referenceKind'] == 'unspecified'), isFalse);
      expect(refs.any((r) => r['collection'] == 'الشافعي'), isFalse);
      expect(refs.any((r) => r['collection'] == 'أحمد'), isFalse);
    });

    test('hajar-umar was already right and was not touched', () {
      expect(
          _refs(kUmar).map((r) => r['reference']).toList(), ['1597', '1270']);
      expect(_refs(kUmar).every((r) => r['citedOnPage'] == 66), isTrue);
    });
  });

  group('maqam-rakatayn: where the two surahs actually live', () {
    test('the two surahs the pack names are the ones the corpus holds', () {
      // This file reasons about quranRef, so it reads the pinned corpus
      // rather than judging Quranic text by eye. The record cites the
      // OPENINGS of al-Kafirun and al-Ikhlas; the body quotes each first
      // ayah inside ornate brackets. Those two quotations are checked
      // against the corpus, so «109:1» and «112:1» are not bare labels.
      final corpus = (jsonDecode(File(kCorpus).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      expect(corpus, hasLength(6236));
      String ayah(int s, int a) => corpus.firstWhere((r) =>
          int.parse('${r['sura_no']}') == s &&
          int.parse('${r['aya_no']}') == a)['aya_text'] as String;
      String skeleton(String t) {
        final b = StringBuffer();
        for (final r in t.runes) {
          if ((r >= 0x064B && r <= 0x0652) ||
              r == 0x0670 ||
              (r >= 0x06D6 && r <= 0x06ED) ||
              // The corpus terminates each ayah with a presentation-form
              // number glyph (U+FC00 and neighbours). It is a mark, not a
              // letter, and the ministry's inline quotation omits it.
              r >= 0xFB50) {
            continue;
          }
          var c = r;
          if (c == 0x0671 || c == 0x0622 || c == 0x0623 || c == 0x0625) {
            c = 0x0627;
          }
          b.writeCharCode(c);
        }
        return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      }

      final body = skeleton(_entry(kRakatayn)['text']['ar'] as String);
      expect(body.contains(skeleton(ayah(109, 1))), isTrue,
          reason: 'the body does not quote al-Kafirun 1 as the pack claims');
      expect(body.contains(skeleton(ayah(112, 1))), isTrue,
          reason: 'the body does not quote al-Ikhlas 1 as the pack claims');
      // And the check has teeth: an unrelated ayah is not in there.
      expect(body.contains(skeleton(ayah(2, 201))), isFalse);
    });

    test('they are in sourceReferences, not in quranRef', () {
      final e = _entry(kRakatayn);
      // The record has no quranRef at all; the two citations are structured
      // references. That is what makes reviewed_present the honest status,
      // even though page 71 has no footnote rule: the ministry prints these
      // two inside the body sentence, and the pack stores them as references.
      expect(e['quranRef'], isNull);
      expect(e.containsKey('quranRefs'), isFalse);
      final refs = _refs(kRakatayn);
      expect(refs, hasLength(2));
      expect(refs.map((r) => r['reference']).toList(), ['109:1', '112:1']);
      expect(refs.every((r) => r['type'] == 'quran'), isTrue);
      expect(refs.every((r) => r['citedOnPage'] == 71), isTrue);
    });

    test('and its status is reviewed_present, not reviewed_none', () {
      expect(_reviews()[kRakatayn]!['sourceReferencesReviewStatus'],
          'reviewed_present');
    });

    test('the note says the citations are in the body, not a footnote', () {
      final note = _reviews()[kRakatayn]!['sourceReferencesNote'] as String;
      expect(note.contains('المتن'), isTrue);
    });
  });

  group('records the pages showed no footnote for', () {
    test('hajar-tasmiya across 65-67, and tawaf-takbir-hajar on 69', () {
      for (final id in [kTasmiya, kTakbirHajar]) {
        expect(_reviews()[id]!['sourceReferencesReviewStatus'], 'reviewed_none',
            reason: id);
        expect(_refs(id), isEmpty, reason: id);
      }
    });

    test('the tasmiya note names all three pages that were read for it', () {
      final note = _reviews()[kTasmiya]!['sourceReferencesNote'] as String;
      for (final p in ['65', '66', '67']) {
        expect(note.contains(p), isTrue,
            reason: 'page $p is not accounted for');
      }
    });

    test('the neighbours whose footnotes those pages DO carry are separate',
        () {
      // 66 and 67 have footnotes; they belong to hajar-umar and
      // hajar-crowding, and to paragraphs with no record at all. None of that
      // leaks onto hajar-tasmiya.
      expect(_reviews()[kUmar]!['sourceReferencesReviewStatus'],
          'reviewed_present');
      expect(_reviews()[kCrowding]!['sourceReferencesReviewStatus'],
          'reviewed_present');
      expect(_refs(kTasmiya), isEmpty);
    });
  });

  group('this round changed nothing but citations', () {
    test('text and reviewedTextHash are untouched, and still agree', () {
      for (final entry in kUnchangedHashes.entries) {
        final e = _entry(entry.key);
        final ar = e['text']['ar'] as String;
        final en = (e['text']['en'] ?? '') as String;
        final digest = sha256.convert(utf8.encode('$ar\u0000$en')).toString();
        expect(digest, entry.value,
            reason: '${entry.key}: the text moved under its reviewed hash');
        expect(_reviews()[entry.key]!['reviewedTextHash'], entry.value,
            reason: '${entry.key}: the ledger hash was rewritten');
      }
    });

    test('reviewStatus and verificationStatus did not move', () {
      final reviews = _reviews();
      for (final id in kUnchangedHashes.keys) {
        expect(reviews[id]!['reviewStatus'], 'passed', reason: id);
        expect(_entry(id)['verificationStatus'], 'unverified', reason: id);
      }
      // And the ledger counters are unchanged by a citation-only round.
      final s = _ledger()['summary'] as Map<String, dynamic>;
      expect(s['totalReviews'], 85);
      expect(s['passed'], 84);
      expect(s['blocked'], 1);
      expect(s['pending'], 0);
      expect(s['failed'], 0);
      expect(s['verifiedRecords'], 0);
    });

    test('every record in the pack is still unverified', () {
      for (final e in _entries()) {
        expect(e['verificationStatus'], 'unverified', reason: '${e['duaId']}');
        expect(e['verifiedAt'], isNull, reason: '${e['duaId']}');
        expect(e['verifiedBy'], isNull, reason: '${e['duaId']}');
      }
    });

    test('the import and hold lists are the same size as before', () {
      final s = _ledger()['summary'] as Map<String, dynamic>;
      expect((s['excludedFromImportRecordIds'] as List), hasLength(12));
      expect((s['deploymentBlockedRecordIds'] as List), hasLength(11));
      expect(
          (s['blockedRecordIds'] as List), ['moia-mukhtasar-1446-general-009']);
    });

    test('a citation status never changes what may be recited', () {
      // talbiyah-ziyadah is now reviewed_present and stays deployment-held;
      // the two are unrelated axes.
      final s = _ledger()['summary'] as Map<String, dynamic>;
      expect((s['deploymentBlockedRecordIds'] as List), contains(kZiyadah));
      expect(_reviews()[kZiyadah]!['sourceReferencesReviewStatus'],
          'reviewed_present');
    });
  });
}
