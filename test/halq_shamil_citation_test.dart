// umrah-halq-shamil — a citation that pointed at the wrong paragraph.
//
// The record carried «صحيح البخاري 1540». Page 74 was re-rendered from the
// source file's own pixels and the footnote reads 1545, not 1540 — but the
// number was the smaller half of the problem. Footnote (1) is anchored on the
// paragraph BEFORE this one, the Ibn ʿAbbās hadith running over from page 73
// and ending at «قَلَّدَهَا». The footnote anchored inside this record is (2),
// on «شقه الأيسر», and that one is Muslim 1305.
//
// So the reference was wrong twice over: wrong number, and attached to text
// this record does not contain. It was removed rather than renumbered.
// Putting 1545 here would keep the misattribution and merely fix its digits;
// moving it to another record is impossible because the paragraph it belongs
// to has no record in the pack at all — it is a gap, reported as one.
//
// The Quran citation stays: ﴿الفتح: 27﴾ is printed inside this record's own
// sentence between brackets, not in a footnote, so it is this record's.
//
// text.ar did not change. This was a metadata correction, and the reviewed
// text hash is unchanged — which is itself asserted below, because a
// "citation fix" that quietly moved the text would be the thing to catch.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String kHalqShamil = 'moia-mukhtasar-1446-umrah-halq-shamil';

List<Map<String, dynamic>> _entries() => ((jsonDecode(
      File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
    ) as Map<String, dynamic>)['entries'] as List)
        .cast<Map<String, dynamic>>();

Map<String, dynamic> _entry(String id) =>
    _entries().firstWhere((e) => e['duaId'] == id);

Map<String, dynamic> _review(String id) =>
    ((jsonDecode(File('review/human_review_ledger.json').readAsStringSync())
            as Map<String, dynamic>)['reviews'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((r) => r['recordId'] == id);

List<Map<String, dynamic>> _refs(String id) =>
    ((_entry(id)['sourceReferences'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

void main() {
  group('halq-shamil carries only the citations that are its own', () {
    test('Muslim 1305 is the one hadith reference', () {
      final hadith =
          _refs(kHalqShamil).where((r) => r['type'] == 'hadith').toList();
      expect(hadith, hasLength(1));
      expect(hadith.single['collection'], 'صحيح مسلم');
      expect(hadith.single['reference'], '1305');
      expect(hadith.single['citedOnPage'], 74);
    });

    test('no Bukhari reference, under either number', () {
      for (final r in _refs(kHalqShamil)) {
        expect(r['collection'], isNot(contains('البخاري')),
            reason: 'footnote (1) belongs to the previous paragraph');
        expect(r['reference'], isNot(equals('1540')),
            reason: '1540 was the stored number and the page prints 1545');
        expect(r['reference'], isNot(equals('1545')),
            reason: '1545 is the right number for the wrong paragraph — '
                'renumbering would keep the misattribution');
      }
    });

    test('the printed inline Quran citation is kept', () {
      // ﴿مُحَلِّقِينَ رُءُوسَكُمْ وَمُقَصِّرِينَ﴾ [الفتح: 27] sits inside this
      // record's sentence, so unlike footnote (1) it really is this record's.
      final quran =
          _refs(kHalqShamil).where((r) => r['type'] == 'quran').toList();
      expect(quran, hasLength(1));
      expect(quran.single['reference'], 'الفتح: 27');
      expect(_entry(kHalqShamil)['text']['ar'], contains('الفتح: 27'));
    });

    test('exactly two references remain', () {
      expect(_refs(kHalqShamil), hasLength(2));
    });
  });

  group('the correction touched metadata and nothing else', () {
    test('the reviewed text hash still matches the stored text', () {
      // Pinned from before the citation change. If a future "citation fix"
      // also edits the text, this fails rather than passing silently.
      expect(_review(kHalqShamil)['reviewedTextHash'],
          '29f4b7b78e0f998d6e4990706a0b9a558f8657c4b909832adb4383b3220fc9ce');
      expect(_review(kHalqShamil)['transcriptionCorrected'], isFalse,
          reason: 'no transcription was corrected — only a citation removed');
    });

    test('the record stays passed, unverified, and deployable as before', () {
      final r = _review(kHalqShamil);
      expect(r['reviewStatus'], 'passed',
          reason: 'the text itself was never shown to be wrong');
      expect(r['sourceReferencesReviewStatus'], 'reviewed_present');
      expect(_entry(kHalqShamil)['verificationStatus'], 'unverified');
    });

    test('the note records why the reference went rather than changed', () {
      final n = _review(kHalqShamil)['sourceReferencesNote'] as String;
      expect(n, contains('1540'));
      expect(n, contains('1545'));
      expect(n, contains('قَلَّدَهَا'));
      expect(n, contains('1305'));
    });
  });

  group('the removed citation was not quietly parked somewhere else', () {
    test('no record in the pack cites Bukhari 1540 or 1545', () {
      for (final e in _entries()) {
        for (final r in ((e['sourceReferences'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()) {
          final isBukhari =
              (r['collection'] as String?)?.contains('البخاري') ?? false;
          if (!isBukhari) continue;
          expect(['1540', '1545'].contains(r['reference']), isFalse,
              reason: '${e['duaId']} must not adopt the orphaned footnote; '
                  'its paragraph has no record and is a reported gap');
        }
      }
    });
  });
}
