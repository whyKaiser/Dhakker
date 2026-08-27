// Printed page 102 — one new record, general-049, and nothing else in scope.
//
// The page opens with the last two lines of general-048, whose unit begins on
// page 101 and is already recorded there with reviewedPages [101, 102]. It is
// deliberately NOT re-recorded here. Lines 3-4 are general-049. From line 5 a
// new heading begins — «❑ المبيت بمزدلفة:» — and the rest of the page is
// unvocalised Hajj prose, outside this pack.
//
// -049 compared clean: raw and NFC identical at the same length. Nothing in
// text.ar changed and the classification was not touched.
//
// The page does carry a real footnote rule, glossing «منتصف الليل» for the
// Muzdalifah section. It belongs to neither dua: nothing follows «قَدِيرٌ)»
// or «وَتَعَالَيْتَ)» but the full stop, with no raised numeral.
//
// The live ledger counters moved on to test/page_64_test.dart when page 64
// was recorded — a snapshot of a growing counter belongs to exactly one test,
// and every other page's test asserts the identity instead.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';

const String k048 = 'moia-mukhtasar-1446-general-048';
const String k049 = 'moia-mukhtasar-1446-general-049';

/// sha256(text.ar + U+0000 + text.en) of the reviewed text.
const String kHash049 = '184f7ac9e269e9e7';

/// The pinned KFGQPC Hafs corpus — the only authority for Quran text here.
const String kCorpus = 'third_party/kfgqpc/hafsData_v2-0.json';

