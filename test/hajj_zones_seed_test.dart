import 'package:dhakker/shared/data/hajj_zones_seed.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HajjZonesSeed', () {
    test('seeds all zones to Firestore with correct count', () async {
      final fakeDb = FakeFirebaseFirestore();

      final result = await HajjZonesSeed.seedToFirestore(fakeDb);

      expect(result['added'], equals(HajjZonesSeed.zones.length));
      expect(result['skipped'], equals(0));

      final snapshot = await fakeDb.collection('zones').get();
      expect(snapshot.docs.length, equals(HajjZonesSeed.zones.length));
    });

    test('skips duplicate zones on second run', () async {
      final fakeDb = FakeFirebaseFirestore();

      await HajjZonesSeed.seedToFirestore(fakeDb);
      final second = await HajjZonesSeed.seedToFirestore(fakeDb);

      expect(second['added'], equals(0));
      expect(second['skipped'], equals(HajjZonesSeed.zones.length));

      // العدد في Firestore لم يتغير
      final snapshot = await fakeDb.collection('zones').get();
      expect(snapshot.docs.length, equals(HajjZonesSeed.zones.length));
    });

    test('every zone has required fields', () {
      for (final zone in HajjZonesSeed.zones) {
        expect(zone['nameAr'], isA<String>(), reason: '${zone['nameEn']} missing nameAr');
        expect(zone['nameEn'], isA<String>(), reason: 'zone missing nameEn');
        expect(zone['type'], anyOf('circle', 'polygon'), reason: '${zone['nameEn']} bad type');
        expect(zone['isActive'], isTrue, reason: '${zone['nameEn']} should be active');

        if (zone['type'] == 'circle') {
          expect(zone['center'], isNotNull, reason: '${zone['nameEn']} circle needs center');
          expect(zone['radiusM'], isA<double>(), reason: '${zone['nameEn']} circle needs radiusM');
        } else {
          expect(zone['points'], isA<List>(), reason: '${zone['nameEn']} polygon needs points');
          expect((zone['points'] as List).length, greaterThanOrEqualTo(3),
              reason: '${zone['nameEn']} polygon needs ≥3 points');
        }
      }
    });

    test('zone count matches expected 19', () {
      expect(HajjZonesSeed.zones.length, equals(19));
    });
  });
}
