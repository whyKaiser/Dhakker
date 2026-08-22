// High-risk content audit: the corpus, the three reviewed records, the
// verbatim contract, and the citation-review states.
//
// The corpus check comes first and is not decoration. In the previous
// report I claimed the repository held provenance metadata only and fell
// back to rasm heuristics — the pinned KFGQPC corpus was tracked in Git the
// whole time. A heuristic that "detects Quran" by counting Uthmani code
// points cannot tell a correct excerpt from a corrupted one; only the corpus
// can. These tests fail if that file ever stops being read.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/services/assistant_service.dart';
import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';

const String kCorpus = 'third_party/kfgqpc/hafsData_v2-0.json';
const String kBetween = 'moia-mukhtasar-1446-tawaf-between-corners';
const String kGeneral001 = 'moia-mukhtasar-1446-general-001';
const String kHalq = 'moia-mukhtasar-1446-umrah-halq-shamil';
const String kReturnHajar = 'moia-1446-return-hajar';

List<Map<String, dynamic>> _entries() => ((jsonDecode(
      File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
    ) as Map<String, dynamic>)['entries'] as List)
        .cast<Map<String, dynamic>>();

Map<String, dynamic> _entry(String id) =>
    _entries().firstWhere((e) => e['duaId'] == id);

SupplicationModel _model(String id) => SupplicationModel.fromJson(_entry(id));

Map<String, dynamic> _ledger() => jsonDecode(
      File('review/human_review_ledger.json').readAsStringSync(),
    ) as Map<String, dynamic>;

Map<String, Map<String, dynamic>> _reviews() => {
      for (final r
          in (_ledger()['reviews'] as List).cast<Map<String, dynamic>>())
        r['recordId'] as String: r
    };

List<Map<String, dynamic>> _corpus() => (jsonDecode(
      File(kCorpus).readAsStringSync(),
    ) as List)
        .cast<Map<String, dynamic>>();

String _ayah(int sura, int aya) => _corpus().firstWhere((r) =>
    int.parse('${r['sura_no']}') == sura &&
    int.parse('${r['aya_no']}') == aya)['aya_text'] as String;

