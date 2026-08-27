// Printed page 97 — the three prose duas (general-023, -024, -025).
//
// This page took three passes, and the first two got it wrong in opposite
// directions. Comparing whole strings said everything matched. Eyeballing
// enlarged crops said four vowels were wrong. Both were unreliable for the
// same reason: the page is a 1302x1912 JPEG, so a sukun is about five pixels
// across and a crop wide enough to read comfortably also pulls in the sukun
// of the following «الْـ» — which is what got misread as a mark on the noon.
//
// What settled it was measuring shape on the native pixels, with the search
// window clipped to the noon's own horizontal span so a neighbouring word can
// never contribute a mark. A fatha is a slanted bar (elongation 5.6-7.3, fill
// 0.23-0.28). A sukun is a ring (elongation 1.27-1.60, fill 0.45-0.56). No
// overlap. Counting the ring's hole does NOT work at this resolution — it
// succeeded on only 6 of 15 rings — so hole-count is not what these tests pin.
//
// The outcome cuts both ways, which is why it is worth pinning: three
// positions in -024 really did store a fatha where the book prints a sukun,
// and -025 really does print a fatha at «مِنَ الْعَجْزِ», exactly as stored.
// An earlier attempt "corrected" -025 too and was reverted; these tests exist
// so that mistake cannot come back.
//
// Same lesson in the opposite direction for the opening word. -023 prints
// «اللَّهُمَ» with no shadda on the mim; -024 and -025 print «اللَّهُمَّ» with
// one. The book is inconsistent, and the records keep its inconsistency.
//
// The enclosing parentheses and the full stop after the closing paren are
// printing apparatus marking quoted matter, excluded from text.ar by the
// reviewer's decision. The full stop INSIDE -024 sits inside the quoted unit,
// belongs to the sentence, and is not a record boundary.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';

const String k023 = 'moia-mukhtasar-1446-general-023';
const String k024 = 'moia-mukhtasar-1446-general-024';
const String k025 = 'moia-mukhtasar-1446-general-025';
const List<String> kPage97 = [k023, k024, k025];

const String kFatha = 'َ';
const String kSukun = 'ْ';
const String kShadda = 'ّ';
const String kKasra = 'ِ';
const String kMeem = 'م';
const String kNoon = 'ن';

/// «مِنْ » as page 97 prints it at the corrected sites: meem, kasra, noon, sukun.
const String kMinSukun = '$kMeem$kKasra$kNoon$kSukun ';

/// «مِنَ » — wrong at the three -024 sites, right everywhere it still appears.
const String kMinFatha = '$kMeem$kKasra$kNoon$kFatha ';

/// sha256(text.ar + U+0000 + text.en) — the pack's own construction.
const Map<String, String> kReviewedHashes = {
  k023: '27be045d943f743742d020e1abd69a910e7ecf031c57fe0986b9aadf661f6712',
  k024: 'c998fcddcbaa2af67881fad4948e533091d4d964f2965ec7ed26a8f6725e6b74',
  k025: 'ced5ee217007d540aaa6140218f481c572a2f6c2b727124b03e53d46cb901b99',
};

/// The pinned KFGQPC Hafs corpus — the only authority for Quran text here.
const String kCorpus = 'third_party/kfgqpc/hafsData_v2-0.json';

/// Letters only: vowels, shadda, sukun and dagger alef dropped, alef forms
/// unified. Comparing skeletons is strictly wider than comparing code points,
/// so a quotation cannot slip past by being written in a different rasm.
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

String _contentHash(Map<String, dynamic> e) {
  final t = e['text'] as Map<String, dynamic>;
  return sha256.convert(utf8.encode('${t['ar']}\u0000${t['en']}')).toString();
}

