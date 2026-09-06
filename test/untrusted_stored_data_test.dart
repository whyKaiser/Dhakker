// Parsing of data this repository does not control.
//
// Firestore documents carry no schema and SharedPreferences is untyped, so a
// field can arrive as any type at all: written by an older build, edited by
// hand in the console, or simply absent. Every parser below used to perform an
// implicit downcast from `dynamic`, which the analyzer accepted silently and
// which throws on a pilgrim's device rather than in CI.
//
// Each test feeds a parser the wrong type on purpose and asserts it degrades
// to a sane value instead of throwing. They fail against the previous code:
// `(map['lat'] ?? 0).toDouble()` raises NoSuchMethodError on a String, and
// `isActive: data['isActive'] ?? true` yields a String where a bool is
// declared.

import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Home/models/zone_model.dart';

void main() {
  group('ZonePoint.fromMap survives whatever Firestore holds', () {
    test('parses ordinary numeric coordinates', () {
      final p = ZonePoint.fromMap({'lat': 21.4225, 'lng': 39.8262});
      expect(p.lat, 21.4225);
      expect(p.lng, 39.8262);
    });

    test('accepts an int where a double is expected', () {
      // Firestore stores a whole number as an integer, so a coordinate
      // entered as `21` comes back as int, not double.
      final p = ZonePoint.fromMap({'lat': 21, 'lng': 39});
      expect(p.lat, 21.0);
      expect(p.lng, 39.0);
    });

    test('parses a numeric string rather than throwing', () {
      final p = ZonePoint.fromMap({'lat': '21.4225', 'lng': '39.8262'});
      expect(p.lat, 21.4225);
      expect(p.lng, 39.8262);
    });

    test('a non-numeric or missing coordinate becomes 0, not a crash', () {
      // The polygon this feeds is drawn on the map and used for zone
      // detection. A crash here takes down the map screen entirely.
      for (final bad in <dynamic>[null, 'abcd', true, <String, dynamic>{}]) {
        final p = ZonePoint.fromMap({'lat': bad, 'lng': bad});
        expect(p.lat, 0.0, reason: 'lat from ${bad.runtimeType}');
        expect(p.lng, 0.0, reason: 'lng from ${bad.runtimeType}');
      }
    });

    test('an empty map yields the origin instead of throwing', () {
      final p = ZonePoint.fromMap({});
      expect(p.lat, 0.0);
      expect(p.lng, 0.0);
    });
  });

  group('zoneDouble / zoneDoubleOrNull', () {
    test('null is absent, not zero, when absence is representable', () {
      expect(zoneDoubleOrNull(null), isNull);
      expect(zoneDouble(null), 0.0);
    });

    test('numbers pass through and strings are parsed', () {
      expect(zoneDoubleOrNull(5), 5.0);
      expect(zoneDoubleOrNull(5.5), 5.5);
      expect(zoneDoubleOrNull('5.5'), 5.5);
      expect(zoneDoubleOrNull('not a number'), isNull);
    });
  });

  group('zoneBool refuses to trust a stored flag', () {
    test('a real boolean is honoured', () {
      expect(zoneBool(true), isTrue);
      expect(zoneBool(false), isFalse);
    });

    test('anything else falls back rather than being cast', () {
      // The string "false" is the dangerous case: truthy as a value, and
      // an outright type error where a bool is declared.
      for (final bad in <dynamic>[null, 'false', 'true', 0, 1, <String>[]]) {
        expect(zoneBool(bad), isTrue, reason: 'fallback for $bad');
        expect(zoneBool(bad, fallback: false), isFalse,
            reason: 'explicit fallback for $bad');
      }
    });
  });
}
