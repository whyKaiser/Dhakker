// Printed page 97 — the three general duas (general-023, -024, -025).
//
// This page was reviewed twice. The first pass compared whole strings and
// reported a clean match; the second pass rendered the page at 450dpi, cut
// every line in half at native resolution, and read each half by eye. That
// second pass found four vowel differences the first had missed: the book
// prints «مِنْ» with a sukun where the records stored «مِنَ» with a fatha.
//
// The distinction is not a normalisation artefact. A hollow ring above the
// nun is a sukun (U+0652); a diagonal stroke is a fatha (U+064E); a solid
// dot is the letter's own dot. NFC and NFD both leave the two forms
// unequal, so no amount of normalising turns one into the other.
//
// The opposite lesson sits in the same page: general-023 prints «اللَّهُمَ»
// with a mim carrying a fatha and NO shadda, where -024 and -025 print
// «اللَّهُمَّ» with both. That is the source's own inconsistency, and the
// records must keep it. Correcting it would be us editing the ministry's
// text — which is the one thing this pipeline exists to prevent. So the
// tests below pull in two directions on purpose: they pin the four sukuns
// as corrections, and pin the missing shadda as something never to correct.
//
// The enclosing parentheses and the full stop after the closing paren are
// printing apparatus marking quoted matter, not part of the dua, and are
// excluded from text.ar by the reviewer's decision. The full stop INSIDE
// general-024 is different: it falls inside the quoted unit and belongs to
// the printed sentence, so it stays — and it is not evidence of a split.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';

const String k023 = 'moia-mukhtasar-1446-general-023';
const String k024 = 'moia-mukhtasar-1446-general-024';
const String k025 = 'moia-mukhtasar-1446-general-025';
const List<String> kPage97 = [k023, k024, k025];

// Arabic marks, named so the assertions below read as what they check.
const String kFatha = 'َ';
const String kSukun = 'ْ';
const String kShadda = 'ّ';
const String kKasra = 'ِ';
const String kMeem = 'م';
const String kNoon = 'ن';

/// «مِنْ » — the printed form on this page: meem, kasra, noon, sukun.
const String kMinSukun = '$kMeem$kKasra$kNoon$kSukun ';

/// «مِنَ » — the form the records stored before the correction.
const String kMinFatha = '$kMeem$kKasra$kNoon$kFatha ';

/// The reviewed text of each record, pinned by hash so a later edit to the
/// source pack cannot quietly drift away from what was read off the page.
/// These are sha256(text.ar + U+0000 + text.en), the pack's own construction.
const Map<String, String> kReviewedHashes = {
  k023: '27be045d943f743742d020e1abd69a910e7ecf031c57fe0986b9aadf661f6712',
  k024: 'c998fcddcbaa2af67881fad4948e533091d4d964f2965ec7ed26a8f6725e6b74',
  k025: '3f0984bfd12066d92fec13c5c84a69cd2a47d7d13f3ddff699bfea0895518362',
};

/// The pinned KFGQPC Hafs corpus — the only authority for Quran text here.
const String kCorpus = 'third_party/kfgqpc/hafsData_v2-0.json';

