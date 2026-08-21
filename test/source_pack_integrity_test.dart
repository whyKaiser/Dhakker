// Source-pack integrity tests.
//
// These read the committed source pack and coverage matrix as data and
// enforce the rules that keep the pack honest. They are the automated half
// of the manual review — they cannot judge whether a transcription is
// faithful to the printed page (only a human reading the paper can), but
// they CAN prove that no place-specific text has been reassigned to a place
// the source never tied it to, that nothing claims to be verified, and that
// no placeholder survived into a record a pilgrim could be shown.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/shared/data/hajj_zones_seed.dart';

Map<String, dynamic> _readJson(String path) {
  // Read at top level (outside any test body), so `expect` is unavailable
  // here — a missing pack is a hard failure of the whole suite.
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('missing source pack: $path');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final pack = _readJson('source_packs/moia_mukhtasar_1446_umrah.json');
  final matrix = _readJson('source_packs/moia_zone_coverage_matrix.json');

  final entries = (pack['entries'] as List).cast<Map<String, dynamic>>();
  final matrixZones = (matrix['zones'] as List).cast<Map<String, dynamic>>();

  final seedZoneKeys = HajjZonesSeed.zones
      .map((z) => (z['zoneKey'] ?? '').toString())
      .where((k) => k.isNotEmpty)
      .toSet();

  const knownKinds = {
    'specific_text',
    'general_dua',
    'general_dhikr',
    'mosque_entry',
    'procedural_guidance',
    // A narration cited to teach rather than to be recited — see
    // test/content_kind_batch_b_test.dart.
    'contextual_evidence',
  };

  group('pack structure', () {
    test('every entry carries an explicit zoneKey', () {
      // Explicit is the point: an absent key cannot be told apart from a
      // forgotten one. "" is how the pack says "not tied to any one place".
      for (final e in entries) {
        expect(e.containsKey('zoneKey'), isTrue,
            reason: '${e['duaId']} has no zoneKey field');
      }
    });

    test('every non-empty zoneKey names a zone that exists in the seed', () {
      for (final e in entries) {
        final key = (e['zoneKey'] ?? '').toString();
        if (key.isEmpty) continue;
        expect(seedZoneKeys, contains(key),
            reason: '${e['duaId']} points at unknown zone "$key"');
      }
    });

    test('every entry has a known contentKind', () {
      for (final e in entries) {
        expect(knownKinds, contains(e['contentKind']),
            reason: '${e['duaId']} has contentKind ${e['contentKind']}');
      }
    });

    test('duaIds are unique', () {
      final ids = entries.map((e) => e['duaId'].toString()).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('nothing is citable before a human verifies it', () {
    test('every record is unverified, unsigned and not revoked', () {
      for (final e in entries) {
        expect(e['verificationStatus'], 'unverified', reason: '${e['duaId']}');
        expect(e['verifiedAt'], isNull, reason: '${e['duaId']}');
        expect(e['verifiedBy'], isNull, reason: '${e['duaId']}');
        expect(e['revokedAt'], isNull, reason: '${e['duaId']}');
      }
    });

    test('the pack itself is not marked approved', () {
      expect(pack['packStatus'].toString().toLowerCase(),
          isNot(contains('verified')));
    });
  });

  group('no placeholders reach a pilgrim', () {
    final placeholder = RegExp(
      r'REPLACE|TODO|TBD|PLACEHOLDER|LOREM|XXX|\{\{|<<',
      caseSensitive: false,
    );

    test('no entry contains placeholder markers', () {
      for (final e in entries) {
        final blob = jsonEncode(e);
        expect(placeholder.hasMatch(blob), isFalse,
            reason: '${e['duaId']} still contains a placeholder');
      }
    });

    test('every entry has non-empty Arabic title and text', () {
      for (final e in entries) {
        final title = ((e['title'] as Map)['ar'] ?? '').toString().trim();
        final text = ((e['text'] as Map)['ar'] ?? '').toString().trim();
        expect(title, isNotEmpty, reason: '${e['duaId']} title');
        expect(text, isNotEmpty, reason: '${e['duaId']} text');
      }
    });
  });

  group('no cross-zone assignment of place-specific text', () {
    final byId = {for (final e in entries) e['duaId'].toString(): e};

    /// The set of zones a place-specific text may legitimately appear at.
    ///
    /// Normally that is exactly one zone (`zoneKey`). A few texts are tied by
    /// the source to a RITUAL that spans several zones rather than to one
    /// spot — the Talbiyah is prescribed on entering ihram, and the app
    /// records three miqats. Those declare `appliesToZoneKeys` explicitly.
    /// The list is an enumeration of what the source already covers, never a
    /// licence to spread a text somewhere the source did not put it.
    Set<String> allowedZones(Map<String, dynamic> entry) {
      final declared = (entry['appliesToZoneKeys'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          <String>{};
      final own = (entry['zoneKey'] ?? '').toString();
      return {...declared, if (own.isNotEmpty) own};
    }

    test('a ritual-scoped text lists only zones that exist in the seed', () {
      for (final e in entries) {
        final declared = (e['appliesToZoneKeys'] as List?) ?? const [];
        if (declared.isEmpty) continue;
        expect(e['ritualKey'].toString().trim(), isNotEmpty,
            reason: '${e['duaId']} spans zones without naming the ritual');
        for (final key in declared) {
          expect(seedZoneKeys, contains(key.toString()),
              reason: '${e['duaId']} lists unknown zone "$key"');
        }
      }
    });

    test('the matrix only references duas that exist in the pack', () {
      for (final zone in matrixZones) {
        for (final item in (zone['items'] as List)) {
          expect(byId, contains((item as Map)['duaId']),
              reason: 'zone ${zone['zoneKey']} references an unknown dua');
        }
      }
    });

    test('a specific_text dua appears ONLY under its own zone', () {
      // This is the central guard. A text the source ties to the Black Stone
      // must never surface at Zamzam — not as "specific", and not at all.
      for (final zone in matrixZones) {
        final zoneKey = zone['zoneKey'].toString();
        for (final item in (zone['items'] as List).cast<Map>()) {
          final entry = byId[item['duaId'].toString()]!;
          if (entry['contentKind'] != 'specific_text') continue;

          final allowed = allowedZones(entry);
          expect(allowed, isNotEmpty,
              reason: '${entry['duaId']} is specific_text with no owning zone, '
                  'so it cannot be placed at "$zoneKey"');
          expect(allowed, contains(zoneKey),
              reason: '${entry['duaId']} belongs to $allowed but the '
                  'matrix places it at "$zoneKey"');
        }
      }
    });

    test('an item is only marked basis=specific when the source ties it here',
        () {
      for (final zone in matrixZones) {
        final zoneKey = zone['zoneKey'].toString();
        for (final item in (zone['items'] as List).cast<Map>()) {
          if (item['basis'] != 'specific') continue;
          final entry = byId[item['duaId'].toString()]!;
          expect(allowedZones(entry), contains(zoneKey),
              reason: '${entry['duaId']} is claimed as specific to "$zoneKey" '
                  'but the pack does not tie it there');
        }
      }
    });

    test('a general or mosque_entry item is never claimed as specific', () {
      for (final zone in matrixZones) {
        for (final item in (zone['items'] as List).cast<Map>()) {
          final entry = byId[item['duaId'].toString()]!;
          final kind = entry['contentKind'].toString();
          if (kind == 'general_dua' ||
              kind == 'general_dhikr' ||
              kind == 'mosque_entry') {
            expect(item['basis'], isNot('specific'),
                reason: '${entry['duaId']} ($kind) is claimed as specific to '
                    '${zone['zoneKey']}');
          }
        }
      }
    });

    test('Zamzam and the Kaaba carry no place-specific text', () {
      // The transcribed pages contain no text the source ties to either
      // place. Until a page that does is transcribed, any "specific" entry
      // appearing here would be fabricated attribution.
      for (final key in ['zamzam', 'kaaba']) {
        final zone = matrixZones.firstWhere((z) => z['zoneKey'] == key);
        expect(zone['specificAvailable'], 0, reason: key);
        for (final item in (zone['items'] as List).cast<Map>()) {
          expect(item['basis'], isNot('specific'),
              reason: '$key: ${item['duaId']} claims a specific basis');
          expect(byId[item['duaId'].toString()]!['contentKind'],
              isNot('specific_text'),
              reason: '$key: ${item['duaId']} is place-specific text');
        }
      }
    });
  });

  group('no per-circuit supplication is implied', () {
    test('the pack records the source forbidding per-circuit duas', () {
      final hits = entries.where((e) =>
          e['contentKind'] == 'procedural_guidance' &&
          jsonEncode(e).contains('شوط'));
      expect(hits, isNotEmpty,
          reason: 'the p70/p73 prohibition must remain in the pack');
    });

    test('no UI string offers a dua for a numbered circuit', () {
      // Guards the app's own copy, not just the source data: a heading like
      // «دعاء الشوط الأول» would imply a per-circuit supplication exists.
      // The source calls that «عمل محدث، وبدعة منكرة لا تجوز» (p70, p73).
      //
      // Numbering a circuit is itself fine — the tawaf/sa'i counter has to
      // do it. What must never appear is a circuit number PAIRED WITH a
      // supplication, so the pattern requires both.
      final offending = RegExp(
        'دعاء الشوط|أدعية الأشواط|دعاء كل شوط|ذكر الشوط'
        '|(دعاء|أدعية|ذكر)[^\\n]{0,20}الشوط (الأول|الثاني|الثالث|الرابع'
        '|الخامس|السادس|السابع)',
      );

      final offenders = <String>[];
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final content = file.readAsStringSync();
        for (final match in offending.allMatches(content)) {
          offenders.add('${file.path}: ${match.group(0)}');
        }
      }

      expect(offenders, isEmpty);
    });

    test('no entry title numbers a circuit', () {
      // e.g. «دعاء الشوط الأول» — the source calls that «بدعة منكرة».
      final numbered = RegExp('الشوط (الأول|الثاني|الثالث|الرابع|الخامس'
          '|السادس|السابع)');
      for (final e in entries) {
        final title = ((e['title'] as Map)['ar'] ?? '').toString();
        expect(numbered.hasMatch(title), isFalse,
            reason: '${e['duaId']}: "$title" implies a per-circuit dua');
      }
    });
  });
}