String _skeleton(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if ((r >= 0x064B && r <= 0x0652) ||
        r == 0x0670 ||
        (r >= 0x06D6 && r <= 0x06ED)) {
      continue;
    }
    var c = r;
    if (c == 0x0671 || c == 0x0622 || c == 0x0623 || c == 0x0625) c = 0x0627;
    b.writeCharCode(c);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<Map<String, dynamic>> _entries() => ((jsonDecode(
      File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
    ) as Map<String, dynamic>)['entries'] as List)
        .cast<Map<String, dynamic>>();

Map<String, dynamic> _entry(String id) =>
    _entries().firstWhere((e) => e['duaId'] == id);

SupplicationModel _model(String id) => SupplicationModel.fromJson(_entry(id));

String _ar(String id) => _entry(id)['text']['ar'] as String;

List<Map<String, dynamic>> _rawReviews() => ((jsonDecode(
      File('review/human_review_ledger.json').readAsStringSync(),
    ) as Map<String, dynamic>)['reviews'] as List)
        .cast<Map<String, dynamic>>();

Map<String, Map<String, dynamic>> _reviews() =>
    {for (final r in _rawReviews()) r['recordId'] as String: r};

String _hash(String id) {
  final t = _entry(id)['text'] as Map<String, dynamic>;
  return sha256.convert(utf8.encode('${t['ar']}\u0000${t['en']}')).toString();
}

void main() {
  group('general-049 is recorded once, on page 102, with nothing corrected',
      () {
    test('it has a passed review naming page 102', () {
      final r = _reviews()[k049];
      expect(r, isNotNull);
      expect(r!['reviewStatus'], 'passed');
      expect(r['textReviewStatus'], 'passed');
      expect(r['reviewedPage'], 102);
      expect(r['transcriptionCorrected'], isFalse);
      expect(r['deploymentBlocked'], isFalse);
      expect(r['excludedFromImport'], isFalse);
      expect(r.containsKey('reviewedPages'), isFalse,
          reason: 'the unit opens and closes on page 102');
      expect(_entry(k049)['printedPage'], 102);
    });

    test('it appears exactly once in the ledger', () {
      expect(_rawReviews().where((r) => r['recordId'] == k049).length, 1);
    });

    test('the text still hashes to what was compared', () {
      expect(_hash(k049).startsWith(kHash049), isTrue);
      expect(_ar(k049).length, 116);
      expect(
          (_reviews()[k049]!['reviewedTextHash'] as String)
              .startsWith(kHash049),
          isTrue);
    });

    test('its classification was not touched', () {
      expect(_entry(k049)['contentKind'], 'general_dhikr');
      expect(_model(k049).contentKind, SupplicationContentKind.generalDhikr);
      expect(_reviews()[k049]!['contentKindConfirmed'], 'general_dhikr');
      expect(_entry(k049)['verificationStatus'], 'unverified');
      expect(_entry(k049)['contentHash'], isNull);
    });

    test('no printing apparatus leaked in, and the punctuation is as set', () {
      final t = _ar(k049);
      expect(t.contains('('), isFalse);
      expect(t.contains(')'), isFalse);
      expect(t.endsWith('.'), isFalse);
      expect(t, equals(t.trim()));
      // One comma, after «لَهُ»; no internal full stop to split on.
      expect('،'.allMatches(t).length, 1);
      expect(t.contains('لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ'), isTrue);
      expect(t.contains('.'), isFalse);
    });

    test('the orthography the page prints survives', () {
      final t = _ar(k049);
      // «إِلَهَ» without a dagger alef, but «عَلَىٰ» with one — both as printed.
      expect(t.contains('إِلَهَ'), isTrue);
      expect(t.contains('إِلَٰهَ'), isFalse);
      expect(t.contains('عَلَىٰ'), isTrue);
      // «الله» is set plain here, without a written shadda.
      expect(t.contains('إِلَّا الله وَحْدَهُ'), isTrue);
    });

    test('general-048 was not re-recorded by this batch', () {
      final r = _reviews()[k048]!;
      expect(r['reviewedPage'], 101, reason: 'its unit opens on 101');
      expect(r['reviewedPages'], [101, 102]);
      expect(_rawReviews().where((e) => e['recordId'] == k048).length, 1);
    });
  });

  group('nothing on the page attaches a takhrij to -049', () {
    test('the ledger says reviewed_none and the pack agrees', () {
      expect(
          _reviews()[k049]!['sourceReferencesReviewStatus'], 'reviewed_none');
      expect((_entry(k049)['sourceReferences'] as List), isEmpty);
      expect(_entry(k049)['quranRef'], isNull);
    });

    test('the note explains the page footnote is the Muzdalifah gloss', () {
      // The page has a rule and a numbered note. Saying "reviewed_none"
      // without recording why that footnote is unrelated would leave a
      // later reader unable to tell a check from an oversight.
      final n = _reviews()[k049]!['sourceReferencesNote'] as String;
      expect(n.contains('منتصف الليل'), isTrue);
      expect(n.contains('مزدلفة'), isTrue);
    });

    test('it shares a formula with al-Taghabun 1, and that is recorded', () {
      // The scan raised a real candidate here, unlike every other page in
      // this batch: 34
      // characters of the vowel-stripped skeleton — «لَهُ الْمُلْكُ وَلَهُ
      // الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ» — occur in al-Taghabun 1. The
      // record still carries no quranRef, because the ministry prints it as
      // a prophetic dhikr inside the quoted-matn parentheses, with no ayah
      // marker and no attribution; the wording is a shared formula, not a
      // declared quotation.
      //
      // That is not a one-off exemption. safa-dhikr, reviewed long before
      // this batch, shares the same words from the same ayah and likewise
      // has no quranRef — and every OTHER record in the pack that shares 25
      // characters or more with the Mushaf does have one. This test pins
      // both halves, so the day someone adds a quranRef-less record with a
      // real Quranic run, it fails.
      final corpus = (jsonDecode(File(kCorpus).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      expect(corpus.length, 6236);
      final skeletons = {
        for (final a in corpus)
          '${a['sura_no']}:${a['aya_no']}': _skeleton(a['aya_text'] as String)
      };
      const shared = 'له الملك وله الحمد وهو على كل شيء';
      expect(skeletons['64:1']!.contains(shared), isTrue,
          reason: 'the overlap is with al-Taghabun 1');
      expect(_skeleton(_ar(k049)).contains(shared), isTrue);
      expect(_entry(k049)['quranRef'], isNull);

      // Nobody else may sit in that exemption unannounced.
      final hay = skeletons.values.join(' | ');
      const window = 25;
      final unrefd = <String>[];
      for (final e in _entries()) {
        if (e['quranRef'] != null) continue;
        final s = _skeleton(e['text']['ar'] as String);
        for (var i = 0; i + window <= s.length; i++) {
          if (hay.contains(s.substring(i, i + window))) {
            unrefd.add(e['duaId'] as String);
            break;
          }
        }
      }
      unrefd.sort();
      expect(unrefd, ['moia-1446-safa-dhikr', k049],
          reason: 'a record shares a Quranic run but carries no quranRef; '
              'either it quotes the Quran and needs one, or the exemption '
              'needs to be reviewed and recorded like these two');
    });

    test('the note says so, rather than claiming a clean scan', () {
      final n = _reviews()[k049]!['sourceReferencesNote'] as String;
      expect(n.contains('التغابن'), isTrue);
      expect(n.contains('safa-dhikr'), isTrue);
    });

    test('it holds no «من» site at all', () {
      final bare = _ar(k049)
          .split(RegExp(r'\s+'))
          .map((w) => w.replaceAll(RegExp(r'[،.:؛]'), ''))
          .map((w) => w.runes
              .where((r) => !((r >= 0x064B && r <= 0x0652) || r == 0x0670))
              .map(String.fromCharCode)
              .join());
      expect(bare.where((w) => const ['من', 'ومن'].contains(w)), isEmpty);
    });
  });

  group('recording the page changed nothing about deployment', () {
    test('the pack is still 85 unverified records', () {
      final all = _entries();
      expect(all.length, 85);
      expect(all.every((e) => e['verificationStatus'] == 'unverified'), isTrue);
    });

    test('the ledger counters are what page 102 leaves behind', () {
      final l = jsonDecode(
        File('review/human_review_ledger.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final s = l['summary'] as Map<String, dynamic>;
      final rs = _rawReviews();
      expect(s['totalReviews'], rs.length);
      expect(s['totalReviews'], greaterThanOrEqualTo(83),
          reason: 'page 102 took the ledger to 83; it can only grow');
      expect(s['blocked'], 1);
      // The identity, not «passed == total - blocked»: pending and failed are
      // real statuses the schema supports, and this must keep adding up when
      // one of them is finally used.
      expect(
          (s['passed'] as int) +
              (s['blocked'] as int) +
              (s['pending'] as int) +
              (s['failed'] as int),
          s['totalReviews']);
      for (final st in ['passed', 'blocked', 'pending', 'failed']) {
        expect(s[st], rs.where((r) => r['reviewStatus'] == st).length,
            reason: 'summary.$st disagrees with the reviews array');
      }
      expect(s['verifiedRecords'], 0);
      expect(s['firestoreVerificationPerformed'], isFalse);
      expect(rs.map((r) => r['recordId']).toSet().length, rs.length,
          reason: 'no record may be reviewed twice');
      expect(rs.map((r) => r['recordId']).toSet().length, lessThanOrEqualTo(85),
          reason: 'the ledger cannot hold more reviews than there are '
              'records');
    });

    test('the page-64 pair that was still open here is now recorded too', () {
      // When page 102 was recorded these two were the whole remainder. They
      // were reviewed in the next batch, so the assertion is inverted rather
      // than deleted: what mattered was that the remainder was exactly this
      // pair and nothing else had been skipped along the way.
      final done = _rawReviews().map((r) => r['recordId']).toSet();
      for (final id in const [
        'moia-mukhtasar-1446-umrah-entering-masjid',
        'moia-mukhtasar-1446-umrah-entering-masjid-hadith',
      ]) {
        expect(done, contains(id), reason: id);
      }
      final left = _entries()
          .where((e) => !done.contains(e['duaId']))
          .map((e) => e['duaId'])
          .toList();
      expect(left, isEmpty, reason: 'nothing was skipped on the way here');
    });
  });
}
