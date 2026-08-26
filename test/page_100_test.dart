// Printed page 100 — four duas, none of which needed a correction.
//
// The page compared clean end to end: all four match the print letter for
// letter, raw and under NFC, at identical length. Nothing in text.ar changed,
// and these tests exist to keep it that way.
//
// Page structure, for anyone re-deriving it: 16 text lines below the header
// rule and the «١٠٠» number box. The first two are the TAIL of general-050,
// whose unit opens on page 99 — that record is already recorded with
// reviewedPages [99, 100] and is deliberately NOT re-recorded here. Then
// general-039 (6 lines), -040 (3), -041 (3), -042 (2).
//
// Every «من» in these four records was isolated at its own word boundary
// before its mark was judged, never by a wide crop that can pick up the
// following word's sukun — the mistake that cost a reverted commit on page
// 97. Line 2 of -039 carries its own control: «وَمِنْ طَاعَتِكَ» (sukun ring)
// and «وَمِنَ الْيَقِينِ» (fatha stroke) in the same line, same size.
//
// -042 prints a full stop INSIDE its own parentheses («…إِلَّا أَنْتَ.
// فَاغْفِرْ لِي»). That is sentence punctuation, not a record boundary, and the
// record is not split at it — the same call already made for -024 and -050.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';

const String k039 = 'moia-mukhtasar-1446-general-039';
const String k040 = 'moia-mukhtasar-1446-general-040';
const String k041 = 'moia-mukhtasar-1446-general-041';
const String k042 = 'moia-mukhtasar-1446-general-042';
const String k050 = 'moia-mukhtasar-1446-general-050';

const List<String> kPage100 = [k039, k040, k041, k042];

/// sha256(text.ar + U+0000 + text.en) of the reviewed text.
const Map<String, String> kHashes = {
  k039: '0d738c334fe6ed09',
  k040: '50e3afc51f13810a',
  k041: '600ef7a6bb127777',
  k042: '50ca348cc7ab756f',
};

