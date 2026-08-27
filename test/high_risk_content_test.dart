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

    test('the page-74 citations that are this record\'s are structured refs',
        () {
      // Was three. Page 74 was later re-rendered from the source file's own
      // pixels, and footnote (1) — «صحيح البخاري» — turned out to be anchored
      // on the paragraph before this one, ending at «قَلَّدَهَا». It was
      // removed rather than renumbered; see halq_shamil_citation_test.dart.
      final refs = (_entry(kHalq)['sourceReferences'] as List)
          .cast<Map<String, dynamic>>();
      expect(refs, hasLength(2));
      expect(refs.any((r) => (r['collection'] as String).contains('البخاري')),
          isFalse,
          reason: 'footnote (1) belongs to a paragraph this record lacks');
      for (final r in refs) {
        expect(r['citedBy'], 'moia_1446',
            reason: 'these are what the MINISTRY cited, not our own research');
        expect(r['citedOnPage'], 74);
        expect((r['reference'] as String).trim(), isNotEmpty);
      }
      final byCollection = {
        for (final r in refs) r['collection'] as String: r,
      };
      expect(byCollection['القرآن الكريم']!['type'], 'quran');
      expect(byCollection['القرآن الكريم']!['referenceKind'], 'surah_ayah');
      expect(byCollection.containsKey('صحيح البخاري'), isFalse);
      expect(byCollection['صحيح مسلم']!['type'], 'hadith');
      expect(byCollection['صحيح مسلم']!['reference'], '1305');
      expect(byCollection['صحيح مسلم']!['referenceKind'], 'hadith_number');
    });

    test('the hadith numbers live in the citations, not in the prose', () {
      // Page 74 prints them as citations for the sentence; the sentence
      // itself does not contain them. Splicing them into text.ar would put
      // administrative apparatus into ministry prose.
      final t = _entry(kHalq)['text']['ar'] as String;
      expect(t.contains('1540'), isFalse);
      expect(t.contains('1305'), isFalse);
    });

    test('the ministry sentence is preserved exactly as printed', () {
      // Page 74 sets رُءُوسَكُمْ with the ORDINARY sukun. It is never
      // rewritten toward the mushaf's Uthmani sukun: this record is the
      // ministry writing, and correcting its orthography would be editing
      // a source we only quote.
      final guid = _entry(kHalq)['text']['ar'] as String;
      final embedded = RegExp('﴿(.*?)﴾').firstMatch(guid)!.group(1)!;
      expect(embedded.contains('ْ'), isTrue,
          reason: 'plain sukun U+0652, as the ministry printed it');
      expect(embedded.contains('ۡ'), isFalse,
          reason: 'the Uthmani sukun must not be substituted in');
    });

    test('NFC and NFD leave the two excerpts unequal', () {
      // The retired status claimed Unicode canonical equivalence. It does
      // not hold, and the real picture has TWO layers worth stating exactly:
      //
      //   1. Mark ORDER. The ministry writes kasra-then-shadda where KFGQPC
      //      writes shadda-then-kasra. Those differ by canonical combining
      //      class, so NFC and NFD DO merge them — that part really is
      //      canonical equivalence.
      //   2. The SUKUN. Ordinary U+0652 vs Quranic U+06E1 are distinct
      //      characters. No normalisation form merges them, and this is the
      //      single residual difference after normalising.
      //
      // So "canonically equivalent" was wrong about the pair as a whole:
      // normalisation gets the two strings close but never equal. The
      // accurate description is the same lexical text under two rasm
      // conventions.
      const plain = '\u0652'; // ARABIC SUKUN
      const uthmani = '\u06E1'; // ARABIC SMALL HIGH DOTLESS HEAD OF KHAH

      final guid = _entry(kHalq)['text']['ar'] as String;
      final embedded = RegExp('﴿(.*?)﴾').firstMatch(guid)!.group(1)!;
      final official = _ayah(48, 27);

      expect(embedded.contains(plain), isTrue);
      expect(embedded.contains(uthmani), isFalse);
      expect(official.contains(uthmani), isTrue);

      // The characters themselves are not equal, and Dart's own comparison
      // is code-point equality — the property normalisation would have to
      // change, and does not.
      expect(plain == uthmani, isFalse);
      expect(plain.runes.single, isNot(uthmani.runes.single));

      // The quotation is not a code-point excerpt of the ayah...
      expect(official.contains(embedded), isFalse);
      // ...and swapping ONLY the sukun is still not enough on the raw
      // strings, because the mark ordering also differs.
      expect(official.contains(embedded.replaceAll(plain, uthmani)), isFalse);
    });

    test('the ONE residual difference after normalising is the sukun', () {
      // Pins the finding above: once mark order is normalised away, the
      // quotation differs from the mushaf by exactly one character class.
      const plain = '\u0652';
      const uthmani = '\u06E1';
      final guid = _entry(kHalq)['text']['ar'] as String;
      final embedded = RegExp('﴿(.*?)﴾').firstMatch(guid)!.group(1)!;
      final official = _ayah(48, 27);

      // Dart has no NFC in the core library, so the mark-order difference is
      // neutralised directly: sort each combining run by code point. That is
      // weaker than NFC in general but sufficient here, and it isolates the
      // sukun as the only remaining difference.
      String orderMarks(String s) {
        bool mark(int c) =>
            (c >= 0x064B && c <= 0x065F) || c == 0x0670 || c == 0x0653;
        final out = <int>[];
        final run = <int>[];
        void flush() {
          run.sort();
          out.addAll(run);
          run.clear();
        }

        for (final c in s.runes) {
          if (mark(c)) {
            run.add(c);
          } else {
            flush();
            out.add(c);
          }
        }
        flush();
        return String.fromCharCodes(out);
      }

      // Still unequal with the sukun left alone...
      expect(orderMarks(official).contains(orderMarks(embedded)), isFalse);
      // ...and equal the moment the rasm convention is reconciled.
      expect(
          orderMarks(official)
              .contains(orderMarks(embedded).replaceAll(plain, uthmani)),
          isTrue,
          reason: 'same words, same order — one rasm code point apart');
    });

    test('the recorded status uses the precise term', () {
      final r = _reviews()[kHalq]!;
      expect(r['embeddedQuranEquivalence'], 'same_lexical_text_different_rasm');
      // The retired value claimed a Unicode property that does not hold.
      expect(r['embeddedQuranEquivalence'],
          isNot('canonically_equivalent_not_byte_identical'));
      expect(r['embeddedQuranEquivalenceNote'], isNotNull);
    });

    test('the page-74 review is recorded, with its evidence stated', () {
      final r = _reviews()[kHalq]!;
      expect(r['reviewStatus'], 'passed');
      expect(r['textReviewStatus'], 'passed');
      expect(r['reviewedPage'], 74);
      expect(r['transcriptionCorrected'], isFalse);
      expect(r['sourceReferencesReviewStatus'], 'reviewed_present');
      expect(r['embeddedQuranEquivalence'], 'same_lexical_text_different_rasm');
      // The human reviewer looked first, from the full 136-page source, at a
      // time when the uploaded page files were thought to stop at 73. Page 74
      // turned out to be in the selected-pages upload after all, so the agent
      // did later render it — and that second look is what caught the
      // misattributed Bukhari footnote. The ledger records both, so neither
      // pass is mistaken for the other.
      expect(r['agentRenderedPage'], isTrue);
      expect(r['reviewedFromFullSourcePdf'], isTrue);
      expect(_entry(kHalq)['verificationStatus'], 'unverified');
    });

    test('the embedded quotation shares 48:27 word-for-word', () {
      // Reported precisely rather than asserted as identical: the ministry
      // sets the quotation in plain orthography (U+0652) where KFGQPC uses
      // the Uthmani sukun (U+06E1).
      //
      // The accurate description is SAME LEXICAL TEXT, DIFFERENT RASM: the
      // same words in the same order, written under two script conventions.
      // It is NOT Unicode canonical equivalence — that would mean the two
      // strings normalise to one code-point sequence, and these are distinct
      // characters that no normalisation form merges (see the NFC/NFD test
      // below). The ministry sentence is preserved as printed; nothing is
      // "corrected" toward the mushaf.
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

    test('the status was NOT mass-applied', () {
      // This test used to assert the complement — that some reviews still
      // carried no status — to stop the field being stamped across records
      // nobody had examined. The takhrij round read the last ten printed
      // pages, so that remainder is now empty and the assertion would only
      // pass vacuously. What replaces it is the thing the old test was
      // really protecting: a status that was applied per record discriminates
      // between records, so both values must actually occur, and neither may
      // account for the whole ledger.
      final reviews = _reviews();
      final present = reviews.values
          .where((r) => r['sourceReferencesReviewStatus'] == 'reviewed_present')
          .length;
      final none = reviews.values
          .where((r) => r['sourceReferencesReviewStatus'] == 'reviewed_none')
          .length;
      expect(present, greaterThan(0));
      expect(none, greaterThan(0));
      expect(present + none, reviews.length,
          reason: 'every review must carry one of the two resolved values');
      // And nothing outside the ledger carries it: it is administrative.
      for (final e in _entries()) {
        expect(e.containsKey('sourceReferencesReviewStatus'), isFalse,
            reason: '${e['duaId']}: this belongs to review, not to content');
      }
    });

    test('every record now carries a citation status, and it was earned', () {
      // This test used to guard the opposite state: while records were still
      // unreviewed, an empty sourceReferences list must never read as
      // "reviewed and none found", so unreviewed records had to carry no
      // citation status at all. It asserted the remainder was non-empty and
      // said in its own reason that when it emptied it should be retired
      // deliberately rather than pass vacuously. Page 64 emptied it.
      //
      // Retired as instructed, and replaced by the invariant that now holds:
      // every record is reviewed, every one carries an explicit status, and
      // «reviewed_none» is only ever claimed where the pack really holds no
      // reference. The distinction the old test protected — silence is not a
      // finding — is what the second half still enforces.
      final reviewed = _reviews();
      final entries = _entries();
      expect(entries.where((e) => !reviewed.containsKey(e['duaId'])), isEmpty,
          reason: 'the batch flow is finished; nothing is unreviewed');

      // 31 reviews predated the field and were left visibly unset rather than
      // backfilled from nothing. The takhrij round earned them: the ten
      // remaining printed pages were read for footnote rules, marker
      // positions and their anchors. So the remainder is now empty — and the
      // ledger summary has to agree, computed rather than typed.
      final withoutStatus = entries
          .map((e) => e['duaId'] as String)
          .where((id) => reviewed[id]?['sourceReferencesReviewStatus'] == null)
          .toList();
      final sr = ((_ledger()['summary']
              as Map<String, dynamic>)['sourceReferencesReviewed'])
          as Map<String, dynamic>;
      expect(withoutStatus, isEmpty,
          reason: 'every record must carry a resolved citation status');
      expect(sr['not_reviewed_count'], 0);
      expect(withoutStatus, hasLength(sr['not_reviewed_count']),
          reason: 'the summary and the reviews disagree about how many '
              'reviews still lack the citation-status field');
      // The two summary lists are derived, not hand-maintained.
      for (final status in const ['reviewed_present', 'reviewed_none']) {
        final actual = entries
            .map((e) => e['duaId'] as String)
            .where(
                (id) => reviewed[id]?['sourceReferencesReviewStatus'] == status)
            .toList()
          ..sort();
        expect(List<String>.from(sr[status] as List), actual,
            reason: 'summary.$status disagrees with the reviews array');
      }
      expect(
          (sr['reviewed_present'] as List).length +
              (sr['reviewed_none'] as List).length +
              (sr['not_reviewed_count'] as int),
          entries.length);

      // Where a status IS claimed, it must be one of the two values and must
      // match what the pack actually holds. This is the half that carries
      // the original point: silence is not a finding, and a finding may not
      // contradict the record it describes.
      for (final e in entries) {
        final id = e['duaId'] as String;
        final status = reviewed[id]?['sourceReferencesReviewStatus'];
        if (status == null) continue;
        expect(const ['reviewed_none', 'reviewed_present'], contains(status),
            reason: '$id has an unknown status: $status');
        final refs = e['sourceReferences'] as List;
        if (status == 'reviewed_none') {
          expect(refs, isEmpty,
              reason: '$id says the page cites nothing yet holds references');
        } else {
          expect(refs, isNotEmpty,
              reason: '$id says the page cites something yet holds none');
        }
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

  group('isVerbatimFromStoredRecord means one thing only', () {
    test('it is equality with the stored record, nothing more', () {
      final w = File('assistant-proxy/worker.js').readAsStringSync();
      expect(
          w.contains('isVerbatimFromStoredRecord: excerptText === doc.content'),
          isTrue,
          reason: 'the only comparison is shipped-string vs stored-string');
      // No Quran corpus, authority field, or external source is consulted
      // anywhere in the excerpt builder.
      final withComments = w.substring(
          w.indexOf('function buildVerifiedExcerpts'),
          w.indexOf('function canonicalizeCitations'));
      // Comments are stripped first: the rule is about what the CODE reads,
      // and the doc comment above the flag legitimately names the fields it
      // must not consult in order to say that it does not consult them.
      final builder = withComments
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      for (final forbidden in [
        'hafsData',
        'kfgqpc',
        'quranRef',
        'textAuthority'
      ]) {
        expect(builder.contains(forbidden), isFalse,
            reason: 'the flag must not consult $forbidden');
      }
    });

    test('a true flag on guidance never yields a Quran-verbatim label', () {
      // The halq record is guidance that EMBEDS Quran. Even when the proxy
      // proves the string is the stored one, the card must not present it as
      // a verbatim scriptural text.
      final e = VerifiedExcerpt.listFrom([
        {
          'documentId': kHalq,
          'text': _entry(kHalq)['text']['ar'],
          'contentKind': 'procedural_guidance',
          'isVerbatimFromStoredRecord': true,
        }
      ]).single;
      expect(e.isVerbatimFromStoredRecord, isTrue,
          reason: 'store-to-wire fidelity really does hold');
      expect(e.isRecitable, isFalse);
      expect(e.mayShowVerbatimLabel, isFalse,
          reason: 'guidance never carries a verbatim recitation label, '
              'however faithfully it was transported');
    });

    test('the flag does not certify the embedded Quran against KFGQPC', () {
      // Proof by counter-example: the stored halq sentence is transported
      // perfectly AND its embedded quotation is NOT a KFGQPC excerpt. If the
      // flag implied scriptural identity, these two could not both hold.
      final guid = _entry(kHalq)['text']['ar'] as String;
      final embedded = RegExp('﴿(.*?)﴾').firstMatch(guid)!.group(1)!;
      expect(_ayah(48, 27).contains(embedded), isFalse);
      final e = VerifiedExcerpt.listFrom([
        {
          'documentId': kHalq,
          'text': guid,
          'contentKind': 'procedural_guidance',
          'isVerbatimFromStoredRecord': true,
        }
      ]).single;
      expect(e.isVerbatimFromStoredRecord, isTrue);
    });
  });

  group('audio scope excludes guidance', () {
    test('the halq record is never counted toward an audio file', () {
      const recitable = {
        'specific_text',
        'general_dua',
        'general_dhikr',
        'mosque_entry',
      };
      final entries = _entries();
      final rec =
          entries.where((e) => recitable.contains(e['contentKind'])).toList();
      expect(rec.map((e) => e['duaId']), isNot(contains(kHalq)));
      expect(rec.map((e) => e['duaId']), isNot(contains(kReturnHajar)));
      // 59, down from 60: the page-64 mosque-entry hadith is evidence for the
      // wording above it on the page, not a wording to recite, so it is no
      // longer counted toward an audio file either.
      expect(rec.map((e) => e['duaId']),
          isNot(contains('moia-mukhtasar-1446-umrah-entering-masjid-hadith')));
      expect(rec, hasLength(59));
      final uniqueTexts =
          rec.map((e) => (e['text']['ar'] as String).trim()).toSet();
      expect(uniqueTexts, hasLength(58),
          reason: 'the one legitimate duplicate shares a single audio file');
      // And no guidance record carries an audio URL that would bypass this.
      for (final e in entries) {
        if (recitable.contains(e['contentKind'])) continue;
        expect((e['audioUrl'] ?? '').toString().trim(), isEmpty,
            reason: '${e['duaId']}: guidance must own no audio');
      }
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
