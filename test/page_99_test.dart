// Printed page 99 — six duas, none of which needed a correction.
//
// The page compared clean: all six match the print letter for letter, raw and
// under NFC, at identical length. Nothing in text.ar changed, and these tests
// exist to keep it that way — "nothing changed" is the state most easily lost
// to a well-meaning later edit.
//
// general-050 is the reason this page mattered structurally. Its printed unit
// STARTS on page 99 and does not close there: the last line ends at
// «اللَّهُمَّ إِنِّي أَسْأَلُكَ» with no closing paren, and the rest sits at the
// top of page 100, finishing at «قَضَيْتَهُ لِي خَيْرًا)» before general-039
// begins. So printedPage stays 99 (where it starts) and reviewedPages records
// both, the same shape used for tawaf-direction.
//
// That also explains something that looked wrong for a long time: -050 is
// stored between -038 and -039 rather than after -049, and the pack order is
// right. And it explains why counting «من» occurrences per page never lined
// up — three of -050's sit on page 100, which made page 99 look three short
// and page 100 three long at the same time.
//
// -050 carries two printed full stops inside its own parentheses. They are
// sentence punctuation, not record boundaries, and the record is not split at
// them — the same call already made for -024 on page 97.
//
// One note on -037, recorded because the process matters: the agent first
// read «عَفُوٌّ» with a fatha and the stored text has «عُفُوٌّ» with a damma.
// Isolating the mark against two controls from the same line — «تُحِبُّ»
// (damma) and «كَرِيمٌ» (fatha) — showed a damma, so the record was right and
// the reading was wrong. No correction was made.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';

const String k050 = 'moia-mukhtasar-1446-general-050';

const List<String> kPage99 = [
  'moia-mukhtasar-1446-general-034',
  'moia-mukhtasar-1446-general-035',
  'moia-mukhtasar-1446-general-036',
  'moia-mukhtasar-1446-general-037',
  'moia-mukhtasar-1446-general-038',
  k050,
];

/// sha256(text.ar + U+0000 + text.en) of the reviewed text.
const Map<String, String> kHashes = {
  'moia-mukhtasar-1446-general-034': 'b677ae9f3fcbd451',
  'moia-mukhtasar-1446-general-035': '39b66ee11c5db88b',
  'moia-mukhtasar-1446-general-036': 'de7dc187effd00af',
  'moia-mukhtasar-1446-general-037': 'f43926809e4a2767',
  'moia-mukhtasar-1446-general-038': 'ce575dd2aede6473',
  k050: 'b19bcd1994d85bce',
};

const Map<String, int> kLengths = {
  'moia-mukhtasar-1446-general-034': 407,
  'moia-mukhtasar-1446-general-035': 67,
  'moia-mukhtasar-1446-general-036': 55,
  'moia-mukhtasar-1446-general-037': 67,
  'moia-mukhtasar-1446-general-038': 286,
  k050: 596,
};

/// The pinned KFGQPC Hafs corpus — the only authority for Quran text here.
const String kCorpus = 'third_party/kfgqpc/hafsData_v2-0.json';