void main() {
  group('the three corrected positions in -024 carry a sukun', () {
    // Anchored on the following word, so an assertion can never drift onto a
    // different «من» in the same record.
    const List<String> corrected = ['الْخَطَايَا', 'الدَّنَسِ', 'الْكَسَلِ'];

    test('each reads «مِنْ» as the page prints it', () {
      final ar = _ar(k024);
      for (final w in corrected) {
        expect(ar.contains('$kMinSukun$w'), isTrue,
            reason: '-024: «مِنْ $w» is what page 97 prints');
        expect(ar.contains('$kMinFatha$w'), isFalse,
            reason: '-024: «مِنَ $w» was the transcription error, twice');
      }
    });

    test('the two sites that were already right were not touched', () {
      final ar = _ar(k024);
      expect(ar.contains('$kMinSukun' 'فِتْنَةِ'), isTrue);
      expect(ar.contains('$kMinSukun' 'شَرِّ'), isTrue);
    });

    test('sukun and fatha are different code points, so this is not NFC drift',
        () {
      expect(kMinSukun, isNot(equals(kMinFatha)));
      expect(kSukun.codeUnitAt(0), 0x0652);
      expect(kFatha.codeUnitAt(0), 0x064E);
    });
  });

  group('-025 keeps its fatha — the correction that was reverted', () {
    // An earlier pass changed this to a sukun on a misread crop. The page
    // prints a fatha, and general-029 on page 98 prints the same word the
    // same way. Re-"correcting" it would be silent damage to a sound text.
    test('«مِنَ الْعَجْزِ» is stored with a fatha', () {
      expect(_ar(k025).contains('$kMinFatha' 'الْعَجْزِ'), isTrue,
          reason: 'page 97 prints a fatha here; a sukun would be the old bug');
      expect(_ar(k025).contains('$kMinSukun' 'الْعَجْزِ'), isFalse);
    });

    test('its other two sites keep their sukun', () {
      expect(_ar(k025).contains('$kMinSukun' 'عَذَابِ'), isTrue);
      expect(_ar(k025).contains('وَ$kMinSukun' 'فِتْنَةِ'), isTrue);
    });

    test('page 98 spells the same phrase the same way', () {
      // Independent corroboration from a different page and record: if the
      // book were really writing a sukun here, -029 would show it too.
      final other = _entries()
          .firstWhere((e) => e['duaId'] == 'moia-mukhtasar-1446-general-029');
      expect((other['text']['ar'] as String).contains('$kMinFatha' 'الْعَجْزِ'),
          isTrue);
    });
  });

  group('the source\'s three spellings of «اللهم» all survive', () {
    test('-023 has a bare fatha on the mim, with no shadda', () {
      final w = _ar(k023).split(' ').first;
      expect(w.endsWith('$kMeem$kFatha'), isTrue,
          reason: '-023 must print «اللَّهُمَ»: mim + fatha, no shadda');
      expect(w.endsWith('$kMeem$kFatha$kShadda'), isFalse,
          reason: 'adding a shadda here would be us editing the source');
      expect(w.contains(kShadda), isTrue,
          reason: 'the lam still has its shadda — only the mim lacks one');
    });

    test('-024 and -025 do carry it, so the gap in -023 is real', () {
      for (final id in [k024, k025]) {
        expect(
            _ar(id).split(' ').first.endsWith('$kMeem$kFatha$kShadda'), isTrue,
            reason: '$id must print «اللَّهُمَّ»');
      }
    });

    test('-026 on page 98 is a third spelling again, and also kept', () {
      // lam without shadda, mim with one — different from both page-97 forms.
      final w = (_entries().firstWhere((e) =>
                  e['duaId'] == 'moia-mukhtasar-1446-general-026')['text']['ar']
              as String)
          .split(' ')
          .first;
      expect(w.endsWith('$kMeem$kFatha$kShadda'), isTrue);
      expect(w, isNot(equals(_ar(k023).split(' ').first)));
      expect(w, isNot(equals(_ar(k024).split(' ').first)));
    });

    test('nothing normalised the three page-97 openings together', () {
      final first = kPage97.map((id) => _ar(id).split(' ').first).toList();
      expect(first[0], isNot(equals(first[1])));
      expect(first[1], equals(first[2]));
    });
  });

  group('-024 is one printed unit and is not split', () {
    test('the page holds five records, three of them these prose duas', () {
      // -021 (al-Ahqaf 15) and -022 (al-Hashr 10) are the Quranic duas at the
      // top of the page, reviewed earlier. Pinning all five stops a later
      // split of -024 from arriving as "just another record on page 97".
      final onPage = _entries()
          .where((e) => e['printedPage'] == 97)
          .map((e) => e['duaId'] as String)
          .toSet();
      expect(onPage, {
        'moia-mukhtasar-1446-general-021',
        'moia-mukhtasar-1446-general-022',
        ...kPage97,
      });
    });

    test('its internal full stop is sentence punctuation, not a boundary', () {
      final ar = _ar(k024);
      expect(ar.contains('وَالْمَغْرِبِ. اللَّهُمَّ'), isTrue);
      expect('.'.allMatches(ar).length, 1);
      expect(ar.endsWith('.'), isFalse);
    });

    test('no other record is a split-off half of it', () {
      final halves = _ar(k024).split('. ');
      expect(halves.length, 2);
      for (final other in _entries().where((e) => e['duaId'] != k024)) {
        for (final h in halves) {
          expect((other['text']['ar'] as String).trim() == h.trim(), isFalse,
              reason: '${other['duaId']} must not duplicate half of -024');
        }
      }
    });
  });

  group('the printing apparatus stayed out of the text', () {
    test('no parentheses, no trailing period, no padding', () {
      for (final id in kPage97) {
        final ar = _ar(id);
        expect(ar.contains('('), isFalse, reason: id);
        expect(ar.contains(')'), isFalse, reason: id);
        expect(ar.trim().endsWith('.'), isFalse, reason: id);
        expect(ar, equals(ar.trim()), reason: id);
      }
    });

    test('only -024 changed length-neutrally; the others are untouched', () {
      // A sukun replacing a fatha is one code point for one, so any added
      // word, paren or period would move these numbers.
      expect(_ar(k023).length, 158);
      expect(_ar(k024).length, 553);
      expect(_ar(k025).length, 177);
    });
  });

  group('the reviewed text is pinned to what was read off the page', () {
    test('each record hashes to its reviewed value', () {
      for (final id in kPage97) {
        expect(_contentHash(_entry(id)), kReviewedHashes[id], reason: id);
      }
    });

    test('the ledger reviewed that same hash on page 97', () {
      final r = _reviews();
      for (final id in kPage97) {
        expect(r[id]!['reviewedTextHash'], kReviewedHashes[id], reason: id);
        expect(r[id]!['reviewedPage'], 97, reason: id);
      }
    });
  });

  group('the review is recorded per record, not per batch', () {
    test('all three passed on their own', () {
      final r = _reviews();
      for (final id in kPage97) {
        expect(r[id], isNotNull, reason: id);
        expect(r[id]!['reviewStatus'], 'passed', reason: id);
        expect(r[id]!['textReviewStatus'], 'passed', reason: id);
        expect(r[id]!['deploymentBlocked'], isFalse, reason: id);
        expect(r[id]!['excludedFromImport'], isFalse, reason: id);
      }
    });

    test('only -024 is flagged as corrected', () {
      final r = _reviews();
      expect(r[k023]!['transcriptionCorrected'], isFalse);
      expect(r[k024]!['transcriptionCorrected'], isTrue);
      expect(r[k025]!['transcriptionCorrected'], isFalse);
    });

    test('the note names all three moved sites and the code points', () {
      final n = _reviews()[k024]!['transcriptionNote'] as String;
      for (final w in ['الْخَطَايَا', 'الدَّنَسِ', 'الْكَسَلِ']) {
        expect(n, contains(w));
      }
      expect(n, contains('U+0652'));
      expect(n, contains('U+064E'));
    });

    test('-025\'s note records that it was checked and left alone', () {
      expect(_reviews()[k025]!['transcriptionNote'], contains('الْعَجْزِ'));
    });

    test('the page carries no takhrij, and that was checked not skipped', () {
      final r = _reviews();
      for (final id in kPage97) {
        expect(r[id]!['sourceReferencesReviewStatus'], 'reviewed_none',
            reason: id);
        expect((_entry(id)['sourceReferences'] as List), isEmpty, reason: id);
        expect(_entry(id)['quranRef'], isNull, reason: id);
      }
    });
  });

  group('none of the three contains Quranic text', () {
    test('checked against the pinned KFGQPC corpus, not by eye', () {
      // A null quranRef is a claim about the text, so it gets checked.
      // -023 echoes the vocabulary of al-Hujurat 7 while being a supplication
      // in its own wording — exactly what a "looks Quranic" guess gets wrong.
      final corpus = (jsonDecode(File(kCorpus).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      expect(corpus.length, 6236);
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
                'a real quotation needs a quranRef and the Quran-text '
                'authority checks, not a general_dua record');
      }
    });
  });

  group('reviewing the page changed nothing about deployment', () {
    test('the three stay unverified and unpublished', () {
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
      }
    });

    test('the pack is still 85 unverified records', () {
      final all = _entries();
      expect(all.length, 85);
      expect(all.every((e) => e['verificationStatus'] == 'unverified'), isTrue);
    });
  });
}