const Map<String, int> kLengths = {
  k039: 564,
  k040: 197,
  k041: 193,
  k042: 183,
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
  group('all four are recorded, on page 100, with nothing corrected', () {
    test('each has a passed review naming page 100', () {
      final r = _reviews();
      for (final id in kPage100) {
        expect(r[id], isNotNull, reason: id);
        expect(r[id]!['reviewStatus'], 'passed', reason: id);
        expect(r[id]!['textReviewStatus'], 'passed', reason: id);
        expect(r[id]!['reviewedPage'], 100, reason: id);
        expect(r[id]!['transcriptionCorrected'], isFalse,
            reason: '$id needed no correction');
        expect(r[id]!['deploymentBlocked'], isFalse, reason: id);
        expect(r[id]!['excludedFromImport'], isFalse, reason: id);
        expect(_entry(id)['printedPage'], 100, reason: id);
      }
    });

    test('none of them claims to span pages', () {
      // Only -050 does, and it is recorded on the page-99 batch, not here.
      final r = _reviews();
      for (final id in kPage100) {
        expect(r[id]!.containsKey('reviewedPages'), isFalse, reason: id);
      }
    });

    test('the page prints no takhrij, and that was checked not assumed', () {
      final r = _reviews();
      for (final id in kPage100) {
        expect(r[id]!['sourceReferencesReviewStatus'], 'reviewed_none',
            reason: id);
        expect((_entry(id)['sourceReferences'] as List), isEmpty, reason: id);
        expect(_entry(id)['quranRef'], isNull, reason: id);
      }
    });

    test('each text still hashes to what was compared, at the same length', () {
      for (final id in kPage100) {
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
      for (final id in kPage100) {
        final t = _ar(id);
        expect(t.contains('('), isFalse, reason: id);
        expect(t.contains(')'), isFalse, reason: id);
        expect(t.trim().endsWith('.'), isFalse, reason: id);
        expect(t, equals(t.trim()), reason: id);
      }
    });

    test('general-050 was not re-recorded by this batch', () {
      final r = _reviews()[k050]!;
      expect(r['reviewedPage'], 99, reason: 'its unit opens on 99');
      expect(r['reviewedPages'], [99, 100]);
      final all = (jsonDecode(
        File('review/human_review_ledger.json').readAsStringSync(),
      ) as Map<String, dynamic>)['reviews'] as List;
      expect(all.where((e) => (e as Map)['recordId'] == k050).length, 1,
          reason: '-050 must appear exactly once in the ledger');
    });

    test('the tail compared on page 100 is still in -050', () {
      // If a later edit truncated -050 back to what page 99 alone shows, the
      // page-100 half of that comparison would silently stop applying.
      expect(_ar(k050).endsWith('قَضَيْتَهُ لِي خَيْرًا'), isTrue);
      expect(_ar(k050).contains('وَأَعُوذُ بِكَ مِنَ النَّارِ'), isTrue);
    });
  });

  group('-042 keeps its printed internal full stop and stays one record', () {
    test('the stop is present, and it is the only one', () {
      final t = _ar(k042);
      expect('.'.allMatches(t).length, 1);
      expect(t.contains('إِلَّا أَنْتَ. فَاغْفِرْ لِي'), isTrue);
      expect(t.endsWith('.'), isFalse,
          reason: 'the closing stop is apparatus and stays out');
    });

    test('no other record is a split-off half of it', () {
      final halves = _ar(k042).split('. ').map((s) => s.trim()).toList();
      expect(halves, hasLength(2));
      for (final other in _entries().where((e) => e['duaId'] != k042)) {
        for (final h in halves) {
          expect((other['text']['ar'] as String).trim() == h, isFalse,
              reason: '${other['duaId']} must not duplicate a half of -042');
        }
      }
    });
  });

  group('the «من» sites this page turns on', () {
    // Counted from the text itself, not from a reading tally. Sites are the
    // standalone particle «مِنْ/مِنَ» and the relative pronoun «مَنْ»; the
    // assimilated «مِنَّا»/«مِنِّي» are counted apart, because they are not
    // «من» followed by another word and cannot carry a sukun or a fatha.
    List<String> tokens(String id) => _ar(id)
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[،.:؛]'), ''))
        .toList();

    String bare(String w) => w.runes
        .where((r) => !((r >= 0x064B && r <= 0x0652) || r == 0x0670))
        .map(String.fromCharCode)
        .join();

    test('-039 has 6 standalone «من» and 1 assimilated «مِنَّا»', () {
      final t = tokens(k039);
      final standalone = t.where((w) => const ['من', 'ومن'].contains(bare(w)));
      expect(standalone.length, 6);
      // three of them are the relative pronoun, all with a sukun
      expect(standalone.where((w) => w == 'مَنْ').length, 3);
      expect(standalone.where((w) => w == 'مِنْ' || w == 'وَمِنْ').length, 2);
      expect(standalone.where((w) => w == 'وَمِنَ').length, 1);
      expect(t.where((w) => bare(w) == 'منا' && w.contains('ّ')).length, 1);
    });

    test('-040 has 4: two fatha, two sukun', () {
      final t = tokens(k040).where((w) => bare(w) == 'من').toList();
      expect(t, hasLength(4));
      expect(t.where((w) => w == 'مِنَ').length, 2);
      expect(t.where((w) => w == 'مِنْ').length, 2);
    });

    test('-041 has no standalone «من», only «مِنِّي»', () {
      final t = tokens(k041);
      expect(t.where((w) => const ['من', 'ومن'].contains(bare(w))), isEmpty);
      expect(t.where((w) => bare(w) == 'مني' && w.contains('ّ')).length, 1);
    });

    test('-042 has exactly one, with a sukun', () {
      final t = tokens(k042).where((w) => bare(w) == 'من').toList();
      expect(t, ['مِنْ']);
    });

    test('the four records together hold 11 standalone sites and 2 assimilated',
        () {
      var standalone = 0, assimilated = 0;
      for (final id in kPage100) {
        for (final w in tokens(id)) {
          final b = bare(w);
          if (b == 'من' || b == 'ومن') standalone++;
          if ((b == 'منا' || b == 'مني') && w.contains('ّ')) assimilated++;
        }
      }
      expect(standalone, 11);
      expect(assimilated, 2);
    });

    test('-050\'s page-100 tail holds 3 more, counted apart', () {
      // Kept separate so the page total is never quoted as if the tail
      // belonged to one of the four new records.
      final tail = _ar(k050).substring(_ar(k050).length - 202);
      final t = tail
          .split(RegExp(r'\s+'))
          .map((w) => w.replaceAll(RegExp(r'[،.:؛]'), ''))
          .where((w) => bare(w) == 'من')
          .toList();
      expect(t, hasLength(3));
      expect(t.where((w) => w == 'مِنْ').length, 2);
      expect(t.where((w) => w == 'مِنَ').length, 1);
    });
  });

  group('the dagger alef on this page survives', () {
    test('«عَلَىٰ» in -039 and «إِلَىٰ» in -040 keep U+0670', () {
      expect('عَلَىٰ'.allMatches(_ar(k039)).length, 2);
      expect(_ar(k040).contains('إِلَىٰ'), isTrue);
    });
  });

  group('none of the four quotes the Quran', () {
    test('no 25-character window matches the pinned KFGQPC corpus', () {
      // Scope, stated plainly: this rules out a shared run of 25 characters
      // or more in the vowel-stripped skeleton. It does NOT rule out a
      // shorter fragment, nor a passage written with a different rasm or
      // orthography. The finding that these are not Quran quotations rests on
      // the full comparison with the printed page and on the bracketed unit's
      // context; this check is corroboration, not the basis.
      final corpus = (jsonDecode(File(kCorpus).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      expect(corpus.length, 6236);
      final hay =
          corpus.map((a) => _skeleton(a['aya_text'] as String)).join(' | ');
      // Linear in the record's length: if no 25-character window appears,
      // no longer run can either, since every longer run contains one.
      const window = 25;
      for (final id in kPage100) {
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
    test('all four stay unverified general duas', () {
      for (final id in kPage100) {
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

    test('the ledger stayed consistent and conferred nothing', () {
      // Deliberately NOT a snapshot of totalReviews. This file once pinned
      // "76 reviews, 9 unreviewed", which was true the day page 100 was
      // recorded and false the moment page 101 was — a counter that every
      // later batch must break is a tripwire, not an invariant. What page
      // 100 is entitled to assert is that its own four records are in the
      // ledger exactly once (asserted above) and that recording them moved
      // nothing else. The live counters belong to the newest batch's test.
      final l = jsonDecode(
        File('review/human_review_ledger.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final s = l['summary'] as Map<String, dynamic>;
      final rs = (l['reviews'] as List).cast<Map<String, dynamic>>();
      expect(s['totalReviews'], rs.length);
      expect(s['totalReviews'], greaterThanOrEqualTo(76),
          reason: 'page 100 took the ledger to 76; it can only grow');
      expect(s['passed'], rs.length - (s['blocked'] as int));
      expect(s['blocked'], 1);
      expect(s['pending'], 0);
      expect(s['failed'], 0);
      expect(s['verifiedRecords'], 0);
      expect(s['firestoreVerificationPerformed'], isFalse);
      expect(rs.map((r) => r['recordId']).toSet().length, rs.length,
          reason: 'no record may be reviewed twice');
      expect(rs.length, lessThanOrEqualTo(85),
          reason: 'the ledger cannot hold more reviews than there are records');
    });
  });
}
