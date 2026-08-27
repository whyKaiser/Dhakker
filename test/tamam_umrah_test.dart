// umrah-tamam-umrah — the last of the page-74 records, and the slowest to
// settle.
//
// Two marks were wrong in opposite directions. The record carried a shadda on
// «حِلًّا» that the page does not print, and it lacked a fatha on «جميعَ»
// that the page does. Both are now corrected; the record's length is
// unchanged, because one code point left and one arrived.
//
// The shadda took the longest because the obvious check was unavailable: no
// word anywhere in the accessible pages combines a shadda with tanwin fath,
// so there was nothing to show what the two look like when they collide and
// merge. What settled it instead was the negative reading. Above «حِلاً» sit
// exactly two marks — a pair of parallel bars of identical size (the tanwin)
// and a kasra below — and nothing with the shadda's signature, which on this
// same page and in this same size is a squat notched glyph roughly half as
// elongated (compare the shadda in «يعمُّ» one line up). Two equal separate
// bars are also not what a merge produces. «جدًا» on page 103 is printed
// without a shadda too, which corroborates but did not decide it — the page
// itself did.
//
// Deliberately NOT changed, and pinned so: the tanwin sits over the alef in
// the print and over the preceding letter in the record. That is a question
// about encoding, and the page is an image with no encoding to read — a font
// may well draw a mark bound to one letter above the next. Same for the dash
// characters in taqsir-mara: no declared normalisation rule, no change.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const String kTamam = 'moia-mukhtasar-1446-umrah-tamam-umrah';

const String kShadda = 'ّ';
const String kFatha = 'َ';
const String kFathatan = 'ً';

/// sha256(text.ar + U+0000 + text.en) of the corrected, reviewed text.
const String kHash =
    '406da1bc6300bc40dedac79854fb3fd875fa566379ff5ce0b58a30cc9a0a678d';

List<Map<String, dynamic>> _entries() => ((jsonDecode(
      File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
    ) as Map<String, dynamic>)['entries'] as List)
        .cast<Map<String, dynamic>>();

Map<String, dynamic> _entry(String id) =>
    _entries().firstWhere((e) => e['duaId'] == id);

String _ar(String id) => _entry(id)['text']['ar'] as String;

Map<String, dynamic> _review(String id) =>
    ((jsonDecode(File('review/human_review_ledger.json').readAsStringSync())
            as Map<String, dynamic>)['reviews'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((r) => r['recordId'] == id);

void main() {
  group('the shadda the page does not print stays gone', () {
    test('«حِلًا» has a tanwin and no shadda', () {
      final t = _ar(kTamam);
      expect(t.contains('حِلًا'), isTrue, reason: 'as page 74 prints it');
      expect(t.contains('حِلًّا'), isFalse,
          reason: 'the shadda was never on the page');
    });

    test('no shadda survives anywhere in the record', () {
      // Blunt but exact: this text has no doubled consonant at all, so any
      // shadda reappearing is a regression rather than a legitimate edit.
      expect(_ar(kTamam).contains(kShadda), isFalse);
    });

    test('the tanwin itself was not touched', () {
      expect(_ar(kTamam).contains(kFathatan), isTrue,
          reason: 'removing the shadda must not take the tanwin with it');
    });
  });

  group('the fatha the page does print is now there', () {
    test('«جميعَ» carries a fatha on the ain', () {
      expect(_ar(kTamam).contains('جميعَ محظورات'), isTrue);
      expect(_ar(kTamam).contains('جميع محظورات'), isFalse,
          reason: 'the bare form was the transcription error');
    });
  });

  group('nothing else in the record moved', () {
    test('the length is unchanged — one mark out, one mark in', () {
      expect(_ar(kTamam).length, 80);
    });

    test('the tanwin position is left exactly as stored', () {
      // The print draws it over the alef; the record binds it to the letter
      // before. An image cannot settle an encoding question, so this is
      // pinned as-is rather than "fixed" toward what the glyph looks like.
      expect(_ar(kTamam).contains('كاملًا'), isTrue);
      expect(_ar(kTamam).contains('كاملاً'), isFalse);
    });

    test('it still ends on the book\'s own full stop', () {
      expect(_ar(kTamam).endsWith('الإحرامِ.'), isTrue);
    });

    test('no printing apparatus was absorbed', () {
      final t = _ar(kTamam);
      expect(t.contains('('), isFalse);
      expect(t.contains(')'), isFalse);
      expect(t, equals(t.trim()));
    });
  });

  group('the review is recorded and claims only what was checked', () {
    test('passed on page 74, corrected, no takhrij', () {
      final r = _review(kTamam);
      expect(r['reviewStatus'], 'passed');
      expect(r['reviewedPage'], 74);
      expect(r['transcriptionCorrected'], isTrue);
      expect(r['sourceReferencesReviewStatus'], 'reviewed_none');
      expect((_entry(kTamam)['sourceReferences'] as List), isEmpty);
    });

    test('the hash matches the corrected file', () {
      final t = _entry(kTamam)['text'] as Map<String, dynamic>;
      final h =
          sha256.convert(utf8.encode('${t['ar']}\u0000${t['en']}')).toString();
      expect(h, kHash);
      expect(_review(kTamam)['reviewedTextHash'], kHash);
    });

    test('the note names both sites and the evidence for each', () {
      final n = _review(kTamam)['transcriptionNote'] as String;
      expect(n, contains('U+0651'));
      expect(n, contains('U+064E'));
      expect(n, contains('يعمُّ'), reason: 'the same-page shadda control');
      expect(n, contains('جدًا'), reason: 'named as corroboration only');
      expect(n, contains('قرينةً مساندة'),
          reason: 'page 103 must not read as the basis for the change');
    });

    test('the record stays unverified and unheld', () {
      expect(_entry(kTamam)['verificationStatus'], 'unverified');
      expect(_review(kTamam)['deploymentBlocked'], isFalse);
    });
  });

  group('page 74 is now fully reviewed', () {
    test('all four of its records have entries', () {
      final ids = _entries()
          .where((e) => e['printedPage'] == 74)
          .map((e) => e['duaId'] as String)
          .toList();
      expect(ids, hasLength(4));
      for (final id in ids) {
        expect(() => _review(id), returnsNormally, reason: id);
        expect(_review(id)['reviewedPage'], 74, reason: id);
      }
    });
  });
}
