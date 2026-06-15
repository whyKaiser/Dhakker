import 'package:dhakker/shared/data/hajj_zones_seed.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dhakker/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  });

  testWidgets('Seed Hajj zones to Firestore', (tester) async {
    final result = await HajjZonesSeed.seedToFirestore();
    final added = result['added'] ?? 0;
    final skipped = result['skipped'] ?? 0;
    final total = added + skipped;

    debugPrint('✅ Zones seeded: added=$added, skipped=$skipped, total=$total');

    expect(total, equals(HajjZonesSeed.zones.length),
        reason: 'Total zones in Firestore should match seed list (${HajjZonesSeed.zones.length})');
  });
}
