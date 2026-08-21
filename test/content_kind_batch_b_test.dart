// Batch B: three records at the Black Stone, three different dispositions.
//
// They arrived classified identically (`specific_text`), which meant the app
// would have shown all three with a «وارد في هذا الموضع» badge and a play
// button. Only one of them is a text a pilgrim says.
//
//   hajar-tasmiya  «بسم الله والله أكبر»      → recited. Stays specific_text.
//   hajar-umar     Umar's words at the Stone  → a narration cited to TEACH.
//   hajar-crowding the Prophet's instruction  → a directive to FOLLOW.
//
// Neither of the last two is a supplication. Shipping them as one has
// pilgrims reciting a narration about the Stone as though it were a dhikr.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Duas/widgets/content_kind_card.dart';
import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';

const _b1 = 'moia-1446-hajar-tasmiya';
const _b2 = 'moia-1446-hajar-umar';
const _b3 = 'moia-1446-hajar-crowding';

Map<String, dynamic> _entry(String id) {
  final pack = jsonDecode(
    File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return (pack['entries'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((e) => e['duaId'] == id);
}

SupplicationModel _model(SupplicationContentKind kind) => SupplicationModel(
      duaId: 'x',
      zoneId: '',
      title: const {'ar': 'ع'},
      text: const {'ar': 'نص'},
      audioMode: 'tts',
      audioUrl: '',
      languageCodes: const ['ar'],
      isActive: true,
      updatedAt: null,
      usageCount: 0,
      contentKind: kind,
      zoneKey: 'hajar_aswad',
    );

void main() {
  group('the three records are classified apart', () {
    test('B1 stays a recitable text', () {
      expect(_entry(_b1)['contentKind'], 'specific_text');
    });

    test('B2 is contextual evidence, not guidance and not a supplication', () {
      // Not procedural_guidance: it is a narration cited for benefit, not a
      // set of instructions to carry out.
      expect(_entry(_b2)['contentKind'], 'contextual_evidence');
    });

    test('B3 is procedural guidance', () {
      expect(_entry(_b3)['contentKind'], 'procedural_guidance');
    });

    test('none of the three texts was altered', () {
      // Reclassifying must never become an excuse to touch the wording.
      expect(_entry(_b1)['text']['ar'], 'بسم الله والله أكبر');
      expect(_entry(_b2)['text']['ar'],
          startsWith('إِنِّي أَعْلَمُ أَنَّكَ حَجَرٌ'));
      expect(_entry(_b3)['text']['ar'], startsWith('يَا أَبَا حَفْصٍ'));
      for (final id in [_b1, _b2, _b3]) {
        expect(_entry(id)['verificationStatus'], 'unverified');
      }
    });
  });

  group('only B1 is recitable and auto-playable', () {
    test('specific_text is recitable; the other two are not', () {
      expect(
          SupplicationContentKind.fromRaw('specific_text').isRecitable, isTrue);
      expect(SupplicationContentKind.fromRaw('contextual_evidence').isRecitable,
          isFalse);
      expect(SupplicationContentKind.fromRaw('procedural_guidance').isRecitable,
          isFalse);
    });

    test('neither B2 nor B3 belongs in the dua section', () {
      for (final raw in ['contextual_evidence', 'procedural_guidance']) {
        expect(
            SupplicationContentKind.fromRaw(raw).belongsInDuaSection, isFalse,
            reason: '$raw must never be counted as a supplication');
      }
    });

    test('only B1 is eligible for automatic playback', () {
      expect(
          _model(SupplicationContentKind.specificText).isAutoPlayable, isTrue);
      expect(_model(SupplicationContentKind.contextualEvidence).isAutoPlayable,
          isFalse);
      expect(_model(SupplicationContentKind.proceduralGuidance).isAutoPlayable,
          isFalse);
    });

    test('the partition puts each in its own bucket', () {
      final p = SupplicationPartition.of([
        _model(SupplicationContentKind.specificText),
        _model(SupplicationContentKind.contextualEvidence),
        _model(SupplicationContentKind.proceduralGuidance),
      ]);
      expect(p.recitable, hasLength(1));
      expect(p.guidance, hasLength(1));
      expect(p.evidence, hasLength(1));
      // No record may land in two buckets.
      expect(p.recitable.length + p.guidance.length + p.evidence.length, 3);
    });

    test('contextual evidence round-trips through raw', () {
      expect(SupplicationContentKind.contextualEvidence.raw,
          'contextual_evidence');
      expect(SupplicationContentKind.fromRaw('contextual_evidence'),
          SupplicationContentKind.contextualEvidence);
    });

    test('an unknown kind still degrades to a general dua, not to evidence',
        () {
      expect(SupplicationContentKind.fromRaw('nonsense'),
          SupplicationContentKind.generalDua);
    });
  });

  group('the evidence card keeps the narration a narration', () {
    testWidgets('it shows the attribution and offers no playback',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ContextualEvidenceCard(
            title: 'أثر عمر رضي الله عنه عند الحجر',
            body: 'إِنِّي أَعْلَمُ أَنَّكَ حَجَرٌ',
            attribution: 'أخرجه البخاري (1597) ومسلم (1270)',
          ),
        ),
      ));

      // Labelled as a narration, never as a supplication.
      expect(find.text('أثر موثّق'), findsOneWidget);
      expect(find.text('دعاء'), findsNothing);
      // The chain is the reason this record exists; hiding it guts the card.
      expect(find.text('أخرجه البخاري (1597) ومسلم (1270)'), findsOneWidget);
      // No play control of any kind.
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('its badge says it is for benefit, not for repetition',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ContentKindBadge(
              kind: SupplicationContentKind.contextualEvidence),
        ),
      ));
      expect(find.text('أثر موثّق — للفائدة لا للترديد'), findsOneWidget);
    });
  });

  group('the guidance card keeps the directive prophetic', () {
    testWidgets('a prophetic directive is labelled as one, with its source',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: GuidanceCard(
            title: 'النهي عن المزاحمة عند الحجر',
            body: 'يَا أَبَا حَفْصٍ إِنَّكَ رَجُلٌ قَوِيٌّ فَلَا تُزَاحِمْ',
            attribution: 'عبدالرزاق (5/36) وابن أبي شيبة (3/171)',
            isPropheticDirective: true,
          ),
        ),
      ));

      // Without this the Prophet's words read as ministry prose.
      expect(find.text('توجيه نبوي'), findsOneWidget);
      expect(
          find.text('عبدالرزاق (5/36) وابن أبي شيبة (3/171)'), findsOneWidget);
      // Not headed «دعاء». The badge below does contain the word — as
      // «إرشاد — ليس دعاءً», the opposite claim — so this checks the bare
      // heading rather than the substring.
      expect(find.text('دعاء'), findsNothing);
      expect(find.text('إرشاد — ليس دعاءً'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('an ordinary ruling is still labelled إرشاد', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: GuidanceCard(
            title: 'حكم',
            body: 'لا يصح الطواف من داخل الحِجْر',
          ),
        ),
      ));
      expect(find.text('إرشاد'), findsOneWidget);
      expect(find.text('توجيه نبوي'), findsNothing);
    });
  });

  group('B1 page provenance spans 65-67', () {
    test('the record cites the full range and starts at 65', () {
      final e = _entry(_b1);
      expect(e['printedPage'], 65);
      expect(e['sourceSection'], contains('65-67'));
      expect(e['sourceSection'], contains('صفحات'));
    });

    test('the ledger records all three pages as reviewed', () {
      final ledger = jsonDecode(
        File('review/human_review_ledger.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final r = (ledger['reviews'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((r) => r['recordId'] == _b1);
      expect((r['reviewedPages'] as List).cast<int>(), [65, 66, 67]);
      expect(r['reviewedPage'], 65,
          reason: 'the first page of the range is the starting page');
    });

    test('B2 and B3 remain single-page reviews', () {
      final ledger = jsonDecode(
        File('review/human_review_ledger.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final reviews = (ledger['reviews'] as List).cast<Map<String, dynamic>>();
      for (final entry in {_b2: 66, _b3: 67}.entries) {
        final r = reviews.firstWhere((r) => r['recordId'] == entry.key);
        expect(r['reviewedPages'], isNull);
        expect(r['reviewedPage'], entry.value);
      }
    });
  });

  group('B2 and B3 are held back until the classification ships', () {
    final ledger = jsonDecode(
      File('review/human_review_ledger.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final reviews = (ledger['reviews'] as List).cast<Map<String, dynamic>>();
    Map<String, dynamic> review(String id) =>
        reviews.firstWhere((r) => r['recordId'] == id);

    test('their text passed — the hold is ours, not the source\'s', () {
      for (final id in [_b2, _b3]) {
        final r = review(id);
        expect(r['textReviewStatus'], 'passed');
        expect(r['reviewStatus'], isNot('blocked'),
            reason: 'the wording is faithful; only the presentation was wrong');
        expect(r['deploymentBlocked'], isTrue);
        expect(r['deploymentBlockReason'], 'content_kind_not_yet_deployed');
        expect(r['excludedFromImport'], isTrue);
      }
    });

    test('B1 is not held back', () {
      final r = review(_b1);
      expect(r['deploymentBlocked'], isNull);
      expect(r['excludedFromImport'], isNull);
    });

    test('the reclassification is recorded, not silently applied', () {
      for (final id in [_b2, _b3]) {
        expect(review(id)['contentKindChangedFrom'], 'specific_text',
            reason: 'an audit must show what the classification used to be');
      }
      expect(review(_b2)['contentKindConfirmed'], 'contextual_evidence');
      expect(review(_b3)['contentKindConfirmed'], 'procedural_guidance');
    });
  });
}
