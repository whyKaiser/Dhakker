// Printed page 98 (general-026..033) and two of the page-74 guidance records.
//
// Page 98 is the first page in this review that came back clean: all eight
// records matched the print letter for letter, vowel for vowel, comma for
// comma — raw and under NFC, at identical length. Nothing was corrected here,
// and these tests exist to keep it that way, because "nothing changed" is the
// state most easily lost to a well-meaning later edit.
//
// Page 74 needed one fix. «فتُقصر» is printed «فتُقَصر», with a fatha on the
// qaf that the transcription dropped. That one was settled inside the word
// itself: the damma over the ta and the fatha over the qaf sit side by side
// in the same word, same size, same typeface — a damma has a loop (a hole),
// a fatha is a bare slanted bar. The word's boundaries were fixed by
// segmenting the line into word blocks BEFORE any cropping, so no mark from
// a neighbouring word could be read onto it. That sequence — find the word,
// then look at the mark — is what earlier passes got backwards.
//
// Two things on this page are deliberately NOT changed and are pinned so:
// «(ضفيرة)» keeps its parentheses, because there they are the ministry's own
// gloss inside the sentence rather than the quotation apparatus that wraps
// the page-97/98 duas; and the second «فتقصر» later in the same record has no
// printed vowel and stays bare.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';

const String kTaqsirShamil = 'moia-mukhtasar-1446-umrah-taqsir-shamil';
const String kTaqsirMara = 'moia-mukhtasar-1446-umrah-taqsir-mara';
const String kTamamUmrah = 'moia-mukhtasar-1446-umrah-tamam-umrah';

const List<String> kPage98 = [
  'moia-mukhtasar-1446-general-026',
  'moia-mukhtasar-1446-general-027',
  'moia-mukhtasar-1446-general-028',
  'moia-mukhtasar-1446-general-029',
  'moia-mukhtasar-1446-general-030',
  'moia-mukhtasar-1446-general-031',
  'moia-mukhtasar-1446-general-032',
  'moia-mukhtasar-1446-general-033',
];

const String kFatha = 'َ';
const String kShadda = 'ّ';
const String kDamma = 'ُ';

/// sha256(text.ar + U+0000 + text.en), pinned from the reviewed file.
const Map<String, String> kHashes = {
  kTaqsirShamil:
      '0ca402d9c192009863a2ab87dc03f2cdbf01e7455de52b0191c8c030d43c5d92',
  kTaqsirMara:
      '174c58d0013a3b4dad1bf64f543eda4abce2689d5d1d25dcf1ac32bf96eb77e1',
  'moia-mukhtasar-1446-general-026':
      '4e1b5d082560ee2401a4f2231052666a7fe8d348eb76c3eb4108c6e8e91107f2',
  'moia-mukhtasar-1446-general-027':
      '6a01d4abc0356ed647e8be39dbaf07800c9537d5f4950b305dee6e848291d0a9',
  'moia-mukhtasar-1446-general-028':
      '37db53589194178c90cb05db0bc47a6d764737a2c6ff55829b2784edd880824e',
  'moia-mukhtasar-1446-general-029':
      'a36a5bedccf6e722bee26f3941a6514b9392734fd47a3bf0ef3ac593eb6c48c0',
  'moia-mukhtasar-1446-general-030':
      'cc403b059e452971a6b6d78e03c9d1ab2bc8523108a3bab14fabd700572063bc',
  'moia-mukhtasar-1446-general-031':
      '7f7f29cb05b7d75ed1bb0c0f6326543cfdf4e21591d72ba05fe0c4b07bed19dc',
  'moia-mukhtasar-1446-general-032':
      '79e5a70d83845459d0bfbc3c9753b7f4af2f70e4593fe3a9dc606eb9c9afe74c',
  'moia-mukhtasar-1446-general-033':
      'f37d61ed9930b9b1a60004b9e1d0b76bf273c2e50f4445a12d072cd332a879b3',
};

/// Character counts of the reviewed text, pinned separately from the hash so
/// a failure says whether something grew or merely changed.
const Map<String, int> kLengths = {
  kTaqsirShamil: 34,
  kTaqsirMara: 208,
  'moia-mukhtasar-1446-general-026': 117,
  'moia-mukhtasar-1446-general-027': 262,
  'moia-mukhtasar-1446-general-028': 75,
  'moia-mukhtasar-1446-general-029': 378,
  'moia-mukhtasar-1446-general-030': 84,
  'moia-mukhtasar-1446-general-031': 123,
  'moia-mukhtasar-1446-general-032': 73,
  'moia-mukhtasar-1446-general-033': 187,
};

/// The pinned KFGQPC Hafs corpus — the only authority for Quran text here.
const String kCorpus = 'third_party/kfgqpc/hafsData_v2-0.json';

