// Batches G1, G2 and G4 — Tawaf preliminaries, adab, and the free-dhikr rule.
//
// Two records on page 68 were EXCERPTS closed by a full stop the book does
// not print at that position. That is a small thing that reads as a large
// one: a period says "the source's thought ends here", and in both cases it
// did not. Both now carry the complete printed unit and end on the book's
// own period.
//
// Page 70 brings the first citation the ministry itself qualifies. Three
// takhrījs are marked «بإسنادٍ فيه ضعف», and a fourth is «موقوف» on ʿĀ'isha —
// which is not a weaker grade but a different fact, about where the chain
// stops. The two are stored in separate fields for exactly that reason, and
// neither may read as authentication.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';

const String kAdab = 'moia-1446-tawaf-adab';
const String kDirection = 'moia-1446-tawaf-direction';
const String kFreeDhikr = 'moia-1446-tawaf-free-dhikr';

const List<String> kG1 = [
  'moia-1446-tawaf-no-verbal-niyyah',
  'moia-1446-idtiba',
  'moia-1446-raml',
];
const List<String> kG2 = [
  kAdab,
  'moia-1446-tawaf-women-crowding',
  kDirection,
];
const List<String> kG4 = [kFreeDhikr, 'moia-1446-tawaf-no-per-circuit'];

List<Map<String, dynamic>> _entries() => ((jsonDecode(
      File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
    ) as Map<String, dynamic>)['entries'] as List)
        .cast<Map<String, dynamic>>();

Map<String, dynamic> _entry(String id) =>
    _entries().firstWhere((e) => e['duaId'] == id);

SupplicationModel _model(String id) => SupplicationModel.fromJson(_entry(id));

