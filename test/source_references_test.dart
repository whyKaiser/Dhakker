// `sourceReferences` — what the MINISTRY cited, as data.
//
// The whole point is the difference between reporting and vouching. We are
// not asserting that a hadith is authentic; we are recording that the
// reviewed printed page cites a collection and a number. Two rules carry
// that distinction, and the tests below exist to keep them:
//
//   `citedBy` names who made the citation.
//   A source printed WITHOUT a number gets referenceKind "unspecified" and
//   no `reference` key — never "", which reads as "we checked and found
//   none", and never a number recalled from elsewhere.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Duas/widgets/content_kind_card.dart';
import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';
import 'package:dhakker/services/assistant_service.dart';

Map<String, dynamic> _entry(String id) {
  final pack = jsonDecode(
    File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return (pack['entries'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((e) => e['duaId'] == id);
}

void main() {
  group('the pack records only what the pages print', () {
    test('hajar-umar carries Bukhari and Muslim, cited by MOIA on page 66', () {
      final refs = (_entry('moia-1446-hajar-umar')['sourceReferences'] as List)
          .cast<Map<String, dynamic>>();
      expect(refs, hasLength(2));
      for (final r in refs) {
        expect(r['type'], 'hadith');
        expect(r['referenceKind'], 'hadith_number');
        expect(r['citedBy'], 'moia_1446');
        expect(r['citedOnPage'], 66);
      }
      expect(refs.map((r) => r['collection']),
          containsAll(['صحيح البخاري', 'صحيح مسلم']));
      expect(refs.map((r) => r['reference']), containsAll(['1597', '1270']));
    });

    test(
        'hajar-crowding records four sources across a footnote that spans '
        'two pages', () {
      // This test used to assert two numbered and two UNNUMBERED sources,
      // recorded as referenceKind "unspecified" with the bare names
      // «الشافعي» and «أحمد». That was right about what page 67 shows and
      // wrong about what the ministry printed: footnote (٤) ends at the foot
      // of 67 in the continuation mark «=» and finishes at the head of 68,
      // where both works are named in full with their numbers. Reading 68
      // turned the two unspecified entries into numbered ones. The rule the
      // old test protected is untouched — a number nobody printed is still
      // never invented — it just turns out the page did print them.
      final refs =
          (_entry('moia-1446-hajar-crowding')['sourceReferences'] as List)
              .cast<Map<String, dynamic>>();
      expect(refs, hasLength(4));
      for (final r in refs) {
        expect(r['type'], 'athar');
        expect(r['citedBy'], 'moia_1446');
        expect(r.containsKey('reference'), isTrue,
            reason: 'all four are numbered once page 68 is read');
        expect(r['referenceKind'], isNot('unspecified'));
      }

      // The half printed on 67: volume/page, not a hadith number.
      final onSixtySeven = refs.where((r) => r['citedOnPage'] == 67).toList();
      expect(onSixtySeven, hasLength(2));
      expect(onSixtySeven.map((r) => r['reference']),
          containsAll(['5/36', '3/171']));
      expect(onSixtySeven.map((r) => r['collection']),
          containsAll(['مصنف عبد الرزاق', 'مصنف ابن أبي شيبة']));
      for (final r in onSixtySeven) {
        expect(r['referenceKind'], 'volume_page');
      }

      // The half printed on 68, as the continuation of the SAME footnote.
      final onSixtyEight = refs.where((r) => r['citedOnPage'] == 68).toList();
      expect(onSixtyEight, hasLength(2));
      expect(
          onSixtyEight.map((r) => r['reference']), containsAll(['510', '190']));
      expect(onSixtyEight.map((r) => r['collection']),
          containsAll(['السنن المأثورة للشافعي', 'مسند أحمد']));
      for (final r in onSixtyEight) {
        expect(r['referenceKind'], 'hadith_number');
      }
    });

    test('no reference anywhere in the pack is an empty string', () {
      final pack = jsonDecode(
        File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final e in (pack['entries'] as List).cast<Map<String, dynamic>>()) {
        for (final r in (e['sourceReferences'] as List? ?? [])
            .cast<Map<String, dynamic>>()) {
          if (r.containsKey('reference')) {
            expect((r['reference'] as String).trim(), isNotEmpty,
                reason: '${e['duaId']} has an empty reference');
            expect(r['referenceKind'], isNot('unspecified'));
          } else {
            expect(r['referenceKind'], 'unspecified');
          }
          // Every citation says who made it. Ours is never the answer.
          expect(r['citedBy'], 'moia_1446');
          expect(r['citedOnPage'], isA<int>());
        }
      }
    });

    test('the citedOnPage of a reference lies on a page that was read', () {
      // A citation attributed to a page the reviewer never read would be
      // provenance in name only. Normally the pages of the record's own text
      // are that set. A footnote may run past them, though: hajar-crowding's
      // footnote (٤) opens at the foot of 67 and finishes at the head of 68,
      // and the two works named on 68 belong to that footnote. Where the
      // ledger records `sourceReferencesPages`, those are the pages actually
      // read for the citations, and they govern instead — sourceSection keeps
      // pointing at where the TEXT is, which is also what the pilgrim sees on
      // the card.
      final pack = jsonDecode(
        File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final reviews = {
        for (final r in ((jsonDecode(
          File('review/human_review_ledger.json').readAsStringSync(),
        ) as Map<String, dynamic>)['reviews'] as List)
            .cast<Map<String, dynamic>>())
          r['recordId'] as String: r
      };
      for (final e in (pack['entries'] as List).cast<Map<String, dynamic>>()) {
        final refs = (e['sourceReferences'] as List? ?? []);
        if (refs.isEmpty) continue;
        final id = e['duaId'] as String;
        final section = e['sourceSection'] as String;
        final nums = RegExp(r'\d+')
            .allMatches(section.substring(section.lastIndexOf('صفح')))
            .map((m) => int.parse(m.group(0)!))
            .toList();
        var lo = nums.first;
        var hi = nums.length > 1 ? nums.last : nums.first;
        final read = reviews[id]?['sourceReferencesPages'];
        if (read != null) {
          final pages = (read as List).cast<int>();
          expect(pages, isNotEmpty, reason: id);
          // It may only EXTEND the text's pages, never replace or shrink
          // them, so it cannot be used to smuggle in an unrelated page.
          expect(pages.first <= lo && pages.last >= hi, isTrue,
              reason: '$id: sourceReferencesPages $pages does not cover the '
                  'text pages $lo-$hi');
          lo = pages.first;
          hi = pages.last;
        }
        for (final r in refs.cast<Map<String, dynamic>>()) {
          final page = r['citedOnPage'] as int;
          expect(page >= lo && page <= hi, isTrue,
              reason: '$id cites page $page but was read on $lo-$hi');
        }
      }
    });

    test('sourceReferencesPages is only spelled out where a footnote runs on',
        () {
      // One record needs it. If a second ever appears it should be a
      // deliberate reading of a continued footnote, not a way around the
      // page check above.
      final reviews = ((jsonDecode(
        File('review/human_review_ledger.json').readAsStringSync(),
      ) as Map<String, dynamic>)['reviews'] as List)
          .cast<Map<String, dynamic>>();
      final withIt =
          reviews.where((r) => r['sourceReferencesPages'] != null).toList();
      expect(withIt.map((r) => r['recordId']), ['moia-1446-hajar-crowding']);
      for (final r in withIt) {
        final pages = (r['sourceReferencesPages'] as List).cast<int>();
        expect(pages.length, greaterThan(1));
        for (var i = 1; i < pages.length; i++) {
          expect(pages[i], pages[i - 1] + 1,
              reason: 'a continued footnote runs onto the NEXT page');
        }
        expect(pages.first, r['reviewedPage']);
        expect(r['sourceReferencesReviewStatus'], 'reviewed_present');
      }
    });

    test('records with nothing cited carry an explicit empty array', () {
      final pack = jsonDecode(
        File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final e in (pack['entries'] as List).cast<Map<String, dynamic>>()) {
        expect(e.containsKey('sourceReferences'), isTrue,
            reason: '${e['duaId']} omits sourceReferences entirely — absent '
                'and empty must not be told apart by accident');
      }
    });
  });

  group('the model reads and re-writes references faithfully', () {
    test('a reference without a number stays without one', () {
      final refs = SourceReference.listFrom([
        {
          'type': 'athar',
          'collection': 'الشافعي',
          'referenceKind': 'unspecified',
          'citedBy': 'moia_1446',
          'citedOnPage': 67,
        },
      ]);
      expect(refs.single.reference, isNull);
      expect(refs.single.display, 'الشافعي');
      expect(refs.single.toJson().containsKey('reference'), isFalse);
    });

    test('an empty reference string is normalised to absent, not kept', () {
      final refs = SourceReference.listFrom([
        {
          'type': 'athar',
          'collection': 'أحمد',
          'reference': '   ',
          'referenceKind': 'unspecified',
          'citedBy': 'moia_1446',
          'citedOnPage': 67,
        },
      ]);
      expect(refs.single.reference, isNull);
      expect(refs.single.toJson().containsKey('reference'), isFalse);
    });

    test('a malformed entry is dropped, not half-read', () {
      final refs = SourceReference.listFrom([
        {'type': 'hadith'}, // no collection
        'not a map',
        {
          'type': 'hadith',
          'collection': 'صحيح البخاري',
          'reference': '1597',
          'referenceKind': 'hadith_number',
          'citedBy': 'moia_1446',
          'citedOnPage': 66,
        },
      ]);
      expect(refs, hasLength(1));
      expect(refs.single.display, 'صحيح البخاري (1597)');
    });

    test('references survive the offline cache round trip', () {
      final model = SupplicationModel.fromJson(_entry('moia-1446-hajar-umar'));
      expect(model.sourceReferences, hasLength(2));

      final again = SupplicationModel.fromJson(
          jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>);
      expect(again.sourceReferences.map((r) => r.display),
          model.sourceReferences.map((r) => r.display));
      expect(again.sourceReferences.every((r) => r.citedBy == 'moia_1446'),
          isTrue);
    });

    test('a missing field yields an empty list, never a null crash', () {
      expect(SourceReference.listFrom(null), isEmpty);
      expect(SourceReference.listFrom('nope'), isEmpty);
      final m = SupplicationModel.fromJson({
        'duaId': 'x',
        'title': {'ar': 'ع'},
        'text': {'ar': 'ن'},
      });
      expect(m.sourceReferences, isEmpty);
    });
  });

  group('references change nothing about how a text behaves', () {
    SupplicationModel withRefs(SupplicationContentKind kind) =>
        SupplicationModel(
          duaId: 'x',
          zoneId: '',
          title: const {'ar': 'ع'},
          text: const {'ar': 'ن'},
          audioMode: 'tts',
          audioUrl: '',
          languageCodes: const ['ar'],
          isActive: true,
          updatedAt: null,
          usageCount: 0,
          contentKind: kind,
          zoneKey: 'hajar_aswad',
          sourceReferences: const [
            SourceReference(
              type: 'hadith',
              collection: 'صحيح البخاري',
              referenceKind: 'hadith_number',
              citedBy: 'moia_1446',
              citedOnPage: 66,
              reference: '1597',
            ),
          ],
        );

    test('carrying a hadith number does not make a narration recitable', () {
      final m = withRefs(SupplicationContentKind.contextualEvidence);
      expect(m.sourceReferences, isNotEmpty);
      expect(m.isAutoPlayable, isFalse);
      expect(m.contentKind.isRecitable, isFalse);
    });

    test('nor does it make guidance playable', () {
      expect(
          withRefs(SupplicationContentKind.proceduralGuidance).isAutoPlayable,
          isFalse);
    });

    test('nor does it verify anything', () {
      final e = _entry('moia-1446-hajar-umar');
      expect((e['sourceReferences'] as List), isNotEmpty);
      expect(e['verificationStatus'], 'unverified');
      expect(e['verifiedAt'], isNull);
    });

    test('a recitable text keeps its behaviour with references attached', () {
      // The field must not quietly narrow anything either.
      expect(withRefs(SupplicationContentKind.specificText).isAutoPlayable,
          isTrue);
    });
  });

  group('the cards show references; nothing shows reviewNotes', () {
    const refs = [
      SourceReference(
        type: 'hadith',
        collection: 'صحيح البخاري',
        referenceKind: 'hadith_number',
        citedBy: 'moia_1446',
        citedOnPage: 66,
        reference: '1597',
      ),
      SourceReference(
        type: 'athar',
        collection: 'الشافعي',
        referenceKind: 'unspecified',
        citedBy: 'moia_1446',
        citedOnPage: 67,
      ),
    ];

    testWidgets('the evidence card lists them under a clear heading',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ContextualEvidenceCard(
            title: 'أثر عمر',
            body: 'نص',
            attribution: 'صفحة 66',
            references: refs,
          ),
        ),
      ));
      // "The source attributed it to" — reporting, not endorsing.
      expect(find.text('عزاه المصدر إلى:'), findsOneWidget);
      expect(find.text('• صحيح البخاري (1597)'), findsOneWidget);
      // The unnumbered one appears with no empty parentheses.
      expect(find.text('• الشافعي'), findsOneWidget);
      expect(find.textContaining('()'), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('the guidance card lists them too', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: GuidanceCard(
            title: 'النهي عن المزاحمة',
            body: 'نص',
            attribution: 'صفحة 67',
            references: refs,
            isPropheticDirective: true,
          ),
        ),
      ));
      expect(find.text('عزاه المصدر إلى:'), findsOneWidget);
      expect(find.text('• صحيح البخاري (1597)'), findsOneWidget);
    });

    testWidgets('a card with no references shows no empty heading',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ContextualEvidenceCard(
            title: 'ع',
            body: 'ن',
            attribution: 'صفحة 1',
          ),
        ),
      ));
      expect(find.text('عزاه المصدر إلى:'), findsNothing);
    });

    test('reviewNotes never reaches the pilgrim-facing model', () {
      // The citations exist as structured data precisely so the admin note
      // never has to be shown. If reviewNotes ever became readable here,
      // internal review commentary would ship to pilgrims.
      final model = SupplicationModel.fromJson(_entry('moia-1446-hajar-umar'));
      expect(model.toJson().containsKey('reviewNotes'), isFalse);
      // Looks for USE, not for the word: a comment stating the rule is not
      // a violation of it.
      final use = RegExp(r"\['reviewNotes'\]|\.reviewNotes|reviewNotes:");
      for (final path in [
        'lib/Screens/Piligram/Home/models/supplication_model.dart',
        'lib/Screens/Piligram/Duas/widgets/content_kind_card.dart',
        'lib/Screens/Piligram/Home/home_screen.dart',
        'lib/Screens/Piligram/Duas/duas_screen.dart',
      ]) {
        expect(use.hasMatch(File(path).readAsStringSync()), isFalse,
            reason: '$path reads or renders reviewNotes');
      }
    });
  });

  group('the assistant carries references without acting on them', () {
    test('VerifiedExcerpt parses them and drops malformed entries', () {
      final list = VerifiedExcerpt.listFrom([
        {
          'documentId': 'a',
          'title': 't',
          'authority': 'x',
          'text': 'نص',
          'textLanguage': 'ar',
          'contentKind': 'contextual_evidence',
          'sourceReferences': [
            {'collection': 'صحيح البخاري', 'reference': '1597'},
            {'reference': 'orphan'},
          ],
        },
      ]);
      expect(list.single.sourceReferences, hasLength(1));
      expect(list.single.sourceReferences.single['collection'], 'صحيح البخاري');
      // Still not recitable — the citation says nothing about that.
      expect(list.single.isRecitable, isFalse);
    });

    test('an excerpt with no references is not a parse failure', () {
      final list = VerifiedExcerpt.listFrom([
        {
          'documentId': 'a',
          'title': 't',
          'authority': 'x',
          'text': 'نص',
          'textLanguage': 'ar',
        },
      ]);
      expect(list.single.sourceReferences, isEmpty);
    });
  });
}
