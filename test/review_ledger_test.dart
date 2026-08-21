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

/// The page numbers a record's own `sourceSection` claims.
///
/// Only the tail after the last «صفح» is read, so the ayah numbers earlier
/// in the same string ("[النمل: 19] — صفحتا 96-97") can never be mistaken
/// for page numbers.
List<int> _pagesFromSection(String section) {
  final i = section.lastIndexOf('صفح');
  if (i < 0) return const [];
  final nums = RegExp(r'\d+')
      .allMatches(section.substring(i))
      .map((m) => int.parse(m.group(0)!))
      .toList();
  // «صفحتا 96-97» and «صفحات 65-67» are ranges, not two loose numbers: an
  // excerpt spanning 65 to 67 was read on 66 as well, and recording only the
  // endpoints would understate the review.
  if (nums.length == 2 && nums[1] > nums[0]) {
    return [for (var i = nums[0]; i <= nums[1]; i++) i];
  }
  return (nums.toSet().toList())..sort();
}

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

    test('the reviewed page range covers exactly what sourceSection names', () {
      // Some excerpts run across a page break. Recording only the first page
      // would understate the review — it would read as though the second
      // page had never been looked at. So the pages reviewed must equal the
      // pages the record itself claims, in both directions: a spanning
      // record cannot be logged as single-page, and a single-page record
      // cannot claim a range it does not have.
      for (final r in reviews) {
        final entry = entryFor(r['recordId'] as String)!;
        final claimed = _pagesFromSection(entry['sourceSection'] as String);
        expect(claimed, isNotEmpty,
            reason: '${r['recordId']} names no page in sourceSection');

        final reviewed = r['reviewedPages'] == null
            ? [r['reviewedPage'] as int]
            : (r['reviewedPages'] as List).cast<int>();

        expect(reviewed, claimed,
            reason: '${r['recordId']} was reviewed on $reviewed but its '
                'sourceSection names $claimed');
        expect(reviewed.first, r['reviewedPage'],
            reason: '${r['recordId']}: reviewedPage must be the first page '
                'of the range');
      }
    });

    test('reviewedPages is only spelled out when a record really spans pages',
        () {
      for (final r in reviews) {
        if (r['reviewedPages'] == null) continue;
        final pages = (r['reviewedPages'] as List).cast<int>();
        expect(pages.length, greaterThan(1),
            reason: '${r['recordId']} lists reviewedPages for a single page');
        for (var i = 1; i < pages.length; i++) {
          expect(pages[i], greaterThan(pages[i - 1]),
              reason: '${r['recordId']} has an unordered page range');
        }
      }
    });

    test('a record that did not pass carries a reason and is excluded', () {
      // A review that fails or is blocked must say why, and must be marked
      // out of scope for import. Without both, a rejected record looks the
      // same as an unreviewed one, and the rejection is silently lost the
      // next time someone runs the importer.
      for (final r in reviews) {
        if (r['reviewStatus'] == 'passed') continue;
        expect(r['blockReason'], isNotNull,
            reason: '${r['recordId']} did not pass but gives no blockReason');
        expect((r['blockReason'] as String).trim(), isNotEmpty);
        expect(r['excludedFromImport'], isTrue,
            reason: '${r['recordId']} did not pass but is not excluded '
                'from import');
      }
    });

    test('a passed record is excluded only under a declared deployment hold',
        () {
      // A text that passed review is importable by default. The single
      // exception is a record the app cannot yet present correctly, and that
      // exception has to be declared — otherwise an exclusion with no stated
      // reason silently outlives whatever caused it.
      for (final r in reviews) {
        if (r['reviewStatus'] != 'passed') continue;
        expect(r['blockReason'], isNull,
            reason: '${r['recordId']} passed but carries a blockReason');
        if (r['excludedFromImport'] == true) {
          expect(r['deploymentBlocked'], isTrue,
              reason: '${r['recordId']} is passed and excluded, but names no '
                  'deployment hold to justify the exclusion');
        }
      }
    });

    test('nothing held back can read as ready for import', () {
      // Two distinct reasons a record may be held back, and they must not be
      // conflated:
      //
      //   reviewStatus: blocked  → something is wrong with the TEXT.
      //   deploymentBlocked      → the text is fine; the APP cannot yet
      //                            present it correctly.
      //
      // Both must be excluded from import. Only the first says the religious
      // text is at fault, and using it for a product limitation would put
      // blame on the source where none belongs.
      final blocked = reviews
          .where((r) => r['reviewStatus'] == 'blocked')
          .map((r) => r['recordId'])
          .toSet();
      final deploymentBlocked = reviews
          .where((r) => r['deploymentBlocked'] == true)
          .map((r) => r['recordId'])
          .toSet();
      final excluded = reviews
          .where((r) => r['excludedFromImport'] == true)
          .map((r) => r['recordId'])
          .toSet();

      expect(excluded, blocked.union(deploymentBlocked),
          reason: 'every held-back record, for either reason, must be '
              'excluded from import — and nothing else may be');
      expect(blocked.intersection(deploymentBlocked), isEmpty,
          reason: 'the two kinds of hold are distinct');

      final passed = reviews
          .where((r) => r['reviewStatus'] == 'passed')
          .map((r) => r['recordId'])
          .toSet();
      expect(passed.intersection(blocked), isEmpty,
          reason: 'a record cannot be both passed and blocked');
    });

    test('merging the code does not, on its own, lift a deployment hold', () {
      // The failure this guards against: someone merges the PR, sees the
      // field exist in the repository, and clears the hold. But the field
      // existing in `main` is not the field existing on the handset a
      // pilgrim is holding. An import makes the record visible to EVERY
      // released client, including older ones that know nothing about
      // `usageQualifier` — those would show the addition with no badge and
      // play it automatically, which is the exact harm the field prevents.
      //
      // So all three conditions must hold, and the hold stays until they do.
      for (final r in reviews) {
        if (r['deploymentBlocked'] != true) continue;
        final lift =
            r['deploymentBlockLiftConditions'] as Map<String, dynamic>?;
        expect(lift, isNotNull,
            reason: '${r['recordId']} is held back without stating what '
                'would lift the hold');

        for (final condition in const [
          'codeMerged',
          'appAndWorkerReleased',
          'badgeAndNoAutoPlayVerifiedOnDevice',
        ]) {
          expect(lift!.containsKey(condition), isTrue,
              reason: '${r['recordId']} omits the "$condition" condition');
        }

        final allMet = [
          'codeMerged',
          'appAndWorkerReleased',
          'badgeAndNoAutoPlayVerifiedOnDevice'
        ].every((k) => lift![k] == true);

        if (!allMet) {
          // Unmet conditions and a lifted hold cannot coexist.
          expect(lift!['liftedAt'], isNull,
              reason: '${r['recordId']} records a lift date while its '
                  'conditions are unmet');
          expect(r['deploymentBlocked'], isTrue);
          expect(r['excludedFromImport'], isTrue,
              reason: '${r['recordId']} still has unmet conditions but is no '
                  'longer excluded from import');
        } else {
          // Even with every condition met, lifting is a recorded human act.
          expect(lift!['liftedAt'], isNotNull,
              reason: '${r['recordId']} met its conditions but no one '
                  'recorded lifting the hold');
          expect(lift['liftedBy'], isNotNull);
        }
      }
    });

    test('a deployment hold names its reason and never blames the text', () {
      for (final r in reviews) {
        if (r['deploymentBlocked'] != true) continue;
        expect(r['deploymentBlockReason'], isNotNull,
            reason: '${r['recordId']} is held back with no reason given');
        expect((r['deploymentBlockReason'] as String).trim(), isNotEmpty);
        expect(r['excludedFromImport'], isTrue);
        // The text itself passed — that is the whole point of the
        // distinction, and it must be stated on the record.
        expect(r['textReviewStatus'], 'passed',
            reason: '${r['recordId']}: a deployment hold applies only to a '
                'record whose text passed review');
        expect(r['reviewStatus'], isNot('blocked'),
            reason: '${r['recordId']}: a product limitation must not be '
                'recorded as a defect in the religious text');
        expect(r['blockReason'], isNull,
            reason: '${r['recordId']} mixes a text block with a '
                'deployment block');
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

  group('the summary is recomputed, never asserted', () {
    final summary = ledger['summary'] as Map<String, dynamic>;

    int countWhere(bool Function(Map<String, dynamic>) p) =>
        reviews.where(p).length;

    test('the counts match the reviews they summarise', () {
      expect(summary['totalReviews'], reviews.length);
      expect(
          summary['passed'], countWhere((r) => r['reviewStatus'] == 'passed'));
      expect(summary['blocked'],
          countWhere((r) => r['reviewStatus'] == 'blocked'));
      expect(
          summary['failed'], countWhere((r) => r['reviewStatus'] == 'failed'));
      expect(
          summary['totalReviews'],
          (summary['passed'] as int) +
              (summary['blocked'] as int) +
              (summary['failed'] as int),
          reason: 'the statuses do not account for every review');
    });

    test('the per-uncertainty tally matches', () {
      final tally = <String, int>{};
      for (final r in reviews) {
        final u = r['uncertaintyResolved'] as String?;
        if (u == null) continue;
        tally[u] = (tally[u] ?? 0) + 1;
      }
      expect(summary['byUncertainty'], tally);
    });

    test('U5 is complete: all 22 records reviewed, 21 of them passed', () {
      final u5 = reviews.where((r) => r['uncertaintyResolved'] == 'U5');
      expect(u5.length, 22, reason: 'U5 has 22 records');
      expect(u5.where((r) => r['reviewStatus'] == 'passed').length, 21);
      expect(u5.where((r) => r['reviewStatus'] != 'passed').length, 1);

      // Every U5 record in the authority file must actually appear — a
      // tally of 22 proves nothing if it counted one record twice.
      final authority =
          _readJson('source_packs/quran_authority_hafs_uthmani.json');
      final expected = (authority['ayat'] as List)
          .cast<Map<String, dynamic>>()
          .where((a) => a['uncertainty'] == 'U5')
          .map((a) => a['duaId'] as String)
          .toSet();
      expect(u5.map((r) => r['recordId']).toSet(), expected);
    });

    test('the named deployment-blocked ids are the real ones', () {
      expect(
          (summary['deploymentBlockedRecordIds'] as List)
              .cast<String>()
              .toSet(),
          reviews
              .where((r) => r['deploymentBlocked'] == true)
              .map((r) => r['recordId'] as String)
              .toSet());
    });

    test('the named blocked and excluded ids are the real ones', () {
      expect(
          (summary['blockedRecordIds'] as List).cast<String>().toSet(),
          reviews
              .where((r) => r['reviewStatus'] == 'blocked')
              .map((r) => r['recordId'] as String)
              .toSet());
      expect(
          (summary['excludedFromImportRecordIds'] as List)
              .cast<String>()
              .toSet(),
          reviews
              .where((r) => r['excludedFromImport'] == true)
              .map((r) => r['recordId'] as String)
              .toSet());
    });

    test('the summary cannot claim a verification that did not happen', () {
      expect(summary['firestoreVerificationPerformed'], isFalse);
      expect(summary['verifiedRecords'], 0);
      // And the pack must agree — a zero here has to be true of the data,
      // not merely written down.
      expect(entries.where((e) => e['verificationStatus'] != 'unverified'),
          isEmpty);
    });
  });
}