void main() {
  group('the pinned KFGQPC corpus is present and is what we compare against',
      () {
    test('the corpus file exists and is the full mushaf', () {
      final f = File(kCorpus);
      expect(f.existsSync(), isTrue,
          reason: '$kCorpus is the authority; without it every Quran check '
              'below degrades to a heuristic');
      expect(_corpus(), hasLength(6236),
          reason: 'the whole mushaf, not a manifest or a subset');
    });

    test('it carries real ayah text, not just provenance metadata', () {
      final r = _corpus().first;
      expect(r.keys, contains('aya_text'));
      expect(r.keys, contains('sura_no'));
      expect(r.keys, contains('aya_no'));
      expect((_ayah(2, 201)).trim(), isNotEmpty);
      expect((_ayah(48, 27)).trim(), isNotEmpty);
    });

    test('every Quran-checking test file compares against the corpus', () {
      // The mistake that produced the previous report was concluding "no
      // corpus is available" and reaching for a rasm heuristic. A scan that
      // decides "this looks Quranic" by spotting Uthmani code points can
      // confirm nothing about correctness — only the pinned file can. So
      // every test that touches Quran text must read it.
      final quranTests = Directory('test')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) {
        final src = f.readAsStringSync();
        return src.contains('quranRef') || src.contains('aya_text');
      }).toList();
      expect(quranTests, isNotEmpty);
      for (final f in quranTests) {
        expect(f.readAsStringSync().contains(kCorpus), isTrue,
            reason: '${f.path} reasons about Quran text without reading the '
                'pinned corpus');
      }
    });
  });

  group('tawaf-between-corners — Quran text authority', () {
    test('its stored text is an exact code-point excerpt of KFGQPC 2:201', () {
      final stored = _entry(kBetween)['text']['ar'] as String;
      final official = _ayah(2, 201);
      expect(official.contains(stored), isTrue,
          reason: 'stored text must appear verbatim inside the pinned ayah');
      // And prove the check has teeth: one altered mark breaks containment.
      final mutated = stored.replaceFirst('ۡ', 'ْ');
      if (mutated != stored) {
        expect(official.contains(mutated), isFalse);
      }
    });

    test('it declares the KFGQPC authority fields', () {
      final e = _entry(kBetween);
      expect(e['textAuthority'], isNotEmpty);
      expect(e['quranRef'], isNotNull);
      expect(e['quranRef']['surah'], 2);
      expect(e['quranRef']['ayat'], [201]);
    });

    test('it is a location-specific recitable text', () {
      final m = _model(kBetween);
      expect(m.contentKind, SupplicationContentKind.specificText);
      expect(m.contentKind.isTiedToLocation, isTrue);
      expect(m.canPlayManually, isTrue);
      expect(m.zoneKey, 'mataf');
    });

    test('it is recorded passed on both axes, and stays unverified', () {
      final r = _reviews()[kBetween]!;
      expect(r['reviewStatus'], 'passed');
      expect(r['textReviewStatus'], 'passed');
      expect(r['reviewedPage'], 69);
      expect(r['quranTextAuthorityVerified'], isTrue);
      expect(r['printedContextNote'], isNotNull);
      expect(_entry(kBetween)['verificationStatus'], 'unverified');
    });

    test('the legitimate duplicate is preserved, not merged away', () {
      final a = _entry(kBetween)['text']['ar'];
      final b = _entry(kGeneral001)['text']['ar'];
      expect(a, b, reason: 'same canonical text — one set of audio bytes');
      // But they remain two records with different classifications.
      expect(_entry(kBetween)['contentKind'], 'specific_text');
      expect(_entry(kGeneral001)['contentKind'], 'general_dua');
      expect(
          _entry(kBetween)['zoneKey'], isNot(_entry(kGeneral001)['zoneKey']));
      expect(_entry(kBetween)['printedPage'],
          isNot(_entry(kGeneral001)['printedPage']));
    });
  });

  group('umrah-halq-shamil — embedded Quran inside ministry guidance', () {
    test('the record stays guidance and is playable by no path', () {
      final m = _model(kHalq);
      expect(m.contentKind, SupplicationContentKind.proceduralGuidance);
      expect(m.canPlayManually, isFalse);
      expect(m.isAutoPlayable, isFalse);
      expect(m.contentKind.isRecitable, isFalse);
    });

    test('embedding Quran does NOT make guidance recitable', () {
      final t = _entry(kHalq)['text']['ar'] as String;
      expect(t.contains('﴿'), isTrue,
          reason: 'the sentence really does quote inside ornate brackets');
      expect(_model(kHalq).canPlayManually, isFalse,
          reason: 'a quotation inside prose is not a text to recite');
    });

    test('no whole-record Quran authority is claimed for ministry prose', () {
      final e = _entry(kHalq);
      expect((e['textAuthority'] ?? '').toString(), isEmpty,
          reason: 'the sentence is the ministry writing, not revelation');
      expect(e['quranRef'], isNull);
      expect((e['textRiwayah'] ?? '').toString(), isEmpty);
      expect((e['textRasm'] ?? '').toString(), isEmpty);
    });

    test('the Quran citation is recorded as a structured reference', () {
      final refs = (_entry(kHalq)['sourceReferences'] as List)
          .cast<Map<String, dynamic>>();
      expect(refs, hasLength(1));
      expect(refs.first['type'], 'quran');
      expect(refs.first['referenceKind'], 'surah_ayah');
      expect(refs.first['citedBy'], 'moia_1446');
      expect(refs.first['citedOnPage'], 74);
      expect(refs.first['reference'], isNotEmpty);
    });

    test('the embedded quotation shares 48:27 word-for-word', () {
      // Reported precisely rather than asserted as identical: the ministry
      // sets the quotation in plain orthography (U+0652) where KFGQPC uses
      // the Uthmani sukun (U+06E1). Same words, different rasm convention —
      // canonically equivalent, NOT byte-identical. The ministry sentence is
      // preserved as printed; nothing is "corrected" toward the mushaf.
      final guid = _entry(kHalq)['text']['ar'] as String;
      final embedded = RegExp('﴿(.*?)﴾').firstMatch(guid)?.group(1) ?? '';
      expect(embedded, isNotEmpty);
      final official = _ayah(48, 27);
      expect(official.contains(embedded), isFalse,
          reason: 'documented: it is not a byte-identical excerpt');
      String skeleton(String s) => s
          .replaceAll(RegExp('[ً-ٰٟۖ-ۭـ ]'), '')
          .replaceAll('ٱ', 'ا')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      expect(skeleton(official).contains(skeleton(embedded)), isTrue,
          reason: 'the same words in the same order');
    });
  });

  group('return-hajar — completed, guidance, never playable', () {
    test('its transcription was confirmed unchanged against page 72', () {
      final r = _reviews()[kReturnHajar]!;
      expect(r['reviewStatus'], 'passed');
      expect(r['textReviewStatus'], 'passed');
      expect(r['reviewedPage'], 72);
      expect(r['transcriptionCorrected'], isFalse);
      expect(r.containsKey('pendingReason'), isFalse);
    });

    test('the stored text keeps the printed U+0670 and its punctuation', () {
      final t = _entry(kReturnHajar)['text']['ar'] as String;
      expect(t.contains('ٰ'), isTrue,
          reason: 'page 72 prints إلىٰ with the superscript alef');
      expect(t.contains(':'), isTrue, reason: 'colon after الأسود');
      expect(t.contains('،'), isTrue, reason: 'Arabic comma');
      expect(t.endsWith('.'), isTrue);
    });

    test('it stays guidance, unverified, and deployment-held', () {
      final m = _model(kReturnHajar);
      expect(m.contentKind, SupplicationContentKind.proceduralGuidance);
      expect(m.canPlayManually, isFalse);
      expect(m.isAutoPlayable, isFalse);
      expect(_entry(kReturnHajar)['verificationStatus'], 'unverified');
      final r = _reviews()[kReturnHajar]!;
      expect(r['deploymentBlocked'], isTrue);
      expect(r['excludedFromImport'], isTrue);
      expect(r['deploymentBlockLiftConditions']['liftedAt'], isNull);
      expect(
          r['deploymentBlockLiftConditions']['appAndWorkerReleased'], isFalse);
    });

    test('no playback path exists for it', () {
      expect(
          (_entry(kReturnHajar)['audioUrl'] ?? '').toString().trim(), isEmpty);
      final screen =
          File('lib/Screens/Piligram/Duas/duas_screen.dart').readAsStringSync();
      expect(screen.contains('if (!dua.canPlayManually) return;'), isTrue);
    });
  });

  group('citation-review states are explicit and internally consistent', () {
    test('reviewed_present requires at least one structured reference', () {
      final entries = {for (final e in _entries()) e['duaId'] as String: e};
      for (final r in _reviews().values) {
        if (r['sourceReferencesReviewStatus'] != 'reviewed_present') continue;
        final refs =
            (entries[r['recordId']]?['sourceReferences'] as List?) ?? const [];
        expect(refs, isNotEmpty,
            reason: '${r['recordId']} claims references it does not have');
      }
    });

    test('reviewed_none requires a reviewed page and an empty list', () {
      final entries = {for (final e in _entries()) e['duaId'] as String: e};
      for (final r in _reviews().values) {
        if (r['sourceReferencesReviewStatus'] != 'reviewed_none') continue;
        expect(r['reviewedPage'], isNotNull,
            reason: '${r['recordId']}: "none found" needs a page that was '
                'actually read');
        final refs =
            (entries[r['recordId']]?['sourceReferences'] as List?) ?? const [];
        expect(refs, isEmpty, reason: '${r['recordId']}');
      }
    });

    test('only the three allowed values ever appear', () {
      for (final r in _reviews().values) {
        final v = r['sourceReferencesReviewStatus'];
        if (v == null) continue;
        expect(v, anyOf('not_reviewed', 'reviewed_none', 'reviewed_present'),
            reason: '${r['recordId']}');
      }
    });

    test('the status was NOT mass-applied to the unreviewed 50', () {
      final reviews = _reviews();
      final withStatus = reviews.values
          .where((r) => r['sourceReferencesReviewStatus'] != null)
          .length;
      expect(withStatus, lessThan(reviews.length),
          reason: 'an absent status means not_reviewed, and most entries '
              'have not had their citations examined');
      // And nothing outside the ledger carries it: it is administrative.
      for (final e in _entries()) {
        expect(e.containsKey('sourceReferencesReviewStatus'), isFalse,
            reason: '${e['duaId']}: this belongs to review, not to content');
      }
    });

    test('an absent status is never proof that a page cites nothing', () {
      // The 50 unreviewed records all have empty sourceReferences. That
      // emptiness must not be readable as "reviewed and none found".
      final reviewed = _reviews().keys.toSet();
      final unreviewed =
          _entries().where((e) => !reviewed.contains(e['duaId'])).toList();
      expect(unreviewed, hasLength(49));
      for (final e in unreviewed) {
        expect(_reviews()[e['duaId']]?['sourceReferencesReviewStatus'], isNull);
      }
    });

    test('the status changes nothing about recitability', () {
      // safa-dhikr is reviewed_present, marwah-same reviewed_none; their
      // playability comes from contentKind and nothing else.
      expect(_model('moia-1446-safa-dhikr').canPlayManually, isTrue);
      expect(_model('moia-1446-marwah-same').canPlayManually, isFalse);
      expect(_model(kBetween).canPlayManually, isTrue);
      expect(_model(kHalq).canPlayManually, isFalse);
    });

    test('the administrative status never reaches the pilgrim', () {
      for (final path in [
        'lib/Screens/Piligram/Duas/duas_screen.dart',
        'lib/Screens/Piligram/Duas/widgets/content_kind_card.dart',
        'lib/Screens/Assistant/assistant_screen.dart',
        'lib/Screens/Piligram/Home/models/supplication_model.dart',
      ]) {
        expect(
            File(path)
                .readAsStringSync()
                .contains('sourceReferencesReviewStatus'),
            isFalse,
            reason: '$path must not surface a review-desk field');
      }
    });
  });

  group('the verbatim contract is proven, not asserted', () {
    VerifiedExcerpt parse(Map<String, dynamic> m) =>
        VerifiedExcerpt.listFrom([m]).single;

    test('the new flag is read, and defaults to false when absent', () {
      final e = parse({'documentId': 'd', 'text': 'x'});
      expect(e.isVerbatimFromStoredRecord, isFalse);
      expect(e.mayShowVerbatimLabel, isFalse);
    });

    test('a legacy unconditional isVerbatim is NOT trusted', () {
      final e = parse({'documentId': 'd', 'text': 'x', 'isVerbatim': true});
      expect(e.isVerbatimFromStoredRecord, isFalse,
          reason: 'every old proxy sent true unconditionally; honouring it '
              'would import a guarantee nobody computed');
      expect(e.mayShowVerbatimLabel, isFalse);
      // The excerpt still renders — only the claim is withheld.
      expect(e.text, 'x');
    });

    test('a proven flag on a recitable excerpt may show the label', () {
      final e = parse({
        'documentId': 'd',
        'text': 'x',
        'isVerbatimFromStoredRecord': true,
        'contentKind': 'specific_text',
      });
      expect(e.isVerbatimFromStoredRecord, isTrue);
      expect(e.mayShowVerbatimLabel, isTrue);
    });

    test('guidance and evidence never get the verbatim label', () {
      for (final kind in ['procedural_guidance', 'contextual_evidence']) {
        final e = parse({
          'documentId': 'd',
          'text': 'x',
          'isVerbatimFromStoredRecord': true,
          'contentKind': kind,
        });
        expect(e.isVerbatimFromStoredRecord, isTrue,
            reason: 'the store-to-wire fact is still true');
        expect(e.mayShowVerbatimLabel, isFalse,
            reason: '$kind must not be presented as a verbatim recitation');
      }
    });

    test('a non-boolean or absent value never reads as true', () {
      for (final v in [null, 'true', 1, {}, []]) {
        final e = parse({
          'documentId': 'd',
          'text': 'x',
          'isVerbatimFromStoredRecord': v,
        });
        expect(e.isVerbatimFromStoredRecord, isFalse, reason: '$v');
      }
    });

    test('the worker computes the flag rather than hardcoding it', () {
      final w = File('assistant-proxy/worker.js').readAsStringSync();
      expect(
          w.contains('isVerbatimFromStoredRecord: excerptText === doc.content'),
          isTrue);
      expect(w.contains('isVerbatim: true,'), isFalse,
          reason: 'the unconditional literal must be gone');
    });

    test('the label is gated in the UI on the computed value', () {
      final s = File('lib/Screens/Assistant/assistant_screen.dart')
          .readAsStringSync();
      expect(s.contains('excerpt.mayShowVerbatimLabel'), isTrue);
    });
  });

  group('nothing was verified', () {
    test('all 85 records remain unverified', () {
      final entries = _entries();
      expect(entries, hasLength(85));
      for (final e in entries) {
        expect(e['verificationStatus'], 'unverified', reason: '${e['duaId']}');
        expect(e['verifiedAt'], isNull);
        expect(e['verifiedBy'], isNull);
      }
      expect(_ledger()['summary']['verifiedRecords'], 0);
      expect(_ledger()['summary']['firestoreVerificationPerformed'], isFalse);
    });
  });
}
