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

    test('hajar-crowding records two numbered and two unnumbered sources', () {
      final refs =
          (_entry('moia-1446-hajar-crowding')['sourceReferences'] as List)
              .cast<Map<String, dynamic>>();
      expect(refs, hasLength(4));

      final numbered = refs.where((r) => r.containsKey('reference'));
      expect(numbered, hasLength(2));
      expect(
          numbered.map((r) => r['reference']), containsAll(['5/36', '3/171']));
      for (final r in numbered) {
        expect(r['referenceKind'], 'volume_page');
      }

      // al-Shafi'i and Ahmad are named on the page with no number at all.
      final unnumbered = refs.where((r) => !r.containsKey('reference'));
      expect(unnumbered, hasLength(2));
      for (final r in unnumbered) {
        expect(r['referenceKind'], 'unspecified');
        expect(r.containsKey('reference'), isFalse,
            reason: 'a number nobody printed must not be invented, and "" '
                'would claim we looked and found none');
      }
      expect(unnumbered.map((r) => r['collection']),
          containsAll(['الشافعي', 'أحمد']));
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

    test('the citedOnPage of a reference lies within the record\'s pages', () {
      // A citation attributed to a page the reviewer never read would be
      // provenance in name only.
      final pack = jsonDecode(
        File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final e in (pack['entries'] as List).cast<Map<String, dynamic>>()) {
        final refs = (e['sourceReferences'] as List? ?? []);
        if (refs.isEmpty) continue;
        final section = e['sourceSection'] as String;
        final nums = RegExp(r'\d+')
            .allMatches(section.substring(section.lastIndexOf('صفح')))
            .map((m) => int.parse(m.group(0)!))
            .toList();
        final lo = nums.first;
        final hi = nums.length > 1 ? nums.last : nums.first;
        for (final r in refs.cast<Map<String, dynamic>>()) {
          final page = r['citedOnPage'] as int;
          expect(page >= lo && page <= hi, isTrue,
              reason: '${e['duaId']} cites page $page but covers $lo-$hi');
        }
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
