// Human review ledger tests.
//
// The ledger records that a person read a printed page. That is all it does.
// These tests pin the two properties that keep it honest:
//
//   1. It confers no authority. Nothing in it may mark a record verified,
//      and the source pack must stay `unverified` regardless of what the
//      ledger says. A reviewer's note is evidence for a later human act, not
//      a substitute for it.
//   2. It is pinned to exact bytes. `reviewedTextHash` is recomputed here
//      from the source pack, so if the text is edited after review the
//      ledger stops matching and this suite fails — which is the whole
//      point of storing a hash rather than a date alone.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readJson(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('missing file: $path');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Same construction the admin screen uses for `contentHash`:
/// sha256 over the ar body, a NUL separator, then the en body.
String _contentHash(String ar, String en) =>
    sha256.convert(utf8.encode('$ar\u0000$en')).toString();

void main() {
  final ledger = _readJson('review/human_review_ledger.json');
  final pack = _readJson('source_packs/moia_mukhtasar_1446_umrah.json');

  final reviews = (ledger['reviews'] as List).cast<Map<String, dynamic>>();
  final entries = (pack['entries'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic>? entryFor(String id) {
    for (final e in entries) {
      if (e['duaId'] == id) return e;
    }
    return null;
  }

  group('the ledger confers no authority', () {
    test('the ledger itself states no Firestore verification happened', () {
      expect(ledger['conferredAuthority'], 'none');
      expect(ledger['firestoreVerificationPerformed'], isFalse);
    });

    test('no ledger entry claims a record was verified', () {
      for (final r in reviews) {
        expect(r['firestoreVerificationPerformed'], isFalse,
            reason:
                '${r['recordId']} claims verification the ledger cannot grant');
        // `passed` means ready-for-verification. The word `verified` must not
        // appear as a status, so no reader — and no future script — can
        // mistake a review for an approval.
        expect(r['reviewStatus'], isNot('verified'));
        expect(r['reviewStatus'], anyOf('passed', 'failed', 'blocked'));
      }
    });

    test('every reviewed record is still unverified in the source pack', () {
      for (final r in reviews) {
        final entry = entryFor(r['recordId'] as String);
        expect(entry, isNotNull, reason: 'unknown recordId ${r['recordId']}');
        expect(entry!['verificationStatus'], 'unverified');
        expect(entry['verifiedAt'], isNull);
        expect(entry['verifiedBy'], isNull);
        expect(entry['contentHash'], isNull);
      }
    });

    test('the whole pack is still unverified', () {
      for (final e in entries) {
        expect(e['verificationStatus'], 'unverified',
            reason: '${e['duaId']} is no longer unverified');
      }
    });
  });

  group('the ledger is pinned to exact bytes', () {
    test('each reviewedTextHash matches the record text as it stands', () {
      for (final r in reviews) {
        final entry = entryFor(r['recordId'] as String)!;
        final text = entry['text'] as Map<String, dynamic>;
        final actual = _contentHash(
          (text['ar'] ?? '') as String,
          (text['en'] ?? '') as String,
        );
        expect(actual, r['reviewedTextHash'],
            reason: 'the text of ${r['recordId']} changed after it was '
                'reviewed — the review no longer applies to these bytes');
      }
    });

    test('each entry carries the fields an audit needs', () {
      for (final r in reviews) {
        for (final field in [
          'recordId',
          'reviewer',
          'reviewStatus',
          'reviewedPage',
          'reviewedEdition',
          'reviewedTextHash',
          'reviewedAt',
        ]) {
          expect(r[field], isNotNull,
              reason: '${r['recordId']} missing $field');
          expect(r[field].toString().trim(), isNotEmpty,
              reason: '${r['recordId']} has an empty $field');
        }
        expect(DateTime.tryParse(r['reviewedAt'] as String), isNotNull,
            reason: '${r['recordId']} has an unparseable reviewedAt');
      }
    });

    test('reviewedPage matches the printed page recorded on the record', () {
      for (final r in reviews) {
        final entry = entryFor(r['recordId'] as String)!;
        expect(r['reviewedPage'], entry['printedPage'],
            reason: 'the reviewer read a different page than the record cites');
      }
    });

    test('no record is reviewed twice under conflicting outcomes', () {
      final seen = <String, String>{};
      for (final r in reviews) {
        final id = r['recordId'] as String;
        final status = r['reviewStatus'] as String;
        if (seen.containsKey(id)) {
          expect(seen[id], status,
              reason: '$id appears twice with conflicting outcomes');
        }
        seen[id] = status;
      }
    });
  });
}
