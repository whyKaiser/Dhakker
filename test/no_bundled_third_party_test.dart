// The pinned KFGQPC data must never reach a pilgrim's phone.
//
// `third_party/kfgqpc/hafsData_v2-0.json` is 3.5 MB of reference data used
// by tests and by the rebuild script. It is third-party data, not this
// project's, and shipping it would both inflate every download and
// redistribute a publisher's dataset inside an app binary.
//
// Flutter bundles two things: code reachable from `lib/`, and paths declared
// under `flutter: assets:` in pubspec.yaml. These tests check both doors.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('third_party is reference-only, never bundled', () {
    test('the pinned data exists and is the file the tests expect', () {
      final data = File('third_party/kfgqpc/hafsData_v2-0.json');
      expect(data.existsSync(), isTrue);
      // Guards against the file being emptied or replaced by a stub — the
      // comparison tests would otherwise pass against nothing.
      expect(data.lengthSync(), greaterThan(3 * 1024 * 1024));
    });

    test('the publisher\'s own read.me and the provenance note are kept', () {
      expect(File('third_party/kfgqpc/README.kfgqpc.txt').existsSync(), isTrue,
          reason: 'the KFGQPC read.me identifies the edition');
      expect(File('third_party/kfgqpc/PROVENANCE.md').existsSync(), isTrue,
          reason: 'attribution and terms must travel with the data');
    });

    test('pubspec declares no third_party asset', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('third_party'), isFalse,
          reason: 'third_party must not be declared as a Flutter asset — '
              'that would bundle 3.5 MB of reference data into the app');
    });

    test('no file under lib/ references third_party', () {
      final offenders = <String>[];
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (file.readAsStringSync().contains('third_party')) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'application code must not reach into third_party');
    });

    test('the source pack itself is not bundled either', () {
      // The pack is imported into Firestore by an admin, not shipped.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('source_packs'), isFalse);
    });
  });
}
