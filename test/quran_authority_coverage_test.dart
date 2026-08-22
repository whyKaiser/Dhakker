// Every Quranic text in the pack must carry Quran authority metadata.
//
// Two records escaped the U5 audit entirely — `tawaf-between-corners`
// (2:201) and `safa-ayah` (2:158) — because the audit ran over records that
// already carried `quranRef`, and neither did. They held the same verses as
// audited records but in plain imlaa'i script, never compared to anything.
//
// A checklist cannot catch that; only a rescan of the whole pack can. This
// test is that rescan, and it fails CI rather than waiting to be noticed.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Duas/widgets/content_kind_card.dart';
import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';

const _packPath = 'source_packs/moia_mukhtasar_1446_umrah.json';
const _kfPath = 'third_party/kfgqpc/hafsData_v2-0.json';

/// Letters only, with the hamza/alef forms folded together, so a difference
/// of *script* does not hide a match of *wording*. Folding is what the
/// original scan lacked: «رَبَّنَآ» and «رَبَّنَا» differ by one code point
/// and are the same word.
String _fold(String t) {
  const map = {
    'آ': 'ا',
    'أ': 'ا',
    'إ': 'ا',
    'ٱ': 'ا',
    'ى': 'ي',
    'ة': 'ه',
    'ؤ': 'و',
    'ئ': 'ي',
  };
  final buf = StringBuffer();
  for (final ch in t.split('')) {
    if (RegExp(r'[ء-يٱ]').hasMatch(ch)) buf.write(map[ch] ?? ch);
  }
  return buf.toString();
}

String _stripMarker(String t) => t.replaceAll(RegExp(r'[ﭐ-﷿ﹰ-﻿]+$'), '').trim();

