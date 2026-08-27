// Printed page 101 — six duas, none of which needed a correction.
//
// All six match the print letter for letter, raw and under NFC, at identical
// length. Nothing in text.ar changed.
//
// Page structure: 16 text lines under the running title and the «١٠١» number
// box. -043 (3 lines), -044 (6), -045 (1), -046 (2), -047 (3), then -048
// opens on line 16 and does NOT close there. Its unit finishes at the top of
// page 102, at «تَبَارَكْتَ رَبَّنَا وَتَعَالَيْتَ)». So -048 is recorded as one
// unit spanning two pages: printedPage stays 101 (where it opens) and
// reviewedPages records both — the same shape as -050 and tawaf-direction.
//
// Page 102 does carry a real footnote rule. It is not this record's: the end
// of -048's closing line holds nothing after «وَتَعَالَيْتَ)» but the full
// stop — no raised reference numeral — and page 101 has no footnote at all,
// so nothing can be anchored at the unit's opening either.
//
// About «شَرَّمَا قَضَيْتَ» in -048: the ministry sets it with no space
// between «شَرَّ» and «مَا», and the stored text reproduces that. Deliberately
// NOT pinned by a test — a future reviewer may decide differently, and
// reviewedTextHash already protects the text as it stands. The recitation
// note lives in docs/AUDIO_INVENTORY.md, since a voice engine must say two
// words.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';

const String k043 = 'moia-mukhtasar-1446-general-043';
const String k044 = 'moia-mukhtasar-1446-general-044';
const String k045 = 'moia-mukhtasar-1446-general-045';
const String k046 = 'moia-mukhtasar-1446-general-046';
const String k047 = 'moia-mukhtasar-1446-general-047';
const String k048 = 'moia-mukhtasar-1446-general-048';

const List<String> kPage101 = [k043, k044, k045, k046, k047, k048];

/// sha256(text.ar + U+0000 + text.en) of the reviewed text.
const Map<String, String> kHashes = {
  k043: '267fc5ff1d522ec8',
  k044: 'e51d08ad972ab262',
  k045: 'f5cbcaecc18eaf60',
  k046: '9693fc697abb160e',
  k047: 'f8ad639bdf7f114d',
  k048: '71e9b492d1dd7a28',
};

