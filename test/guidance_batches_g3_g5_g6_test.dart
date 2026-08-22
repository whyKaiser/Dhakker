// Batches G3, G5 and G6 — the Tawaf narration, the Maqam warnings, and the
// Sa'i guidance.
//
// G3 is the substantive one. `moia-mukhtasar-1446-tawaf-touching` stored a
// HADITH in full ḥarakāt under `procedural_guidance`: the ruling lived in
// the title and the review note, never in `text.ar`. Guidance and evidence
// look alike in a database and are very different on a screen — one is the
// app telling the pilgrim what to do, the other is a narration shown with
// its chain. It is now `contextual_evidence`.
//
// G5 and G6 confirm six records that were already correctly classified.
// Completing a human review changes what we KNOW, not what the app DOES, so
// none of them gains a deployment hold.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Duas/widgets/content_kind_card.dart';
import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';

const String kTouching = 'moia-mukhtasar-1446-tawaf-touching';

const List<String> kG5 = [
  'moia-1446-tawaf-seven',
  'moia-1446-maqam-crowding',
  'moia-1446-maqam-no-tamassuh',
];

const List<String> kG6 = [
  'moia-1446-sai-no-per-circuit',
  'moia-1446-sai-sunan',
  'moia-1446-sai-seven',
];

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
  group('G3 — the Tawaf narration renders only as contextual evidence', () {
    test('it is classified as evidence, not guidance and not a dua', () {
      final m = _model(kTouching);
      expect(m.contentKind, SupplicationContentKind.contextualEvidence);
      expect(m.contentKind.isRecitable, isFalse);
      expect(m.contentKind.belongsInDuaSection, isFalse);
      expect(m.contentKind.badgeAr(), 'أثر موثّق — للفائدة لا للترديد');
    });

    test('no playback path reaches it', () {
      final m = _model(kTouching);
      expect(m.canPlayManually, isFalse,
          reason: 'the audio button and voice search both gate on this');
      expect(m.isAutoPlayable, isFalse);
      expect(m.audioUrl.trim(), isEmpty,
          reason: 'an audio file would be a second path around the gate');
      final screen =
          File('lib/Screens/Piligram/Duas/duas_screen.dart').readAsStringSync();
      expect(screen.contains('if (!dua.canPlayManually) return;'), isTrue);
    });

    test('the partition routes it to the evidence bucket alone', () {
      final mataf = _entries()
          .where((e) => e['zoneKey'] == 'mataf')
          .map(SupplicationModel.fromJson)
          .toList();
      final p = SupplicationPartition.of(mataf);
      expect(p.evidence.map((e) => e.duaId), contains(kTouching));
      expect(p.recitable.map((e) => e.duaId), isNot(contains(kTouching)));
      expect(p.guidance.map((e) => e.duaId), isNot(contains(kTouching)));
    });

    test('the evidence card can render it — attribution is present', () {
      // ContextualEvidenceCard REQUIRES attribution: a narration shown
      // without its source has lost the reason it is on screen.
      final m = _model(kTouching);
      expect(m.attribution.trim(), isNotEmpty);
      expect(m.authority.trim(), isNotEmpty);
      expect(m.sourceSection.trim(), isNotEmpty);
    });

    test('Bukhari and Muslim appear as attribution, exactly as printed', () {
      final refs = (_entry(kTouching)['sourceReferences'] as List)
          .cast<Map<String, dynamic>>();
      expect(refs, hasLength(2));
      final byCollection = {for (final r in refs) r['collection'] as String: r};
      expect(byCollection['صحيح البخاري']!['reference'], '1609');
      expect(byCollection['صحيح مسلم']!['reference'], '1267');
      for (final r in refs) {
        expect(r['type'], 'hadith');
        expect(r['referenceKind'], 'hadith_number');
        expect(r['citedBy'], 'moia_1446',
            reason: 'what the MINISTRY cited — not our own research');
        expect(r['citedOnPage'], 69);
      }
    });

    test('the references never affect verification or recitability', () {
      final m = _model(kTouching);
      expect(m.sourceReferences, hasLength(2));
      expect(m.isVerifiedSource, isFalse,
          reason: 'a citation is a claim about a source, not an approval');
      expect(_entry(kTouching)['verificationStatus'], 'unverified');
      expect(m.canPlayManually, isFalse,
          reason: 'a sound chain does not make a narration a dhikr');
      // And they survive an offline round trip without gaining authority.
      final back = SupplicationModel.fromJson(
          jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
      expect(back.sourceReferences, hasLength(2));
      expect(back.isVerifiedSource, isFalse);
      expect(back.canPlayManually, isFalse);
    });

    test('the salutation is stored as words — no U+FDFA in any stored text',
        () {
      // The audit reported a `ﷺ` form in storage. It is not there: the
      // ligature appears only in administrative reviewNotes that DESCRIBE
      // the printed glyph. No religious text in the pack contains it, so
      // there was nothing to correct.
      for (final e in _entries()) {
        for (final field in ['text', 'title']) {
          for (final v in (e[field] as Map).values) {
            expect((v as String).contains('ﷺ'), isFalse,
                reason: '${e['duaId']}.$field carries the ligature');
          }
        }
      }
      final stored = _entry(kTouching)['text']['ar'] as String;
      expect(stored.contains('صَلَّى اللهُ عَلَيْهِ وَسَلَّمَ'), isTrue,
          reason: 'spelled out, fully vocalised, as page 69 prints it');
    });

    test('it is held until the evidence card ships', () {
      final r = _reviews()[kTouching]!;
      expect(r['reviewStatus'], 'passed');
      expect(r['textReviewStatus'], 'passed');
      expect(r['reviewedPage'], 69);
      expect(r['contentKindChangedFrom'], 'procedural_guidance');
      expect(r['contentKindConfirmed'], 'contextual_evidence');
      expect(r['transcriptionCorrected'], isFalse);
      expect(r['sourceReferencesReviewStatus'], 'reviewed_present');
      expect(r['deploymentBlocked'], isTrue,
          reason: 'the pilgrim-facing card changed and has not been released');
      expect(r['excludedFromImport'], isTrue);
      expect(r['deploymentBlockLiftConditions']['liftedAt'], isNull);
    });
  });

  group('G5 and G6 — six records confirmed as guidance', () {
    test('all six stay procedural guidance', () {
      for (final id in [...kG5, ...kG6]) {
        expect(
            _model(id).contentKind, SupplicationContentKind.proceduralGuidance,
            reason: id);
        expect(_reviews()[id]!['contentKindConfirmed'], 'procedural_guidance');
      }
    });

    test('none of them is playable by any path', () {
      for (final id in [...kG5, ...kG6]) {
        final m = _model(id);
        expect(m.canPlayManually, isFalse, reason: id);
        expect(m.isAutoPlayable, isFalse, reason: id);
        expect(m.contentKind.isRecitable, isFalse, reason: id);
        expect(m.audioUrl.trim(), isEmpty, reason: id);
        expect(m.recitationPolicy, isNull,
            reason: '$id: guidance carries no performance instruction');
      }
    });

    test('completing a review added NO deployment hold', () {
      // A hold waits on unreleased presentation. Nothing about these six
      // changed — same kind, same card, same behaviour — so recording that
      // a human read the page must not hold them back.
      for (final id in [...kG5, ...kG6]) {
        final r = _reviews()[id]!;
        expect(r['reviewStatus'], 'passed', reason: id);
        expect(r['deploymentBlocked'], isFalse, reason: id);
        expect(r['excludedFromImport'], isFalse, reason: id);
        expect(r.containsKey('contentKindChangedFrom'), isFalse, reason: id);
      }
    });

    test('maqam-no-tamassuh requires BOTH of its pages', () {
      final r = _reviews()['moia-1446-maqam-no-tamassuh']!;
      expect(r['reviewedPages'], [71, 72],
          reason: 'the sentence runs across the page break');
      expect(r['reviewedPage'], 71, reason: 'first page of the range');
      // Its own record agrees about the span.
      expect(_entry('moia-1446-maqam-no-tamassuh')['sourceSection'],
          contains('71-72'));
    });

    test('single-page records do not claim a range', () {
      for (final id in [...kG5, ...kG6]) {
        if (id == 'moia-1446-maqam-no-tamassuh') continue;
        final r = _reviews()[id]!;
        expect(r.containsKey('reviewedPages'), isFalse, reason: id);
        expect(r['reviewedPage'], _entry(id)['printedPage'], reason: id);
      }
    });

    test('no source reference was invented where the pages print none', () {
      for (final id in [...kG5, ...kG6]) {
        expect(_entry(id)['sourceReferences'], isEmpty,
            reason: '$id: the printed pages carry no citation for it');
      }
    });

    test('reviewed_none means the pages WERE read and carried no citation', () {
      for (final id in [...kG5, ...kG6]) {
        final r = _reviews()[id]!;
        expect(r['sourceReferencesReviewStatus'], 'reviewed_none', reason: id);
        // The distinction that matters: a page was actually read. Without a
        // recorded page this would be indistinguishable from never looking.
        expect(r['reviewedPage'], isNotNull, reason: id);
        expect(_entry(id)['sourceReferences'], isEmpty, reason: id);
      }
    });

    test('no per-circuit dua is created or implied anywhere', () {
      // Two of these records are the printed BASIS for that rule. None may
      // itself become a text a pilgrim is told to say each circuit.
      for (final id in [
        'moia-1446-sai-no-per-circuit',
        'moia-1446-tawaf-seven',
        'moia-1446-sai-seven',
      ]) {
        final m = _model(id);
        expect(m.canPlayManually, isFalse, reason: id);
        expect(m.recitationPolicy, isNull, reason: id);
        expect(m.usageQualifier, isNull, reason: id);
        expect(m.relatedRecordIds, isEmpty,
            reason: '$id must not point at a text as "the circuit dua"');
      }
    });

    test('all six stay unverified', () {
      for (final id in [...kG5, ...kG6]) {
        expect(_entry(id)['verificationStatus'], 'unverified', reason: id);
        expect(_entry(id)['verifiedAt'], isNull, reason: id);
      }
    });
  });

  group('audio inventory is untouched by these seven records', () {
    const recitable = {
      'specific_text',
      'general_dua',
      'general_dhikr',
      'mosque_entry',
    };

    test('none of the seven enters the recitable set', () {
      final ids = _entries()
          .where((e) => recitable.contains(e['contentKind']))
          .map((e) => e['duaId'])
          .toSet();
      for (final id in [kTouching, ...kG5, ...kG6]) {
        expect(ids, isNot(contains(id)), reason: id);
      }
    });

    test('the canonical audio estimate is still 59', () {
      final rec = _entries()
          .where((e) => recitable.contains(e['contentKind']))
          .toList();
      expect(rec, hasLength(60));
      final unique = rec.map((e) => (e['text']['ar'] as String).trim()).toSet();
      expect(unique, hasLength(59),
          reason: 'one legitimate duplicate shares a single audio file');
    });

    test('reclassifying to evidence REMOVED a record from the audio set', () {
      // tawaf-touching was `procedural_guidance` before, so it never counted;
      // it is `contextual_evidence` now and still does not. The count is
      // stable because the change moved between two non-recitable kinds.
      final m = _model(kTouching);
      expect(m.contentKind.isRecitable, isFalse);
      expect(recitable.contains(_entry(kTouching)['contentKind']), isFalse);
    });
  });

  group('the whole pack is still unverified', () {
    test('all 85', () {
      final entries = _entries();
      expect(entries, hasLength(85));
      for (final e in entries) {
        expect(e['verificationStatus'], 'unverified', reason: '${e['duaId']}');
        expect(e['verifiedAt'], isNull);
        expect(e['verifiedBy'], isNull);
      }
    });
  });
}