/// Letters only: vowels, shadda, sukun and dagger alef dropped, alef forms
/// unified — a strictly wider comparison than code points, so a quotation
/// cannot slip past by being set in a different rasm.
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
  group('taqsir-mara — the one corrected word on page 74', () {
    test('«فتُقَصر» carries the printed fatha on the qaf', () {
      expect(_ar(kTaqsirMara).contains('فتُقَصر'), isTrue,
          reason: 'page 74 prints a fatha here');
      expect(_ar(kTaqsirMara).contains('فتُقصر'), isFalse,
          reason: 'the bare form was the transcription error');
    });

    test('the second «فتقصر» in the same record stays bare', () {
      // «فتقصر من كل قَرْنٍ» has no printed vowel. A global replace would have
      // caught it too, which is why the fix was anchored on the damma form.
      expect(_ar(kTaqsirMara).contains('فتقصر من كل'), isTrue);
      expect('فتُقَصر'.allMatches(_ar(kTaqsirMara)).length, 1);
    });

    test('«(ضفيرة)» keeps its parentheses', () {
      // Not the quotation apparatus stripped elsewhere: here the brackets are
      // the ministry's own gloss, printed inside the sentence.
      expect(_ar(kTaqsirMara).contains('(ضفيرة)'), isTrue);
    });

    test('the em-dash asides are untouched', () {
      expect(_ar(kTaqsirMara).contains('-إن كان لها ضفائر-'), isTrue);
      expect(_ar(kTaqsirMara).contains('-إن لم يكن لها ضفائر-'), isTrue);
    });

    test('one fatha was added and nothing else moved', () {
      expect(_ar(kTaqsirMara).length, 208, reason: 'was 207 before the fatha');
      expect(_ar(kTaqsirMara).endsWith('ولا تزيد عليها.'), isTrue,
          reason: 'ends on the book\'s own full stop');
    });
  });

  group('tamam-umrah stays unreviewed and untouched', () {
    // «جميعَ» is printed with a fatha the record lacks, and whether «حِلاً»
    // carries a shadda is still open. Both are held so the record can be
    // settled in one edit rather than piecemeal.
    test('it is not recorded as reviewed', () {
      expect(_reviews().containsKey(kTamamUmrah), isFalse,
          reason: 'unresolved marks remain; guessing would be worse than '
              'leaving it unreviewed');
    });

    test('its text still holds both open sites unchanged', () {
      final t = _ar(kTamamUmrah);
      expect(t.contains('جميع محظورات'), isTrue,
          reason: 'the fatha on «جميعَ» is confirmed but deliberately not '
              'applied yet');
      expect(t.contains('حِلًّا'), isTrue, reason: 'shadda left as stored');
    });
  });

  group('page 98 matched the print and must keep matching', () {
    test('all eight are recorded passed on page 98', () {
      final r = _reviews();
      for (final id in kPage98) {
        expect(r[id], isNotNull, reason: id);
        expect(r[id]!['reviewStatus'], 'passed', reason: id);
        expect(r[id]!['reviewedPage'], 98, reason: id);
        expect(r[id]!['transcriptionCorrected'], isFalse,
            reason: '$id needed no correction');
        expect(r[id]!['sourceReferencesReviewStatus'], 'reviewed_none',
            reason: id);
      }
    });

    test('the page prints no takhrij, so every list is empty', () {
      for (final id in kPage98) {
        expect((_entry(id)['sourceReferences'] as List), isEmpty, reason: id);
        expect(_entry(id)['quranRef'], isNull, reason: id);
      }
    });

    test('none of the eight quotes the Quran, checked against KFGQPC', () {
      // The null quranRef above is a claim about the text, so it is tested
      // against the pinned corpus rather than trusted. -033 is the case worth
      // checking: «لَا إِلَهَ إِلَّا الله» is scriptural vocabulary, but this
      // record is the hadith of distress, not an ayah.
      final corpus = (jsonDecode(File(kCorpus).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      expect(corpus.length, 6236, reason: 'the whole Mushaf, not a subset');
      final hay =
          corpus.map((a) => _skeleton(a['aya_text'] as String)).join(' | ');
      for (final id in kPage98) {
        final s = _skeleton(_ar(id));
        var longest = 0;
        for (var len = s.length; len > 24; len--) {
          for (var i = 0; i + len <= s.length; i++) {
            if (hay.contains(s.substring(i, i + len))) {
              longest = len;
              break;
            }
          }
          if (longest > 0) break;
        }
        expect(longest, lessThan(25),
            reason: '$id shares a $longest-character run with the Mushaf; a '
                'real quotation needs a quranRef and the Quran-text authority '
                'checks, not a bare general_dua record');
      }
    });

    test('every reviewed text still hashes to what was compared', () {
      for (final id in [...kPage98, kTaqsirShamil, kTaqsirMara]) {
        expect(_hash(id), kHashes[id], reason: id);
        expect(_ar(id).length, kLengths[id], reason: id);
        expect(_reviews()[id]!['reviewedTextHash'], kHashes[id], reason: id);
      }
    });

    test('no parentheses or trailing period leaked into the text', () {
      for (final id in kPage98) {
        final t = _ar(id);
        expect(t.contains('('), isFalse, reason: id);
        expect(t.contains(')'), isFalse, reason: id);
        expect(t.trim().endsWith('.'), isFalse, reason: id);
        expect(t, equals(t.trim()), reason: id);
      }
    });
  });

  group('general-033 is dhikr, on what the text does', () {
    test('it is classified as dhikr, not dua', () {
      expect(_model('moia-mukhtasar-1446-general-033').contentKind,
          SupplicationContentKind.generalDhikr);
      expect(
          _reviews()['moia-mukhtasar-1446-general-033']![
              'contentKindConfirmed'],
          'general_dhikr');
    });

    test('it asks for nothing — no vocative, no petition', () {
      // The distinction is what the sentences do, not where they sit on the
      // page: -033 is entirely declarative, affirming God's oneness and
      // attributes. Its neighbours petition, and are duas.
      final t = _ar('moia-mukhtasar-1446-general-033');
      expect(t.contains('اللَّهُمَّ'), isFalse);
      expect(t.contains('أَسْأَلُكَ'), isFalse);
      expect(t.contains('أَعُوذُ'), isFalse);
      expect(t.contains('لَا إِلَهَ إِلَّا الله'), isTrue);
      // and its page-mates do petition, so the contrast is real
      expect(_ar('moia-mukhtasar-1446-general-030').contains('أَسْأَلُكَ'),
          isTrue);
    });
  });

  group('general-029 and general-025 are two records, not one repeated', () {
    test('their texts differ and neither contains the other', () {
      final a = _ar('moia-mukhtasar-1446-general-029');
      final b = _ar('moia-mukhtasar-1446-general-025');
      expect(a, isNot(equals(b)));
      expect(a.contains(b), isFalse);
      expect(b.contains(a), isFalse);
    });

    test('they list the same afflictions in a different printed order', () {
      final a = _ar('moia-mukhtasar-1446-general-029');
      final b = _ar('moia-mukhtasar-1446-general-025');
      // page 98: البخل before الهرم — page 97: الهرم before البخل
      expect(a.indexOf('الْبُخْلِ') < a.indexOf('الْهَرَمِ'), isTrue);
      expect(b.indexOf('الْهَرَمِ') < b.indexOf('الْبُخْلِ'), isTrue);
    });

    test('-029 carries a whole passage -025 does not', () {
      expect(
          _ar('moia-mukhtasar-1446-general-029')
              .contains('آتِ نَفْسِي تَقْوَاهَا'),
          isTrue);
      expect(
          _ar('moia-mukhtasar-1446-general-025')
              .contains('آتِ نَفْسِي تَقْوَاهَا'),
          isFalse);
    });

    test('both spell «مِنَ الْعَجْزِ» with a fatha, as both pages print it',
        () {
      for (final id in [
        'moia-mukhtasar-1446-general-029',
        'moia-mukhtasar-1446-general-025'
      ]) {
        expect(_ar(id).contains('مِنَ الْعَجْزِ'), isTrue, reason: id);
      }
    });
  });

  group('the source\'s spellings of «اللهم» survive across both pages', () {
    test('-026 keeps its lam without shadda', () {
      final w = _ar('moia-mukhtasar-1446-general-026').split(' ').first;
      expect(w.endsWith('م$kFatha$kShadda'), isTrue,
          reason: 'mim carries fatha + shadda');
      expect(w.contains('ل$kShadda'), isFalse,
          reason: 'the lam has no shadda — that is what makes -026 a third '
              'spelling, and it must not be normalised to its neighbours');
    });

    test('the three page-98 openings are not all identical', () {
      final f026 = _ar('moia-mukhtasar-1446-general-026').split(' ').first;
      final f027 = _ar('moia-mukhtasar-1446-general-027').split(' ').first;
      expect(f026, isNot(equals(f027)));
    });
  });

  group('the batch changed nothing about deployment', () {
    test('every record in it stays unverified', () {
      for (final id in [...kPage98, kTaqsirShamil, kTaqsirMara]) {
        expect(_entry(id)['verificationStatus'], 'unverified', reason: id);
        expect(_entry(id)['contentHash'], isNull, reason: id);
        expect(_reviews()[id]!['deploymentBlocked'], isFalse, reason: id);
      }
    });

    test('the pack is still 85 unverified records', () {
      final all = _entries();
      expect(all.length, 85);
      expect(all.every((e) => e['verificationStatus'] == 'unverified'), isTrue);
    });
  });
}