const Map<String, int> kLengths = {
  k043: 257,
  k044: 500,
  k045: 69,
  k046: 149,
  k047: 196,
  k048: 232,
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

List<Map<String, dynamic>> _rawReviews() => ((jsonDecode(
      File('review/human_review_ledger.json').readAsStringSync(),
    ) as Map<String, dynamic>)['reviews'] as List)
        .cast<Map<String, dynamic>>();

Map<String, Map<String, dynamic>> _reviews() =>
    {for (final r in _rawReviews()) r['recordId'] as String: r};

String _hash(String id) {
  final t = _entry(id)['text'] as Map<String, dynamic>;
  return sha256.convert(utf8.encode('${t['ar']}\u0000${t['en']}')).toString();
}

void main() {
  group('all six are recorded once, on page 101, with nothing corrected', () {
    test('each appears exactly once in the ledger', () {
      final all = _rawReviews();
      for (final id in kPage101) {
        expect(all.where((r) => r['recordId'] == id).length, 1, reason: id);
      }
      expect(all.map((r) => r['recordId']).toSet().length, all.length,
          reason: 'no record may be reviewed twice anywhere in the ledger');
    });

    test('each has a passed review naming page 101', () {
      final r = _reviews();
      for (final id in kPage101) {
        expect(r[id], isNotNull, reason: id);
        expect(r[id]!['reviewStatus'], 'passed', reason: id);
        expect(r[id]!['textReviewStatus'], 'passed', reason: id);
        expect(r[id]!['reviewedPage'], 101, reason: id);
        expect(r[id]!['transcriptionCorrected'], isFalse,
            reason: '$id needed no correction');
        expect(r[id]!['deploymentBlocked'], isFalse, reason: id);
        expect(r[id]!['excludedFromImport'], isFalse, reason: id);
        expect(_entry(id)['printedPage'], 101, reason: id);
      }
    });

    test('each text still hashes to what was compared, at the same length', () {
      for (final id in kPage101) {
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
      for (final id in kPage101) {
        final t = _ar(id);
        expect(t.contains('('), isFalse, reason: id);
        expect(t.contains(')'), isFalse, reason: id);
        expect(t.trim().endsWith('.'), isFalse, reason: id);
        expect(t, equals(t.trim()), reason: id);
      }
    });

    test('-043 keeps its printed internal full stop and stays one record', () {
      final t = _ar(k043);
      expect('.'.allMatches(t).length, 1);
      expect(t.contains('وَبِكَ خَاصَمْتُ. اللَّهُمَّ إِنِّي'), isTrue);
      final halves = t.split('. ').map((s) => s.trim()).toList();
      expect(halves, hasLength(2));
      for (final other in _entries().where((e) => e['duaId'] != k043)) {
        for (final h in halves) {
          expect((other['text']['ar'] as String).trim() == h, isFalse,
              reason: '${other['duaId']} must not duplicate a half of -043');
        }
      }
    });
  });

  group('none of the six carries a takhrij', () {
    test('the ledger says reviewed_none and the pack agrees', () {
      final r = _reviews();
      for (final id in kPage101) {
        expect(r[id]!['sourceReferencesReviewStatus'], 'reviewed_none',
            reason: id);
        expect((_entry(id)['sourceReferences'] as List), isEmpty, reason: id);
        expect(_entry(id)['quranRef'], isNull, reason: id);
      }
    });

    test('-048 records why page 102\'s footnote is not its own', () {
      // Page 102 has a real footnote rule. The note must say, in the record
      // that touches that page, that it was checked and is unrelated —
      // otherwise a later reader sees "footnote on the page" and doubts the
      // reviewed_none.
      final n = _reviews()[k048]!['sourceReferencesNote'] as String;
      expect(n.contains('102'), isTrue);
      expect(n.contains('غير مرتبطة'), isTrue);
    });

    test('no 25-character window matches the pinned KFGQPC corpus', () {
      // What this check is: a CANDIDATE detector, within its own limits. A
      // clean run means no shared 25-character window in the vowel-stripped
      // skeleton — not that the text is non-Quranic, and not that it came
      // from anywhere in particular. It sees nothing shorter than the window
      // and nothing across a difference of rasm or orthography. Whether a
      // record quotes the Quran is settled by the full comparison with the
      // printed page and by what the ministry's own layout says the unit is.
      final corpus = (jsonDecode(File(kCorpus).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      expect(corpus.length, 6236);
      final hay =
          corpus.map((a) => _skeleton(a['aya_text'] as String)).join(' | ');
      const window = 25;
      for (final id in kPage101) {
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

  group('general-048 is one unit spanning two printed pages', () {
    test('printedPage records where it opens; reviewedPages records both', () {
      final r = _reviews()[k048]!;
      expect(_entry(k048)['printedPage'], 101,
          reason: 'the unit begins on 101');
      expect(r['reviewedPages'], [101, 102],
          reason: 'it closes at the top of 102, so both were compared');
      expect(r['reviewedPage'], 101,
          reason: 'reviewedPage must stay the first of reviewedPages');
    });

    test('-047 no longer claims -048\'s title and page range', () {
      // The pack shipped -047 with -048's sourceSection copied verbatim
      // («دعاء القنوت المأثور — صفحتا 101-102»), from the original
      // transcription. The print settles it: -047 is a separate unit on
      // lines 13-15 of page 101, closing there at «الدَّجَّالِ)», and the
      // qunut is -048. Metadata only; the text was never affected.
      final s = _entry(k047)['sourceSection'] as String;
      expect(s.endsWith('صفحة 101'), isTrue, reason: s);
      expect(s.contains('القنوت'), isFalse,
          reason: '-047 is not the qunut dua');
      expect(_reviews()[k047]!.containsKey('reviewedPages'), isFalse);
      // -048 keeps the qunut title, and it is the only record with it.
      final qunut = _entries()
          .where((e) => (e['sourceSection'] as String).contains('القنوت'))
          .map((e) => e['duaId'])
          .toList();
      expect(qunut, [k048]);
    });

    test('the pack\'s own sourceSection names both pages', () {
      // It said «صفحة 101» until this batch. The ledger's own rule is that
      // reviewedPages must equal the pages the record itself claims, so the
      // stale sourceSection had to be corrected — otherwise the only way to
      // satisfy the rule would have been to log the review as single-page,
      // understating it. Metadata only: text.ar, text.en and the reviewed
      // hash are untouched.
      final s = _entry(k048)['sourceSection'] as String;
      expect(s.contains('صفحتا 101-102'), isTrue, reason: s);
      expect(s.endsWith('صفحة 101'), isFalse);
    });

    test('it is the only page-101 record spanning pages', () {
      final r = _reviews();
      for (final id in kPage101.where((e) => e != k048)) {
        expect(r[id]!.containsKey('reviewedPages'), isFalse, reason: id);
      }
    });

    test('the comparison really reached the page-102 tail', () {
      // Page 101 stops mid-sentence at «وَتَوَلَّنِي فِيمَنْ». Everything after
      // that was read on page 102, up to the closing paren. If a later edit
      // truncated the record back to the page-101 half, reviewedPages would
      // be claiming a comparison that no longer applies.
      final t = _ar(k048);
      expect(t.contains('وَتَوَلَّنِي فِيمَنْ تَوَلَّيْتَ'), isTrue,
          reason: 'the seam between the two pages');
      expect(t.contains('وَبَارِكْ لِي فِيمَا أَعْطَيْتَ'), isTrue,
          reason: 'page 102, line 1');
      expect(t.endsWith('تَبَارَكْتَ رَبَّنَا وَتَعَالَيْتَ'), isTrue,
          reason: 'page 102, line 2 — up to the closing paren');
      // Roughly a third of the record is on page 102; pin that it is not a
      // token few characters.
      final seam = t.indexOf('تَوَلَّيْتَ،');
      expect(seam, greaterThan(0));
      expect(t.length - seam, greaterThan(100));
    });

    test('no other record is a split-off piece of it', () {
      for (final other in _entries().where((e) => e['duaId'] != k048)) {
        final o = (other['text']['ar'] as String).trim();
        expect(o.length > 30 && _ar(k048).contains(o), isFalse,
            reason: '${other['duaId']} must not duplicate part of -048');
      }
    });
  });

  group('the «من» sites on this page', () {
    // Counted from the text itself, not from a reading tally, and kept
    // strictly secondary: the hash above is what protects the text. This
    // group would still pass on a record whose vowels were all rewritten in
    // some other word, which is exactly why it is not a substitute.
    List<String> tokens(String id) => _ar(id)
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[،.:؛]'), ''))
        .toList();

    String bare(String w) => w.runes
        .where((r) => !((r >= 0x064B && r <= 0x0652) || r == 0x0670))
        .map(String.fromCharCode)
        .join();

    List<String> standalone(String id) =>
        tokens(id).where((w) => const ['من', 'ومن'].contains(bare(w))).toList();

    test('-043 and -045 have none at all', () {
      expect(standalone(k043), isEmpty);
      expect(standalone(k045), isEmpty);
    });

    test('-044 has two: «مِنْ شَرِّ» sukun, «مِنَ الْفَقْرِ» fatha', () {
      expect(standalone(k044), ['مِنْ', 'مِنَ']);
      expect(_ar(k044).contains('مِنْ شَرِّ كُلِّ شَيْءٍ'), isTrue);
      expect(_ar(k044).contains('وَأَغْنِنَا مِنَ الْفَقْرِ'), isTrue);
    });

    test('-046 has one, with a fatha', () {
      expect(standalone(k046), ['مِنَ']);
      expect(_ar(k046).contains('مِنَ الْهَمِّ'), isTrue);
    });

    test('-047 has four: three sukun and one fatha, plus «مِنْهَا»', () {
      final s = standalone(k047);
      expect(s, hasLength(4));
      expect(s.where((w) => w == 'مِنْ').length, 3);
      expect(s.where((w) => w == 'مِنَ').length, 1);
      // «مِنَ الْفِتَنِ» and «مِنْ فِتْنَةِ» sit on the same printed line and
      // were the visual control for the whole page.
      expect(_ar(k047).contains('مِنَ الْفِتَنِ'), isTrue);
      expect(_ar(k047).contains('مِنْ فِتْنَةِ الدَّجَّالِ'), isTrue);
      // attached form, counted apart
      expect(tokens(k047).where((w) => bare(w) == 'منها').length, 1);
    });

    test('-048 has one, and it sits on page 102, not 101', () {
      expect(standalone(k048), ['مَنْ']);
      expect(_ar(k048).contains('لَا يَذِلُّ مَنْ وَالَيْتَ'), isTrue);
      // «فِيمَنْ» is a different word and is counted apart.
      expect(tokens(k048).where((w) => bare(w) == 'فيمن').length, 3);
    });

    test('the page-101 side totals seven standalone sites', () {
      // -048's own «مَنْ» is excluded: it is printed on page 102.
      var n = 0;
      for (final id in [k043, k044, k045, k046, k047]) {
        n += standalone(id).length;
      }
      expect(n, 7);
    });
  });

  group('recording the page changed nothing about deployment', () {
    test('all six stay unverified general duas', () {
      for (final id in kPage101) {
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

    test('the ledger counters are what page 101 leaves behind', () {
      final l = jsonDecode(
        File('review/human_review_ledger.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final s = l['summary'] as Map<String, dynamic>;
      final rs = _rawReviews();
      expect(s['totalReviews'], rs.length);
      expect(s['totalReviews'], greaterThanOrEqualTo(82),
          reason: 'page 101 took the ledger to 82; it can only grow');
      // Counted per status from the reviews themselves, so pending and
      // failed stay supported rather than assumed away.
      for (final st in ['passed', 'blocked', 'pending', 'failed']) {
        expect(s[st], rs.where((r) => r['reviewStatus'] == st).length,
            reason: 'summary.$st disagrees with the reviews array');
      }
      expect(
          (s['passed'] as int) +
              (s['blocked'] as int) +
              (s['pending'] as int) +
              (s['failed'] as int),
          s['totalReviews'],
          reason: 'a review carries a status outside the four the schema '
              'supports, or a status is being double-counted');
      expect(s['verifiedRecords'], 0);
      expect(s['firestoreVerificationPerformed'], isFalse);
      expect(rs.map((r) => r['recordId']).toSet().length, rs.length,
          reason: 'no record may be reviewed twice');
    });
  });
}
