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
