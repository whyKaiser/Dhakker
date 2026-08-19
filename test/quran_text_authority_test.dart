// Quranic text authority tests (U5 / U12).
//
// 23 records in the MOIA source pack quote the Qur'an. Their text was
// transcribed by eye from scans of the printed page, which is exactly the
// method that cannot settle a question about a superscript yā' or a waqf
// mark. The resolution is to make the official digital text published by
// مجمع الملك فهد لطباعة المصحف الشريف (Hafs ʿan ʿĀṣim, Uthmani rasm) the
// authority for the TEXT, while the Ministry's book remains the authority
// for CONTEXT — which āyah belongs to which rite, and on what page.
//
// These tests enforce the split. They are deliberately written so that the
// comparison cannot pass by being skipped: as soon as
// `source_packs/quran_authority_hafs_uthmani.json` carries fetched text, or
// as soon as any record claims a text authority, the character-by-character
// comparison becomes binding.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _manifestPath = 'source_packs/quran_authority_hafs_uthmani.json';
const _packPath = 'source_packs/moia_mukhtasar_1446_umrah.json';
const _kfcAuthority = 'مجمع الملك فهد لطباعة المصحف الشريف';

Map<String, dynamic> _readJson(String path) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('missing $path');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final manifest = _readJson(_manifestPath);
  final pack = _readJson(_packPath);

  final ayat = (manifest['ayat'] as List).cast<Map<String, dynamic>>();
  final entries = (pack['entries'] as List).cast<Map<String, dynamic>>();
  final byId = {for (final e in entries) e['duaId'].toString(): e};

  group('the manifest describes the right records', () {
    test('all 23 Quranic records are enumerated', () {
      expect(ayat.length, 23);
    });

    test('every referenced record exists in the pack', () {
      for (final a in ayat) {
        expect(byId, contains(a['duaId']),
            reason: '${a['duaId']} is not in the source pack');
      }
    });

    test('each entry names a surah, at least one ayah, and a context page', () {
      for (final a in ayat) {
        expect(a['surahNumber'], isA<int>());
        expect(a['surahNumber'], inInclusiveRange(1, 114));
        expect((a['ayahNumbers'] as List), isNotEmpty);
        expect(a['contextPrintedPage'], isA<int>(),
            reason: '${a['duaId']} has no page in the Ministry book');
        expect(['U5', 'U12'], contains(a['uncertainty']));
      }
    });

    test('provenance of the text authority is fully declared', () {
      expect(manifest['textAuthority'], _kfcAuthority);
      expect(manifest['riwayah'], 'حفص عن عاصم');
      expect(manifest['rasm'], 'الرسم العثماني');
      expect(manifest['textAuthoritySourceUrl'].toString(),
          startsWith('https://qurancomplex.gov.sa'));
      // The context authority stays the Ministry's book — the two sources
      // answer different questions and must not be conflated.
      expect(manifest['contextAuthority'].toString(), contains('الشؤون'));
      expect(manifest['contextSourceUrl'].toString(),
          startsWith('https://ebook.moia.gov.sa'));
    });
  });

  group('no record may claim an authority that was never checked', () {
    // This is the invariant that holds RIGHT NOW, while the official text is
    // not yet in the repository. It is what stops the gap from being papered
    // over with a provenance claim nobody verified.
    test('a record claiming KFC text authority must have fetched text', () {
      for (final e in entries) {
        final claimed = (e['textAuthority'] ?? '').toString().trim();
        if (claimed.isEmpty) continue;

        expect(claimed, _kfcAuthority,
            reason: '${e['duaId']} names an unexpected text authority');

        final entry = ayat.firstWhere((a) => a['duaId'] == e['duaId'],
            orElse: () => <String, dynamic>{});
        expect(entry, isNotEmpty,
            reason: '${e['duaId']} claims Quranic authority but is not in '
                'the manifest');
        expect(entry['fetched'], isTrue,
            reason: '${e['duaId']} claims $_kfcAuthority but that text was '
                'never fetched from the official platform');
      }
    });

    test('the manifest cannot be marked fetched while text is missing', () {
      if (manifest['status'] != 'fetched') return;
      for (final a in ayat) {
        expect(a['fetched'], isTrue, reason: '${a['duaId']}');
        expect((a['officialText'] ?? '').toString().trim(), isNotEmpty,
            reason: '${a['duaId']}');
      }
      expect((manifest['editionLabel'] ?? '').toString().trim(), isNotEmpty,
          reason: 'a fetched text must record which edition it came from');
      expect(manifest['fetchedAt'], isNotNull);
    });

    test('no āyah carries text without being marked fetched', () {
      // Guards the reverse direction: text appearing in the manifest by any
      // route other than the fetch script (a hand edit, a paste) leaves
      // `fetched` false and is caught here.
      for (final a in ayat) {
        final hasText = (a['officialText'] ?? '').toString().trim().isNotEmpty;
        expect(hasText, a['fetched'] == true,
            reason: '${a['duaId']}: officialText and fetched disagree — text '
                'must only ever be written by the fetch script');
      }
    });
  });

  group('against the pinned official KFGQPC data', () {
    // The comparison is re-derived here from the official file committed at
    // third_party/kfgqpc/hafsData_v2-0.json, not merely from the manifest —
    // so the manifest cannot drift away from the authority it claims.
    const dataPath = 'third_party/kfgqpc/hafsData_v2-0.json';

    final official = (jsonDecode(File(dataPath).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    final byRef = {
      for (final r in official) '${r['sura_no']}:${r['aya_no']}': r,
    };

    // The official aya_text ends with the āyah-number glyph, a character in
    // the Arabic Presentation Forms block. It is normally preceded by
    // U+00A0 — but not always: 2:286 uses a plain space, and read.me records
    // a v2.0 fix to that very āyah. So strip the glyph and then trailing
    // whitespace of either kind rather than assuming one separator. Nothing
    // else is touched: no character or diacritic is normalised.
    String stripAyahMark(String text) {
      var t = text.trim();
      while (t.isNotEmpty) {
        final c = t.codeUnitAt(t.length - 1);
        final isTrailing = (c >= 0xFB50 && c <= 0xFDFF) ||
            (c >= 0xFE70 && c <= 0xFEFF) ||
            c == 0x00A0 ||
            c == 0x0020;
        if (!isTrailing) break;
        t = t.substring(0, t.length - 1);
      }
      return t;
    }

    test('the pinned file is the v2.0 dataset', () {
      expect(official.length, 6236);
      expect(manifest['editionLabel'], 'KFGQPC Hafs Uthmanic Data v2.0');
      expect(manifest['editionDate'], '2022-09-07');
    });

    test('every stored text is a verbatim span of the official aya_text', () {
      for (final a in ayat) {
        final parts = <String>[];
        for (final n in (a['ayahNumbers'] as List)) {
          final row = byRef['${a['surahNumber']}:$n'];
          expect(row, isNotNull,
              reason: '${a['duaId']}: ${a['surahNumber']}:$n not in the '
                  'official dataset');
          parts.add((row!['aya_text'] as String).trim());
        }
        final full = stripAyahMark(parts.join(' '));

        expect(a['officialFullAyahText'], full,
            reason: '${a['duaId']}: manifest full āyah differs from the '
                'official dataset');

        final stored = (a['officialText'] as String);
        // Verbatim span: every code point comes from the official string.
        expect(full.contains(stored), isTrue,
            reason: '${a['duaId']}: stored text is not a contiguous span of '
                'the official āyah — it must never be hand-assembled');
        expect(a['isPortionOfAyah'], stored != full, reason: '${a['duaId']}');
      }
    });

    test('the source pack carries exactly the official span', () {
      for (final a in ayat) {
        final recorded =
            ((byId[a['duaId']]!['text'] as Map)['ar'] ?? '').toString();
        expect(recorded, a['officialText'], reason: '${a['duaId']}');
      }
    });

    test('each record declares the full provenance split', () {
      for (final a in ayat) {
        final e = byId[a['duaId']]!;
        expect(e['textAuthority'], _kfcAuthority);
        expect(e['textRiwayah'], 'حفص عن عاصم');
        expect(e['textRasm'], 'الرسم العثماني');
        expect(e['textEdition'], 'KFGQPC Hafs Uthmanic Data v2.0');
        expect(e['textAuthoritySourceUrl'].toString(),
            startsWith('https://qurancomplex.gov.sa'));
        // Context stays with the Ministry, with its printed page.
        expect(e['contextSourceUrl'].toString(),
            startsWith('https://ebook.moia.gov.sa'));
        expect(e['printedPage'], a['contextPrintedPage']);
        // Still not verified — that remains a human act.
        expect(e['verificationStatus'], 'unverified');
      }
    });
  });

  group('character-by-character comparison', () {
    // Binding as soon as the official text is present. Until then each
    // record is reported as PENDING rather than passing: an unfetched āyah
    // is an open question, never a silent success.
    test('every fetched āyah matches the record exactly', () {
      final pending = <String>[];
      var compared = 0;

      for (final a in ayat) {
        final official = (a['officialText'] ?? '').toString();
        if (a['fetched'] != true || official.trim().isEmpty) {
          pending.add(a['duaId'].toString());
          continue;
        }

        final recorded =
            ((byId[a['duaId']]!['text'] as Map)['ar'] ?? '').toString();

        // No normalisation: the whole point of U5/U12 is that the code
        // points differ. Comparing normalised forms would hide exactly the
        // defect being hunted.
        expect(recorded, official,
            reason: '${a['duaId']} (سورة ${a['surahNumber']} '
                'آية ${(a['ayahNumbers'] as List).join('،')}) differs from '
                'the official text');
        compared++;
      }

      if (pending.isNotEmpty) {
        // ignore: avoid_print
        print('PENDING official text (${pending.length}/${ayat.length}): '
            '${pending.join(', ')}');
      }
      expect(compared + pending.length, ayat.length);
    });
  });
}