/// Letters only: every vowel, shadda, sukun and dagger alef dropped, and the
/// alef forms unified. Comparing skeletons makes the check strictly *wider*
/// than a code-point comparison, so a quotation cannot slip past by being
/// written in a different rasm.
String _skeleton(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    // Arabic combining marks: fathatan..sukun, superscript alef, and the
    // Uthmani mark block.
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

String _contentHash(Map<String, dynamic> e) {
  final t = e['text'] as Map<String, dynamic>;
  // The pack's own construction: ar, a NUL separator, then en.
  return sha256.convert(utf8.encode('${t['ar']}\u0000${t['en']}')).toString();
}

void main() {
  group('general-023 keeps the source\'s own «اللَّهُمَ»', () {
    // The whole point: this record differs from its two neighbours, and the
    // difference must survive every future edit. A "tidy-up" that gave the
    // mim a shadda would be an undisclosed change to a ministry text.
    test('the opening word ends in a bare fatha, with no shadda', () {
      final w = _ar(k023).split(' ').first;
      expect(w.endsWith('$kMeem$kFatha'), isTrue,
          reason: 'general-023 must print «اللَّهُمَ»: mim + fatha, no shadda');
      expect(w.endsWith('$kMeem$kFatha$kShadda'), isFalse,
          reason: 'a shadda here would be us editing the source');
      expect(w.contains(kShadda), isTrue,
          reason:
              'the shadda on the lam is still there — only the mim lacks one');
    });

    test('-024 and -025 do carry the shadda, so the gap is real not a typo',
        () {
      for (final id in [k024, k025]) {
        expect(
            _ar(id).split(' ').first.endsWith('$kMeem$kFatha$kShadda'), isTrue,
            reason: '$id must print «اللَّهُمَّ»');
      }
    });

    test('the three openings are not normalised to one another', () {
      final first = kPage97.map((id) => _ar(id).split(' ').first).toList();
      expect(first[0], isNot(equals(first[1])),
          reason: 'collapsing -023 into -024 would erase the printed reading');
      expect(first[1], equals(first[2]));
    });
  });

  group('the four corrected positions carry a sukun, never a fatha', () {
    // Anchored on the following word so an assertion can never drift onto a
    // different «من» in the same record.
    const Map<String, List<String>> corrected = {
      k024: ['الْخَطَايَا', 'الدَّنَسِ', 'الْكَسَلِ'],
      k025: ['الْعَجْزِ'],
    };

    test('each site reads «مِنْ» as printed', () {
      corrected.forEach((id, words) {
        final ar = _ar(id);
        for (final w in words) {
          expect(ar.contains('$kMinSukun$w'), isTrue,
              reason: '$id: «مِنْ $w» is what page 97 prints');
          expect(ar.contains('$kMinFatha$w'), isFalse,
              reason: '$id: «مِنَ $w» was the transcription error');
        }
      });
    });

    test('no normalisation can turn one form into the other', () {
      // Guards the reasoning, not just the data: if these ever compared
      // equal, every sukun/fatha assertion above would be vacuous.
      expect(kMinSukun, isNot(equals(kMinFatha)));
      expect(kSukun.codeUnitAt(0), 0x0652);
      expect(kFatha.codeUnitAt(0), 0x064E);
    });

    test('the correction changed nothing but those code points', () {
      // Lengths are pinned: a sukun replacing a fatha is one-for-one, so any
      // added word, paren or period would show up here.
      expect(_ar(k023).length, 158);
      expect(_ar(k024).length, 553);
      expect(_ar(k025).length, 177);
    });

    test('«مِنْ عَذَابِ» and «وَمِنْ فِتْنَةِ» in -025 were already correct',
        () {
      expect(_ar(k025).contains('$kMinSukun' 'عَذَابِ'), isTrue);
      expect(_ar(k025).contains('وَ$kMinSukun' 'فِتْنَةِ'), isTrue);
    });
  });

  group('general-024 is one printed unit and is not split', () {
    test('the page holds five records, and these three are the prose duas', () {
      // The page opens with two Quranic duas (-021 al-Ahqaf 15, -022
      // al-Hashr 10) reviewed in an earlier batch, then the three prose duas
      // reviewed here. Pinning all five stops a later split of -024 from
      // slipping in as "just another record on page 97".
      final onPage = _entries()
          .where((e) => e['printedPage'] == 97)
          .map((e) => e['duaId'] as String)
          .toSet();
      expect(onPage, {
        'moia-mukhtasar-1446-general-021',
        'moia-mukhtasar-1446-general-022',
        ...kPage97,
      });
      // Only the Quranic pair carries a quranRef; these three are hadith
      // supplications and must never acquire one.
      for (final id in kPage97) {
        expect(_entry(id)['quranRef'], isNull, reason: id);
      }
    });

    test('none of the three contains Quranic text, checked against KFGQPC', () {
      // A null quranRef is a claim about the text, so it is checked against
      // the pinned corpus rather than taken on trust — no rasm heuristic,
      // no hand-typed ayah. general-023 echoes the vocabulary of al-Hujurat
      // 7 while being a supplication in its own wording, which is exactly
      // the case a "looks Quranic" guess would get wrong.
      final corpus = (jsonDecode(File(kCorpus).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      expect(corpus.length, 6236,
          reason: 'the pinned corpus is the whole Mushaf');
      final haystack =
          corpus.map((a) => _skeleton(a['aya_text'] as String)).join(' | ');

      for (final id in kPage97) {
        final s = _skeleton(_ar(id));
        var longest = 0;
        for (var len = s.length; len > 24; len--) {
          for (var i = 0; i + len <= s.length; i++) {
            if (haystack.contains(s.substring(i, i + len))) {
              longest = len;
              break;
            }
          }
          if (longest > 0) break;
        }
        expect(longest, lessThan(25),
            reason: '$id shares a $longest-character run with the Mushaf; '
                'if that is a real quotation it needs a quranRef and the '
                'Quran-text authority checks, not a general_dua record');
      }
    });

    test('its internal full stop is part of the sentence, not a boundary', () {
      final ar = _ar(k024);
      expect(ar.contains('وَالْمَغْرِبِ. اللَّهُمَّ'), isTrue,
          reason: 'the page prints a period here and the unit continues');
      // One period, in the middle — not a terminator.
      expect('.'.allMatches(ar).length, 1);
      expect(ar.endsWith('.'), isFalse);
    });

    test('no second record duplicates either half of it', () {
      final ar = _ar(k024);
      final halves = ar.split('. ');
      expect(halves.length, 2);
      for (final other in _entries().where((e) => e['duaId'] != k024)) {
        final t = (other['text']['ar'] as String).trim();
        for (final h in halves) {
          expect(t == h.trim(), isFalse,
              reason: '${other['duaId']} must not be a split-off half of -024');
        }
      }
    });
  });

  group('the printing apparatus was never absorbed into the text', () {
    test('no record on the page gained parentheses or a trailing period', () {
      for (final id in kPage97) {
        final ar = _ar(id);
        expect(ar.contains('('), isFalse, reason: id);
        expect(ar.contains(')'), isFalse, reason: id);
        expect(ar.trim().endsWith('.'), isFalse, reason: id);
        expect(ar, equals(ar.trim()), reason: '$id must not pad with spaces');
      }
    });
  });

  group('the reviewed text is pinned to what was read off the page', () {
    test('each record hashes to its reviewed value', () {
      for (final id in kPage97) {
        expect(_contentHash(_entry(id)), kReviewedHashes[id], reason: id);
      }
    });

    test('the ledger records the same hash it reviewed', () {
      final r = _reviews();
      for (final id in kPage97) {
        expect(r[id]!['reviewedTextHash'], kReviewedHashes[id], reason: id);
        expect(r[id]!['reviewedPage'], 97, reason: id);
      }
    });
  });

  group('the page-97 review is recorded per record', () {
    test('all three passed on their own, not as a batch', () {
      final r = _reviews();
      for (final id in kPage97) {
        expect(r[id], isNotNull, reason: id);
        expect(r[id]!['reviewStatus'], 'passed', reason: id);
        expect(r[id]!['textReviewStatus'], 'passed', reason: id);
        expect(r[id]!['deploymentBlocked'], isFalse, reason: id);
        expect(r[id]!['excludedFromImport'], isFalse, reason: id);
      }
    });

    test('the page carries no takhrij, and that was reviewed not skipped', () {
      final r = _reviews();
      for (final id in kPage97) {
        // "reviewed and none printed" — distinct from nobody having looked.
        expect(r[id]!['sourceReferencesReviewStatus'], 'reviewed_none',
            reason: id);
        expect((_entry(id)['sourceReferences'] as List), isEmpty, reason: id);
        expect(_entry(id)['quranRef'], isNull, reason: id);
      }
    });

    test('only the two corrected records are flagged as corrected', () {
      final r = _reviews();
      expect(r[k023]!['transcriptionCorrected'], isFalse);
      expect(r[k024]!['transcriptionCorrected'], isTrue);
      expect(r[k025]!['transcriptionCorrected'], isTrue);
    });

    test('the correction note names every site that moved', () {
      final r = _reviews();
      for (final w in ['الْخَطَايَا', 'الدَّنَسِ', 'الْكَسَلِ']) {
        expect(r[k024]!['transcriptionNote'], contains(w));
      }
      expect(r[k025]!['transcriptionNote'], contains('الْعَجْزِ'));
      for (final id in [k024, k025]) {
        expect(r[id]!['transcriptionNote'], contains('U+0652'));
        expect(r[id]!['transcriptionNote'], contains('U+064E'));
      }
    });
  });

  group('reviewing the page changed nothing about deployment', () {
    test('the three records stay unverified and unpublished', () {
      for (final id in kPage97) {
        final e = _entry(id);
        expect(e['verificationStatus'], 'unverified', reason: id);
        expect(e['verifiedAt'], isNull, reason: id);
        expect(e['verifiedBy'], isNull, reason: id);
        expect(e['contentHash'], isNull, reason: id);
      }
    });

    test('they stay general duas, tied to no zone', () {
      for (final id in kPage97) {
        final m = _model(id);
        expect(m.contentKind, SupplicationContentKind.generalDua, reason: id);
        expect(m.zoneKey.trim(), isEmpty, reason: id);
        expect(_entry(id)['isGeneralSupplication'], isTrue, reason: id);
      }
    });

    test('the whole pack is still 85 unverified records', () {
      final all = _entries();
      expect(all.length, 85);
      expect(all.every((e) => e['verificationStatus'] == 'unverified'), isTrue);
    });
  });
}