void main() {
  final pack =
      jsonDecode(File(_packPath).readAsStringSync()) as Map<String, dynamic>;
  final entries = (pack['entries'] as List).cast<Map<String, dynamic>>();

  final rows = (jsonDecode(File(_kfPath).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  String ayah(int s, int a) => _stripMarker(rows.firstWhere((r) =>
      int.parse('${r['sura_no']}') == s &&
      int.parse('${r['aya_no']}') == a)['aya_text'] as String);

  final corpus = rows.map((r) => _fold(r['aya_text'] as String)).join(' | ');

  const authorityFields = [
    'textAuthority',
    'textAuthoritySourceUrl',
    'textRiwayah',
    'textRasm',
    'textEdition',
    'textEditionDate',
  ];

  group('no Quranic text escapes the authority audit', () {
    test('every record whose wording is Quranic declares a quranRef', () {
      final escaped = <String>[];
      for (final e in entries) {
        if (e['quranRef'] != null) continue;
        final folded = _fold(e['text']['ar'] as String);
        // Short fragments would match by accident («الله أكبر» appears in
        // the Quran); the audit targets substantial excerpts.
        if (folded.length < 20) continue;
        if (corpus.contains(folded)) escaped.add(e['duaId'] as String);
      }
      expect(escaped, isEmpty,
          reason: 'these records hold Quranic wording with no Quran authority '
              'metadata, so nothing ever compared them to the official text');
    });

    test('every record with a quranRef carries the full authority block', () {
      for (final e in entries) {
        if (e['quranRef'] == null) continue;
        for (final f in authorityFields) {
          expect((e[f] ?? '').toString().trim(), isNotEmpty,
              reason: '${e['duaId']} has a quranRef but no $f');
        }
        expect(e['isPortionOfAyah'], isNotNull);
        // The edition must be the pinned one, not some other mushaf.
        expect(e['textEdition'], 'KFGQPC Hafs Uthmanic Data v2.0');
      }
    });
  });

  group('the two rescued records match the pinned file exactly', () {
    Map<String, dynamic> entry(String id) =>
        entries.firstWhere((e) => e['duaId'] == id);

    test('tawaf-between-corners is a verbatim slice of 2:201', () {
      final e = entry('moia-mukhtasar-1446-tawaf-between-corners');
      expect(e['quranRef'], {
        'surah': 2,
        'ayat': [201]
      });
      expect(e['isPortionOfAyah'], isTrue);
      final official = ayah(2, 201);
      expect(official.contains(e['text']['ar'] as String), isTrue,
          reason: 'the stored text is not a contiguous slice of the official '
              'ayah — it was transcribed, not derived');
    });

    test('safa-ayah is a verbatim slice of 2:158', () {
      final e = entry('moia-1446-safa-ayah');
      expect(e['quranRef'], {
        'surah': 2,
        'ayat': [158]
      });
      expect(e['isPortionOfAyah'], isTrue);
      expect(ayah(2, 158).contains(e['text']['ar'] as String), isTrue);
    });

    test('both now carry the Uthmani rasm, code point for code point', () {
      // The defect was a script difference, so the assertion has to be at
      // code-point level: U+06E1 (Uthmani sukun) not U+0652, U+0657 not
      // U+064B. A "looks right" check would have passed before the fix.
      for (final id in [
        'moia-mukhtasar-1446-tawaf-between-corners',
        'moia-1446-safa-ayah',
      ]) {
        final text = entry(id)['text']['ar'] as String;
        expect(text.contains('ْ'), isFalse,
            reason: '$id still contains a plain sukun');
        expect(text.contains('ً'), isFalse,
            reason: '$id still contains a plain fathatan');
        expect(text.contains('ٱ'), isTrue,
            reason: '$id should carry alef wasla');
      }
    });

    test('the ministry stays the context authority for both', () {
      for (final id in [
        'moia-mukhtasar-1446-tawaf-between-corners',
        'moia-1446-safa-ayah',
      ]) {
        final e = entry(id);
        expect(e['contextAuthority'], contains('وزارة الشؤون الإسلامية'));
        expect(e['authority'], contains('وزارة الشؤون الإسلامية'));
        // Text authority and context authority are different claims.
        expect(e['textAuthority'], 'مجمع الملك فهد لطباعة المصحف الشريف');
      }
    });

    test('neither is marked reviewed or verified by this change', () {
      for (final id in [
        'moia-mukhtasar-1446-tawaf-between-corners',
        'moia-1446-safa-ayah',
      ]) {
        expect(entry(id)['verificationStatus'], 'unverified');
      }
      final ledger = jsonDecode(
        File('review/human_review_ledger.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final byId = {
        for (final r
            in (ledger['reviews'] as List).cast<Map<String, dynamic>>())
          r['recordId'] as String: r
      };
      // The principle this guard exists for is unchanged: deriving text from
      // the pinned KFGQPC file is NOT a human reading a printed page, and can
      // never by itself produce a pass. What changed is the evidence — page 72
      // has now been read — so the guard checks for that evidence rather than
      // forbidding a pass outright. A pass with no page recorded still fails.
      for (final id in [
        'moia-mukhtasar-1446-tawaf-between-corners',
        'moia-1446-safa-ayah',
      ]) {
        final r = byId[id];
        if (r == null) continue;
        if (r['reviewStatus'] == 'passed') {
          final entry = entries.firstWhere((e) => e['duaId'] == id);
          expect(r['reviewedPage'], entry['printedPage'],
              reason: '$id passed without a human reading its printed page');
          expect(r['textReviewStatus'], 'passed', reason: id);
        } else {
          expect(r['textReviewStatus'], isNot('passed'), reason: id);
        }
        // Neither a pinned-file derivation nor a page reading confers
        // verification, and neither lifts the deployment hold.
        expect(r['excludedFromImport'], isTrue, reason: id);
        expect(
            entries.firstWhere((e) => e['duaId'] == id)['verificationStatus'],
            'unverified',
            reason: id);
      }
    });
  });

  group('Quran quoted inside procedural guidance', () {
    test('the Maqam snippets match the official wording, letter for letter',
        () {
      final e =
          entries.firstWhere((e) => e['duaId'] == 'moia-1446-maqam-rakatayn');
      final snippets = RegExp(r'﴿([^﴾]*)﴾')
          .allMatches(e['text']['ar'] as String)
          .map((m) => m.group(1)!)
          .toList();
      expect(snippets, hasLength(2));

      // Wording is compared folded, because the ministry prints these in
      // imlaa'i script inside its own prose. Their WORDING is the official
      // wording; their script is the ministry's. Changing the script here
      // would be editing the ministry's sentence, not correcting a quote.
      expect(_fold(snippets[0]), _fold(ayah(109, 1)));
      expect(_fold(snippets[1]), _fold(ayah(112, 1)));
    });

    test('embedded Quran does not make the whole card recitable', () {
      // The trap this guards: a procedural sentence that quotes two surahs
      // could be argued into `specific_text` because "it contains Quran".
      // It would then get a play button, and the app would read a set of
      // instructions aloud as though it were a dhikr.
      final e =
          entries.firstWhere((e) => e['duaId'] == 'moia-1446-maqam-rakatayn');
      expect(e['contentKind'], 'procedural_guidance');
      expect((e['text']['ar'] as String).contains('﴿'), isTrue,
          reason: 'the fixture must actually contain embedded Quran');

      final model = SupplicationModel.fromJson(e);
      expect(model.contentKind, SupplicationContentKind.proceduralGuidance);
      expect(model.contentKind.isRecitable, isFalse);
      expect(model.contentKind.belongsInDuaSection, isFalse);
      expect(model.isAutoPlayable, isFalse);

      // And the structured Quran references it carries change none of that.
      expect((e['sourceReferences'] as List), hasLength(2));
      expect(model.sourceReferences.map((r) => r.reference),
          containsAll(['109:1', '112:1']));
      expect(model.isAutoPlayable, isFalse);

      // It also must not be counted among the recitable texts of its zone.
      final partition = SupplicationPartition.of([model]);
      expect(partition.recitable, isEmpty);
      expect(partition.guidance, hasLength(1));
    });

    test('the ministry sentence was not rewritten', () {
      final e =
          entries.firstWhere((e) => e['duaId'] == 'moia-1446-maqam-rakatayn');
      final text = e['text']['ar'] as String;
      expect(text, startsWith('ثم صلىٰ ركعتين خلفَه'));
      expect(text, contains('يقرأ في الركعة الأولىٰ'));
    });
  });
}