Map<String, Map<String, dynamic>> _reviews() {
  final l = jsonDecode(
    File('review/human_review_ledger.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return {
    for (final r in (l['reviews'] as List).cast<Map<String, dynamic>>())
      r['recordId'] as String: r
  };
}

void main() {
  group('G1/G2/G4 stay guidance and are playable by nothing', () {
    test('all eight keep procedural_guidance', () {
      for (final id in [...kG1, ...kG2, ...kG4]) {
        expect(
            _model(id).contentKind, SupplicationContentKind.proceduralGuidance,
            reason: id);
        expect(_reviews()[id]!['contentKindConfirmed'], 'procedural_guidance');
      }
    });

    test('none is recitable, playable, or carries audio', () {
      for (final id in [...kG1, ...kG2, ...kG4]) {
        final m = _model(id);
        expect(m.canPlayManually, isFalse, reason: id);
        expect(m.isAutoPlayable, isFalse, reason: id);
        expect(m.contentKind.isRecitable, isFalse, reason: id);
        expect(m.audioUrl.trim(), isEmpty, reason: id);
        expect(m.recitationPolicy, isNull, reason: id);
      }
    });

    test('completing the review added no deployment hold', () {
      for (final id in [...kG1, ...kG2, ...kG4]) {
        final r = _reviews()[id]!;
        expect(r['reviewStatus'], 'passed', reason: id);
        expect(r['deploymentBlocked'], isFalse, reason: id);
        expect(r['excludedFromImport'], isFalse, reason: id);
      }
    });
  });

  group('the two extended records end on the book\'s own punctuation', () {
    test('tawaf-adab runs to the end of the printed paragraph', () {
      final t = _entry(kAdab)['text']['ar'] as String;
      expect(t.endsWith('والمشاجرة.'), isTrue,
          reason: 'the paragraph\'s real terminal period');
      // The clauses that used to be missing are present.
      for (final clause in [
        'جلالة هذه البقعة',
        'ما نزعت إلا من شقي',
        'الخشوع والتضرع',
        'اللغو، والجدال، والمشاجرة',
      ]) {
        expect(t.contains(clause), isTrue, reason: clause);
      }
      // And the old excerpt boundary is now a comma, not a full stop.
      expect(t.contains('لئلا يؤذيهم، وعلىٰ الطائف'), isTrue);
      expect(t.contains('لئلا يؤذيهم.'), isFalse,
          reason: 'the invented period is gone');
    });

    test('tawaf-direction runs across the page break to the p69 period', () {
      final t = _entry(kDirection)['text']['ar'] as String;
      expect(t.endsWith('ولا يُشير إليه.'), isTrue);
      expect(t.contains('علىٰ يساره، فإذا وصل الركنَ اليماني'), isTrue);
      expect(t.contains('علىٰ يساره.'), isFalse,
          reason: 'the invented period is gone');
      final r = _reviews()[kDirection]!;
      expect(r['reviewedPages'], [68, 69]);
      expect(r['reviewedPage'], 68);
      expect(_entry(kDirection)['printedPage'], 68);
    });

    test('neither extension duplicates another record\'s text', () {
      // The parenthetical «(بسم الله والله أكبر)» overlaps two recitable
      // records, but that quotation predates this change and sits in the
      // stored prefix — the APPENDED spans introduce no new overlap.
      for (final id in [kAdab, kDirection]) {
        final t = _entry(id)['text']['ar'] as String;
        for (final other in _entries()) {
          final o = (other['text']['ar'] as String).trim();
          if (other['duaId'] == id || o.isEmpty) continue;
          if (!t.contains(o)) continue;
          expect([
            'moia-mukhtasar-1446-tawaf-takbir-hajar',
            'moia-1446-hajar-tasmiya'
          ], contains(other['duaId']),
              reason: '$id newly contains ${other['duaId']}');
        }
      }
    });

    test('the corrections are recorded as corrections', () {
      expect(_reviews()[kAdab]!['transcriptionCorrected'], isTrue);
      expect(_reviews()[kDirection]!['transcriptionCorrected'], isTrue);
      expect(
          _reviews()['moia-1446-tawaf-women-crowding']![
              'transcriptionCorrected'],
          isFalse,
          reason: 'that one was already a complete printed unit');
    });
  });

  group('page 70 citations carry what the ministry printed', () {
    List<SourceReference> refs() => _model(kFreeDhikr).sourceReferences;

    test('the three takhrijs carry the weakness, and only they do', () {
      final weak =
          refs().where((r) => r.sourceAssessment == SourceReference.weakIsnad);
      expect(weak, hasLength(3));
      expect(weak.map((r) => r.reference).toList()..sort(),
          ['1888', '24351', '902']);
      for (final r in weak) {
        expect(r.qualifierAr(), 'بإسنادٍ فيه ضعف');
        expect(r.attributionLevel, isNull,
            reason: 'a weakness is not a stopping point');
      }
    });

    test('the athar is mawquf, not "more weak"', () {
      final a = refs().firstWhere((r) => r.type == 'athar');
      expect(a.referenceKind, 'volume_page');
      expect(a.reference, '5/49');
      expect(a.attributionLevel, SourceReference.mawquf);
      expect(a.attributedTo, 'عائشة رضي الله عنها');
      expect(a.sourceAssessment, isNull,
          reason: 'mawquf says where the chain stops, not how sound it is');
      expect(a.qualifierAr(), 'موقوف على عائشة رضي الله عنها');
    });

    test('attributedTo is shown only when it is present', () {
      const withWho = SourceReference(
        type: 'athar',
        collection: 'x',
        referenceKind: 'volume_page',
        citedBy: 'moia_1446',
        citedOnPage: 70,
        attributionLevel: SourceReference.mawquf,
        attributedTo: 'فلان',
      );
      const without = SourceReference(
        type: 'athar',
        collection: 'x',
        referenceKind: 'volume_page',
        citedBy: 'moia_1446',
        citedOnPage: 70,
        attributionLevel: SourceReference.mawquf,
      );
      expect(withWho.qualifierAr(), 'موقوف على فلان');
      expect(without.qualifierAr(), 'موقوف',
          reason: 'no trailing "على" with nobody after it');
    });

    test('a reference with no qualifier shows none', () {
      const plain = SourceReference(
        type: 'hadith',
        collection: 'صحيح البخاري',
        reference: '1609',
        referenceKind: 'hadith_number',
        citedBy: 'moia_1446',
        citedOnPage: 69,
      );
      expect(plain.qualifierAr(), isNull,
          reason: 'silence about a chain is silence, not authentication');
    });

    test('unknown values read as absent on the client', () {
      final parsed = SourceReference.listFrom([
        {
          'type': 'hadith',
          'collection': 'x',
          'referenceKind': 'hadith_number',
          'citedBy': 'moia_1446',
          'citedOnPage': 70,
          'sourceAssessment': 'sahih',
          'attributionLevel': 'marfu',
        }
      ]);
      expect(parsed.single.sourceAssessment, isNull);
      expect(parsed.single.attributionLevel, isNull);
      expect(parsed.single.qualifierAr(), isNull,
          reason: 'never invent a grading the client cannot render');
    });

    test('«وغيرهم» appears only under the declared completeness', () {
      expect(_model(kFreeDhikr).sourceReferencesCompleteness,
          SupplicationModel.namedReferencesPlusUnnamedOthers);
      expect(_model(kFreeDhikr).hasUnnamedFurtherReferences, isTrue);
      // Every other record in the pack declares nothing, so shows nothing.
      for (final e in _entries()) {
        if (e['duaId'] == kFreeDhikr) continue;
        expect(
            SupplicationModel.fromJson(e).hasUnnamedFurtherReferences, isFalse,
            reason: '${e['duaId']} must not claim unnamed further sources');
      }
      // And an unknown value reads as absent.
      final raw = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(_model(kFreeDhikr).toJson()))
              as Map<String, dynamic>);
      raw['sourceReferencesCompleteness'] = 'everything';
      expect(
          SupplicationModel.fromJson(raw).hasUnnamedFurtherReferences, isFalse);
    });

    test('a record with no references never shows «وغيرهم»', () {
      final m = SupplicationModel.fromJson({
        'duaId': 'x',
        'text': {'ar': 'y', 'en': ''},
        'title': {'ar': 'y', 'en': ''},
        'sourceReferencesCompleteness':
            SupplicationModel.namedReferencesPlusUnnamedOthers,
      });
      expect(m.sourceReferences, isEmpty);
      expect(m.hasUnnamedFurtherReferences, isFalse,
          reason: 'a claim about a list that does not exist');
    });
  });

  group('the new fields change nothing about content or verification', () {
    test('recitability and playability are untouched', () {
      final m = _model(kFreeDhikr);
      expect(m.sourceReferences, hasLength(4));
      expect(m.contentKind.isRecitable, isFalse);
      expect(m.canPlayManually, isFalse,
          reason: 'a weak citation does not make guidance recitable, and a '
              'sound one would not either');
      expect(m.isAutoPlayable, isFalse);
      expect(m.isVerifiedSource, isFalse);
      expect(_entry(kFreeDhikr)['verificationStatus'], 'unverified');
    });

    test('they survive an offline round trip without gaining authority', () {
      final back = SupplicationModel.fromJson(
          jsonDecode(jsonEncode(_model(kFreeDhikr).toJson()))
              as Map<String, dynamic>);
      expect(back.sourceReferences, hasLength(4));
      expect(
          back.sourceReferences
              .where((r) => r.sourceAssessment == SourceReference.weakIsnad),
          hasLength(3));
      expect(back.hasUnnamedFurtherReferences, isTrue);
      expect(back.isVerifiedSource, isFalse);
      expect(back.canPlayManually, isFalse);
    });

    test('the qualifiers are never rendered as authentication badges', () {
      final card = File(
        'lib/Screens/Piligram/Duas/widgets/content_kind_card.dart',
      ).readAsStringSync();
      // They live in the plain reference list, not in ContentKindBadge or
      // any badge-shaped widget.
      expect(card.contains('qualifierAr()'), isTrue);
      final badge = card.substring(card.indexOf('class ContentKindBadge'),
          card.indexOf('class RecitationPolicyNote'));
      expect(badge.contains('qualifierAr'), isFalse);
      expect(badge.contains('sourceAssessment'), isFalse);
    });
  });

  group('G7 was NOT reviewed', () {
    test('page 74 records have no review entry', () {
      // The page is not available in this session. A review nobody performed
      // must never appear in the ledger.
      final reviews = _reviews();
      for (final id in [
        'moia-mukhtasar-1446-umrah-taqsir-shamil',
        'moia-mukhtasar-1446-umrah-taqsir-mara',
        'moia-mukhtasar-1446-umrah-tamam-umrah',
      ]) {
        expect(reviews.containsKey(id), isFalse,
            reason: '$id has no page to have been reviewed against');
      }
    });
  });

  group('nothing was verified', () {
    test('all 85 remain unverified', () {
      final entries = _entries();
      expect(entries, hasLength(85));
      for (final e in entries) {
        expect(e['verificationStatus'], 'unverified', reason: '${e['duaId']}');
        expect(e['verifiedAt'], isNull);
      }
    });
  });
}