String _skeleton(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if ((r >= 0x064B && r <= 0x0652) ||
        r == 0x0670 ||
        (r >= 0x06D6 && r <= 0x06ED)) {
      continue;
    }
    var c = r;
    if (c == 0x0671 || c == 0x0622 || c == 0x0623 || c == 0x0625) c = 0x0627;
    b.writeCharCode(c);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<Map<String, dynamic>> _entries() => ((jsonDecode(
      File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
    ) as Map<String, dynamic>)['entries'] as List)
        .cast<Map<String, dynamic>>();

Map<String, dynamic> _entry(String id) =>
    _entries().firstWhere((e) => e['duaId'] == id);

SupplicationModel _model(String id) => SupplicationModel.fromJson(_entry(id));

String _ar(String id) => _entry(id)['text']['ar'] as String;

Map<String, Map<String, dynamic>> _reviews() {
  final l = jsonDecode(
    File('review/human_review_ledger.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return {
    for (final r in (l['reviews'] as List).cast<Map<String, dynamic>>())
      r['recordId'] as String: r
  };
}

String _hash(String id) {
  final t = _entry(id)['text'] as Map<String, dynamic>;
  return sha256.convert(utf8.encode('${t['ar']}\u0000${t['en']}')).toString();
}

void main() {
  group('all six are recorded, on page 99, with nothing corrected', () {
    test('each has a passed review naming page 99', () {
      final r = _reviews();
      for (final id in kPage99) {
        expect(r[id], isNotNull, reason: id);
        expect(r[id]!['reviewStatus'], 'passed', reason: id);
        expect(r[id]!['textReviewStatus'], 'passed', reason: id);
        expect(r[id]!['reviewedPage'], 99, reason: id);
        expect(r[id]!['transcriptionCorrected'], isFalse,
            reason: '$id needed no correction');
        expect(r[id]!['deploymentBlocked'], isFalse, reason: id);
        expect(r[id]!['excludedFromImport'], isFalse, reason: id);
      }
    });

    test('the page prints no takhrij, and that was checked not assumed', () {
      final r = _reviews();
      for (final id in kPage99) {
        expect(r[id]!['sourceReferencesReviewStatus'], 'reviewed_none',
            reason: id);
        expect((_entry(id)['sourceReferences'] as List), isEmpty, reason: id);
        expect(_entry(id)['quranRef'], isNull, reason: id);
      }
    });

    test('each text still hashes to what was compared, at the same length', () {
      for (final id in kPage99) {
        expect(_hash(id).startsWith(kHashes[id]!), isTrue, reason: id);
        expect(_ar(id).length, kLengths[id], reason: id);
        expect(
            (_reviews()[id]!['reviewedTextHash'] as String)
                .startsWith(kHashes[id]!),
            isTrue,
            reason: id);
      }
    });

    test('no printing apparatus leaked into any of them', () {
      for (final id in kPage99) {
        final t = _ar(id);
        expect(t.contains('('), isFalse, reason: id);
        expect(t.contains(')'), isFalse, reason: id);
        expect(t.trim().endsWith('.'), isFalse, reason: id);
        expect(t, equals(t.trim()), reason: id);
      }
    });
  });

  group('general-050 spans two printed pages and is not split', () {
    test('printedPage records where it starts; reviewedPages records both', () {
      final r = _reviews()[k050]!;
      expect(_entry(k050)['printedPage'], 99, reason: 'the unit begins on 99');
      expect(r['reviewedPages'], [99, 100],
          reason: 'the unit closes at the top of 100, so both were compared');
      expect(r['reviewedPage'], 99,
          reason: 'reviewedPage must stay the first of reviewedPages');
    });

    test('it is the only page-99 record spanning pages', () {
      final r = _reviews();
      for (final id in kPage99.where((e) => e != k050)) {
        expect(r[id]!.containsKey('reviewedPages'), isFalse, reason: id);
      }
    });

    test('its two internal full stops did not become record boundaries', () {
      final t = _ar(k050);
      expect('.'.allMatches(t).length, 2);
      expect(t.contains('وَمَا لَمْ أَعْلَمْ. اللَّهُمَّ'), isTrue);
      expect(t.contains('عَبْدُكَ وَنَبِيُّكَ. اللَّهُمَّ'), isTrue);
      expect(t.endsWith('.'), isFalse,
          reason: 'the closing stop is apparatus and stays out');
    });

    test('no other record is a split-off piece of it', () {
      final pieces = _ar(k050).split('. ').map((s) => s.trim()).toList();
      expect(pieces, hasLength(3));
      for (final other in _entries().where((e) => e['duaId'] != k050)) {
        for (final p in pieces) {
          expect((other['text']['ar'] as String).trim() == p, isFalse,
              reason: '${other['duaId']} must not duplicate a piece of -050');
        }
      }
    });

    test('the tail compared on page 100 is really in the stored text', () {
      // If a future edit truncated -050 back to what page 99 alone shows,
      // reviewedPages would be claiming a comparison that no longer applies.
      expect(_ar(k050).contains('وَأَعُوذُ بِكَ مِنَ النَّارِ'), isTrue);
      expect(_ar(k050).endsWith('قَضَيْتَهُ لِي خَيْرًا'), isTrue);
    });

    test('its pack position really is out of sequence, and harmlessly so', () {
      // Worth pinning because it was misread twice. -050 does NOT sit between
      // -038 and -039: it is appended near the end of the pack, after the
      // page-74 records and before the page-65 ones. So the pack array is not
      // in printed order at this point — an artefact of when the record was
      // added, not a claim about the book. What matters for review is the
      // page metadata, asserted above, and that is correct.
      final ids = _entries().map((e) => e['duaId'] as String).toList();
      final i = ids.indexOf(k050);
      expect(i, greaterThan(ids.indexOf('moia-mukhtasar-1446-general-049')),
          reason: '-050 is appended late, not filed after -038');
      expect(i, greaterThan(ids.indexOf('moia-mukhtasar-1446-general-039')));
      // Its neighbours in the array belong to entirely different pages, which
      // is the clearest statement that array order carries no meaning here.
      expect(_entry(ids[i - 1])['printedPage'], isNot(99));
      expect(_entry(ids[i + 1])['printedPage'], isNot(99));
    });
  });

  group('-037 keeps the damma the page prints', () {
    test('«عُفُوٌّ» has a damma on the ain, not a fatha', () {
      // The agent misread this one; the record was right. Pinned so a future
      // pass does not "fix" the record toward the wrong reading.
      final t = _ar('moia-mukhtasar-1446-general-037');
      expect(t.contains('عُفُوٌّ'), isTrue);
      expect(t.contains('عَفُوٌّ'), isFalse);
    });
  });

  group('the dagger alefs on this page survive', () {
    test('«عَلَىٰ» and «إِلَىٰ» keep U+0670', () {
      expect(_ar('moia-mukhtasar-1446-general-035').contains('عَلَىٰ'), isTrue);
      expect(_ar('moia-mukhtasar-1446-general-036').contains('عَلَىٰ'), isTrue);
      expect(_ar('moia-mukhtasar-1446-general-038').contains('إِلَىٰ'), isTrue);
    });
  });

  group('none of the six quotes the Quran', () {
    test('checked against the pinned KFGQPC corpus, not assumed', () {
      final corpus = (jsonDecode(File(kCorpus).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      expect(corpus.length, 6236);
      final hay =
          corpus.map((a) => _skeleton(a['aya_text'] as String)).join(' | ');
      // Linear in the record's length: if no 25-character window of the
      // record appears in the Mushaf, then no longer run can either, since
      // every longer run contains a 25-character window. Scanning downward
      // from the full length instead would be quadratic, and -050 is 596
      // characters — that version took minutes.
      const window = 25;
      for (final id in kPage99) {
        final s = _skeleton(_ar(id));
        String? hit;
        for (var i = 0; i + window <= s.length; i++) {
          final w = s.substring(i, i + window);
          if (hay.contains(w)) {
            hit = w;
            break;
          }
        }
        expect(hit, isNull,
            reason: '$id shares «$hit» with the Mushaf; a real quotation '
                'needs a quranRef and the Quran-text authority checks');
      }
    });
  });

  group('recording the page changed nothing about deployment', () {
    test('all six stay unverified general duas', () {
      for (final id in kPage99) {
        expect(_entry(id)['verificationStatus'], 'unverified', reason: id);
        expect(_entry(id)['contentHash'], isNull, reason: id);
        expect(_model(id).contentKind, SupplicationContentKind.generalDua,
            reason: id);
      }
    });

    test('the pack is still 85 unverified records', () {
      final all = _entries();
      expect(all.length, 85);
      expect(all.every((e) => e['verificationStatus'] == 'unverified'), isTrue);
    });
  });
}
