// Card-classification tests.
//
// These guard two safety rules that are easy to break silently in UI work:
//
//   1. A `procedural_guidance` record is a ruling or instruction — e.g.
//      «لا يصح الطواف من داخل الحِجْر» — NOT a text to be recited. It must
//      never be counted as a dua, offered for playback, or rendered under a
//      «دعاء» heading. It belongs in its own guidance card.
//
//   2. Only `specific_text` is tied to a place. Everything else (general
//      dua/dhikr, mosque-entry) must carry a visible label saying it is not
//      specific to where the pilgrim is standing, so the app never implies
//      the source prescribed it for that spot.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Duas/widgets/content_kind_card.dart';
import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';

SupplicationModel _model({
  required String id,
  required SupplicationContentKind kind,
  String zoneKey = '',
}) {
  return SupplicationModel(
    duaId: id,
    zoneId: '',
    title: const {'ar': 'عنوان'},
    text: const {'ar': 'نص'},
    audioMode: 'tts',
    audioUrl: '',
    languageCodes: const ['ar'],
    isActive: true,
    updatedAt: null,
    usageCount: 0,
    contentKind: kind,
    zoneKey: zoneKey,
  );
}

void main() {
  group('SupplicationContentKind parsing', () {
    test('parses every raw value used by the source packs', () {
      expect(SupplicationContentKind.fromRaw('specific_text'),
          SupplicationContentKind.specificText);
      expect(SupplicationContentKind.fromRaw('general_dua'),
          SupplicationContentKind.generalDua);
      expect(SupplicationContentKind.fromRaw('general_dhikr'),
          SupplicationContentKind.generalDhikr);
      expect(SupplicationContentKind.fromRaw('mosque_entry'),
          SupplicationContentKind.mosqueEntry);
      expect(SupplicationContentKind.fromRaw('procedural_guidance'),
          SupplicationContentKind.proceduralGuidance);
    });

    test('an unknown or missing kind falls back to the SAFE option', () {
      // The fallback must never be `specificText`: a legacy record with no
      // classification would then silently claim the source tied it to a
      // place. General is the only fallback that cannot over-claim.
      for (final raw in <String?>[null, '', 'nonsense', 'SPECIFIC_TEXT']) {
        expect(SupplicationContentKind.fromRaw(raw),
            SupplicationContentKind.generalDua,
            reason: 'raw=$raw must fall back to a non-specific kind');
      }
    });

    test('raw round-trips for every kind', () {
      for (final kind in SupplicationContentKind.values) {
        expect(SupplicationContentKind.fromRaw(kind.raw), kind);
      }
    });
  });

  group('classification rules', () {
    test('guidance and contextual evidence are the non-recitable kinds', () {
      // Two ways a text can be in the collection without being something a
      // pilgrim says: it instructs (procedural_guidance), or it is cited as
      // evidence (contextual_evidence). Everything else is recited.
      const nonRecitable = {
        SupplicationContentKind.proceduralGuidance,
        SupplicationContentKind.contextualEvidence,
      };
      for (final kind in SupplicationContentKind.values) {
        expect(kind.isRecitable, !nonRecitable.contains(kind), reason: '$kind');
        expect(kind.belongsInDuaSection, !nonRecitable.contains(kind),
            reason: '$kind');
      }
    });

    test('guidance never belongs in the dua section', () {
      expect(SupplicationContentKind.proceduralGuidance.belongsInDuaSection,
          isFalse);
    });

    test('only specific_text is tied to a location', () {
      for (final kind in SupplicationContentKind.values) {
        expect(
          kind.isTiedToLocation,
          kind == SupplicationContentKind.specificText,
          reason: '$kind must not claim to be tied to a place',
        );
      }
    });

    test('every non-specific kind is labelled as not specific to the place',
        () {
      const notSpecific = [
        SupplicationContentKind.generalDua,
        SupplicationContentKind.generalDhikr,
        SupplicationContentKind.mosqueEntry,
      ];
      for (final kind in notSpecific) {
        final badge = kind.badgeAr();
        expect(badge.trim(), isNotEmpty);
        expect(badge.contains('عام'), isTrue,
            reason: '$kind badge must say it is general: "$badge"');
      }
      expect(SupplicationContentKind.proceduralGuidance.badgeAr(),
          contains('ليس دعاءً'));
    });
  });

  group('SupplicationPartition', () {
    test('splits guidance out of the recitable list', () {
      final items = [
        _model(id: 'a', kind: SupplicationContentKind.specificText),
        _model(id: 'b', kind: SupplicationContentKind.proceduralGuidance),
        _model(id: 'c', kind: SupplicationContentKind.generalDua),
        _model(id: 'd', kind: SupplicationContentKind.proceduralGuidance),
        _model(id: 'e', kind: SupplicationContentKind.mosqueEntry),
      ];

      final partition = SupplicationPartition.of(items);

      expect(partition.recitable.map((e) => e.duaId), ['a', 'c', 'e']);
      expect(partition.guidance.map((e) => e.duaId), ['b', 'd']);
    });

    test('every record lands in exactly one side of the partition', () {
      final items = [
        for (final kind in SupplicationContentKind.values)
          _model(id: kind.raw, kind: kind),
      ];

      final partition = SupplicationPartition.of(items);

      expect(
          partition.recitable.length +
              partition.guidance.length +
              partition.evidence.length,
          items.length);
      final recitableIds = partition.recitable.map((e) => e.duaId).toSet();
      final guidanceIds = partition.guidance.map((e) => e.duaId).toSet();
      final evidenceIds = partition.evidence.map((e) => e.duaId).toSet();
      expect(recitableIds.intersection(guidanceIds), isEmpty);
      expect(recitableIds.intersection(evidenceIds), isEmpty);
      expect(guidanceIds.intersection(evidenceIds), isEmpty);
    });
  });

  group('widgets', () {
    testWidgets('the guidance card is labelled إرشاد and offers no playback',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: GuidanceCard(
              title: 'لا يصح الطواف من داخل الحِجْر',
              body: 'من طاف من داخل الحِجْر لم يصح طوافه.',
            ),
          ),
        ),
      ));

      expect(find.text('إرشاد'), findsOneWidget);
      expect(find.text(SupplicationContentKind.proceduralGuidance.badgeAr()),
          findsOneWidget);

      // The word «دعاء» must not head this card, and there must be no way to
      // play a ruling as if it were a recitation.
      expect(find.text('دعاء'), findsNothing);
      expect(find.byIcon(Icons.play_circle_fill_rounded), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('a general dua badge tells the pilgrim it is not specific',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ContentKindBadge(kind: SupplicationContentKind.generalDua),
          ),
        ),
      ));

      expect(find.textContaining('غير مخصوص بهذا الموضع'), findsOneWidget);
    });
  });
}
