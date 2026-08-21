// Every writer into `supplications`, and the one invariant they share.
//
// The pilgrim-facing queries filter on `revokedAt == null`. A Firestore
// equality filter does NOT match a document where the field is absent, so a
// record written without it is invisible in the app while looking perfectly
// correct in the admin console. That makes "every writer writes revokedAt
// explicitly" a correctness requirement, not a style rule.
//
// These tests read the writers as source text. That is deliberate: the real
// writers need Firebase, and the property being checked is a property of the
// payload each one builds.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) {
  final f = File(path);
  if (!f.existsSync()) throw StateError('missing file: $path');
  return f.readAsStringSync();
}

const _addScreen =
    'lib/Screens/Admin/Manage Supplications/admin_supplication_add_screen.dart';
const _editScreen =
    'lib/Screens/Admin/Manage Supplications/admin_supplication_edit_screen.dart';
const _importer = 'scripts/import_source_pack.mjs';
const _service = 'lib/Screens/Piligram/Home/services/supplication_service.dart';

void main() {
  group('the writer inventory is complete and closed', () {
    test('only the known files write to the supplications collection', () {
      // A write is a mutation chained onto the supplications collection, not
      // merely a file that mentions it and also writes something somewhere.
      // Read-only admin screens (dashboard, zone details) list the
      // collection and must not be counted.
      final writers = <String>[];
      for (final dir in ['lib', 'scripts']) {
        for (final entity in Directory(dir).listSync(recursive: true)) {
          if (entity is! File) continue;
          if (!entity.path.endsWith('.dart') && !entity.path.endsWith('.mjs')) {
            continue;
          }
          if (entity.path.endsWith('.test.mjs')) continue;
          final src = entity.readAsStringSync();

          if (src.contains('PRODUCTION_COLLECTION') &&
              src.contains('method: "PATCH"')) {
            writers.add(entity.path);
            continue;
          }
          for (final m
              in RegExp(r"collection\('supplications'\)").allMatches(src)) {
            // Stop at the next statement boundary so a later, unrelated
            // write in the same file is not attributed here.
            final chain = src
                .substring(m.end, (m.end + 220).clamp(0, src.length))
                .split(';')
                .first;
            if (chain.contains('.update(') ||
                chain.contains('.set(') ||
                chain.contains('.add(')) {
              writers.add(entity.path);
              break;
            }
            // The other shape: the reference is stored first and written
            // later — `final docRef = ...collection('supplications').doc();`
            // followed by `docRef.set(...)`.
            final before = src.substring(
              (m.start - 200).clamp(0, src.length),
              m.start,
            );
            final assign =
                RegExp(r'final\s+(\w+)\s*=[^;]*$').firstMatch(before);
            final name = assign?.group(1);
            if (name != null &&
                (src.contains('$name.set(') ||
                    src.contains('$name.update(') ||
                    src.contains('$name.add('))) {
              writers.add(entity.path);
              break;
            }
          }
        }
      }
      writers.sort();

      expect(writers, containsAll([_addScreen, _editScreen, _importer]),
          reason: 'the known writers must still be detected');

      const allowed = {
        _addScreen,
        _editScreen,
        _importer,
        // usage_count only — these create nothing, so no revokedAt concern.
        'lib/Screens/Piligram/Home/controllers/home_dua_controller.dart',
        'lib/Screens/Piligram/Duas/duas_screen.dart',
      };
      final unexpected = writers.where((w) => !allowed.contains(w)).toList();
      expect(unexpected, isEmpty,
          reason: 'a new writer must declare how it handles revokedAt');
    });

    test('every pilgrim-facing read carries the three read-gate constraints',
        () {
      // Found the hard way while writing this file: duas_screen listed the
      // whole collection with only `isActive`. The tightened rules reject
      // that outright with permission-denied — it does not return less.
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // Admin screens read under the admin branch of the rule; the
        // exemption is stated here rather than left implicit.
        if (entity.path.contains('/Admin/')) continue;
        final src = entity.readAsStringSync();
        for (final m
            in RegExp(r"collection\('supplications'\)").allMatches(src)) {
          final chain = src
              .substring(m.end, (m.end + 400).clamp(0, src.length))
              .split(';')
              .first;
          if (!chain.contains('.where(')) continue;
          if (!chain.contains('verificationStatus') ||
              !chain.contains('revokedAt')) {
            offenders.add(entity.path);
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'a pilgrim-facing query missing a constraint fails entirely');
    });

    test('there is no supplications seed or migration script', () {
      // Zones are seeded; supplications are not. A migration would be a
      // fourth writer and would need the same guarantee.
      final scripts = Directory('scripts')
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => p.endsWith('.mjs') && !p.endsWith('.test.mjs'))
          .toList();
      for (final path in scripts) {
        if (path == _importer) continue;
        final src = _read(path);
        expect(src.contains("collection('supplications')"), isFalse,
            reason: '$path writes supplications without being audited here');
      }
    });
  });

  group('every new record carries an explicit revokedAt', () {
    test('the importer forces revokedAt: null on every record', () {
      final src = _read(_importer);
      final forced = src.substring(
        src.indexOf('const FORCED_FIELDS'),
        src.indexOf('const REQUIRED_FIELDS'),
      );
      expect(forced, contains('revokedAt: null'),
          reason: 'the importer must force revokedAt, not merely allow it');
    });

    test('the admin add screen writes revokedAt: null', () {
      expect(_read(_addScreen), contains("'revokedAt': null"),
          reason: 'a record created in the console would be invisible to the '
              'app without it');
    });
  });

  group('editing an old record backfills the missing field only', () {
    final src = _read(_editScreen);

    test('the edit screen records whether the key was present', () {
      expect(
          src, contains("_hadRevokedAtField = data.containsKey('revokedAt')"),
          reason: 'absent and null must be told apart before deciding');
    });

    test('the backfill is conditional — a real revocation is never cleared',
        () {
      // Writing `revokedAt: null` unconditionally would restore a withdrawn
      // text on the next save. That is the failure mode this guards.
      expect(src, contains("if (!_hadRevokedAtField) 'revokedAt': null"));
      expect(
          src.contains("'revokedAt': null,\n        'languageCodes'"), isFalse,
          reason: 'an unconditional write would clear existing revocations');
    });

    test('the backfill does not alter the text or the verification status', () {
      // The payload's verificationStatus still comes from the toggle the
      // admin set, and the text still comes from the text fields. Backfilling
      // must not become a silent re-verification or a silent edit.
      expect(
          src,
          contains(
              "'verificationStatus': _isVerifiedSource ? 'verified' : 'unverified'"));
      expect(src, contains("'ar': _textArController.text.trim()"));
      // Nothing in the backfill branch touches either.
      final branch = src.substring(src.indexOf('if (!_hadRevokedAtField)'));
      final line = branch.substring(0, branch.indexOf('\n'));
      expect(line.contains('verificationStatus'), isFalse);
      expect(line.contains('text'), isFalse);
    });

    test('a freshly loaded record with the key present is left alone', () {
      // _hadRevokedAtField defaults to true, so a load failure cannot cause a
      // spurious backfill either.
      expect(src, contains('bool _hadRevokedAtField = true;'));
    });
  });

  group('a failed query is diagnosed, never disguised', () {
    final src = _read(_service);

    test('the failure is recorded rather than swallowed', () {
      // Scoped to the fetch method. The cache helpers may still swallow —
      // a cache write that fails is not a deployment fault, and there is
      // nothing to diagnose.
      final fetch = src.substring(
        src.indexOf('Future<List<SupplicationModel>> getSupplicationsByZone'),
        src.indexOf('Future<void> _persistToCache'),
      );
      expect(fetch.contains('} catch (_) {}'), isFalse,
          reason:
              'an empty catch turns a deployment fault into "no duas here"');
      expect(fetch, contains('lastQueryFailure'));
      expect(src, contains('class SupplicationQueryFailure'));
    });

    test('the two dangerous codes are named explicitly', () {
      expect(src, contains('failed-precondition'),
          reason: 'a missing/building composite index must be recognisable');
      expect(src, contains('permission-denied'),
          reason: 'rules deployed ahead of the app must be recognisable');
    });

    test('a successful fetch clears any previous failure', () {
      expect(src, contains('lastQueryFailure = null;'));
    });

    test('the diagnostic carries no record content', () {
      // A diagnostic that logs the documents would leak exactly the
      // unverified text the gate exists to withhold.
      final failureClass = src.substring(
        src.indexOf('class SupplicationQueryFailure'),
        src.indexOf('class SupplicationService'),
      );
      for (final forbidden in ['text', 'title', 'content']) {
        expect(failureClass.contains('this.$forbidden'), isFalse,
            reason: 'the failure object must not carry $forbidden');
      }
    });

    test('failure does not fall back to unverified data', () {
      // The cache is filtered on the way out, so the fallback path cannot
      // surface anything the gate would have withheld.
      expect(src, contains('.where(isDisplayable)'));
      expect(src, contains('static bool isDisplayable'));
    });
  });

  group('the queries and the indexes agree', () {
    final indexes =
        jsonDecode(_read('firestore.indexes.json')) as Map<String, dynamic>;
    final src = _read(_service);

    test('all three retrieval paths carry the three read-gate constraints', () {
      for (final path in [
        "where('zoneKey', isEqualTo: zoneKey.trim())",
        "where('zoneId', isEqualTo: zoneId)",
        "where('appliesToZoneKeys', arrayContains: zoneKey.trim())",
      ]) {
        expect(src, contains(path));
      }
      // Three queries, each with all three constraints.
      expect("isActive', isEqualTo: true".allMatches(src).length, 3);
      expect(
          "verificationStatus', isEqualTo: 'verified'".allMatches(src).length,
          3);
      expect("revokedAt', isNull: true".allMatches(src).length, 3);
    });

    test('each retrieval path has a composite index declared', () {
      final list = (indexes['indexes'] as List).cast<Map<String, dynamic>>();
      for (final terminal in ['zoneKey', 'zoneId', 'appliesToZoneKeys']) {
        final match = list.where((i) {
          if (i['collectionGroup'] != 'supplications') return false;
          final paths = (i['fields'] as List)
              .cast<Map<String, dynamic>>()
              .map((f) => f['fieldPath'])
              .toList();
          return paths.contains('isActive') &&
              paths.contains('verificationStatus') &&
              paths.contains('revokedAt') &&
              paths.contains(terminal);
        });
        expect(match, isNotEmpty,
            reason: 'no composite index covers the $terminal query — it would '
                'fail with failed-precondition in production');
      }
    });
  });
}
