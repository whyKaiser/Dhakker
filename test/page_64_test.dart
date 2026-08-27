// Printed page 64 — the last two records in the pack, and the only page in
// this branch where the review changed more than a vowel.
//
// The page runs: prose continuing from p63; a heading; the author's own
// instruction, which contains the wording to say on entering — «وقول: بسم
// الله … أبواب رحمتك.» — set inside his sentence with no brackets; then the
// hadith, inside guillemets with its isnad outside them, carrying the page's
// only footnote marker (١) immediately after the closing guillemet; then
// «وهذا عام في المسجد الحرام وسائر المساجد.»; then the footnote itself,
// «(١) أخرجه مسلم رقم (٧١٣).»
//
// Three things follow, and each is asserted below:
//
//   * ONE character changed in the whole pack: a sukun on the fa of «افْتَحْ»
//     in the hadith. Isolated at the word's own bounds and magnified, the
//     print shows a sukun RING above the fa — distinct from the fa's own
//     solid dot beneath it — a fatha on the ta, and a sukun on the ha. That
//     settles the visuallyUncertain note which had read «no visible sukun on
//     the fa».
//
//   * Muslim 713 goes to the hadith and to nothing else. The marker sits
//     after the hadith's closing guillemet; the first record ends in a bare
//     full stop.
//
//   * The hadith is reclassified contextual_evidence. Not because a hadith
//     cannot be procedural_guidance — the pack already classifies prophetic
//     instruction that way — but because of what this narration DOES on the
//     page: it is the evidence for the wording above it. Operationally that
//     is the point. As mosque_entry it was recitable, which means
//     canPlayManually, which means voice search would play it: a single
//     spoken result is played with no button press. The pilgrim would have
//     heard the narrator's instructions read out as his own supplication.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';

const String kEntry = 'moia-mukhtasar-1446-umrah-entering-masjid';
const String kHadith = 'moia-mukhtasar-1446-umrah-entering-masjid-hadith';

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

/// sha256(text.ar + U+0000 + text.en) of the reviewed text.
const Map<String, String> kHashes = {
  kEntry: '6daed90342adb2b1',
  kHadith: '793e020ad3e2ab17',
};

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
  group('the only text change on this page is the sukun on the fa', () {
    test('the hadith prints «افْتَحْ», with the sukun', () {
      final t = _ar(kHadith);
      expect(t.contains('اللهُمَّ افْتَحْ لِي'), isTrue);
      expect(t.contains('اللهُمَّ افتَحْ'), isFalse,
          reason: 'the pre-correction spelling must not come back');
      expect(t.length, 160, reason: '159 before the sukun was added');
    });

    test('nothing else in the hadith moved', () {
      final t = _ar(kHadith);
      // The third spelling of «اللهم» in this pack: no shadda on the lam, a
      // damma on the ha, shadda+fatha on the mim. Kept as the ministry set
      // it — it differs from «اللَّهُمَّ» on pp. 97-101 and from «اللَّهُمَ»
      // in general-023, and none of the three was normalised to the others.
      expect('اللهُمَّ'.allMatches(t).length, 2);
      expect(t.contains('اللَّهُمَّ'), isFalse);
      // waṣl damma on the mim of «أَحَدُكُمُ»
      expect(t.contains('أَحَدُكُمُ الْمَسْجِدَ'), isTrue);
      // quotation bounds: the isnad stayed outside, the matn is all of it
      expect(t.startsWith('إِذَا دَخَلَ'), isTrue);
      expect(t.endsWith('مِنْ فَضْلِكَ'), isTrue);
      expect(t.contains('رَسُولُ'), isFalse,
          reason: 'the isnad is printed outside the guillemets');
      expect(t.contains('«'), isFalse);
      expect(t.contains('»'), isFalse);
      // punctuation as printed: two colons, three commas, no full stop
      expect(':'.allMatches(t).length, 2);
      expect('،'.allMatches(t).length, 3);
      expect(t.contains('.'), isFalse);
    });

    test('the first record was not touched at all', () {
      final t = _ar(kEntry);
      expect(t.length, 134);
      expect(_reviews()[kEntry]!['transcriptionCorrected'], isFalse);
      // Unvocalised except for one damma, exactly as printed.
      expect(t.contains('وأعوذُ بالله العظيم'), isTrue);
      expect(t.contains('علىٰ رسول الله'), isTrue,
          reason: 'the dagger alef the page prints');
      expect(t.endsWith('أبواب رحمتك'), isTrue);
      expect(t.contains('.'), isFalse);
      // Counted, so a stray vowel added later shows up here.
      const marks = [
        0x064B,
        0x064C,
        0x064D,
        0x064E,
        0x064F,
        0x0650,
        0x0651,
        0x0652
      ];
      expect(t.runes.where(marks.contains).length, 1,
          reason: 'the damma on «وأعوذُ» is the only vowel on the page here');
    });

    test('both hash to what was compared, and are recorded once each', () {
      for (final id in [kEntry, kHadith]) {
        expect(_hash(id).startsWith(kHashes[id]!), isTrue, reason: id);
        expect(
            (_reviews()[id]!['reviewedTextHash'] as String)
                .startsWith(kHashes[id]!),
            isTrue,
            reason: id);
        expect(_rawReviews().where((r) => r['recordId'] == id).length, 1,
            reason: id);
        expect(_reviews()[id]!['reviewStatus'], 'passed', reason: id);
        expect(_reviews()[id]!['reviewedPage'], 64, reason: id);
        expect(_entry(id)['printedPage'], 64, reason: id);
        expect(_entry(id)['verificationStatus'], 'unverified', reason: id);
      }
      expect(_reviews()[kHadith]!['transcriptionCorrected'], isTrue);
    });
  });

  group('Muslim 713 belongs to the hadith and to nothing else', () {
    test('the hadith carries exactly that one reference', () {
      final refs = (_entry(kHadith)['sourceReferences'] as List)
          .cast<Map<String, dynamic>>();
      expect(refs, hasLength(1));
      final r = refs.single;
      expect(r['type'], 'hadith');
      expect(r['collection'], 'صحيح مسلم');
      expect(r['reference'], '713');
      expect(r['referenceKind'], 'hadith_number');
      expect(r['citedBy'], 'moia_1446');
      expect(r['citedOnPage'], 64);
      expect(_reviews()[kHadith]!['sourceReferencesReviewStatus'],
          'reviewed_present');
    });

    test('the first record did not inherit it', () {
      expect((_entry(kEntry)['sourceReferences'] as List), isEmpty);
      expect(_entry(kEntry)['quranRef'], isNull);
      expect(
          _reviews()[kEntry]!['sourceReferencesReviewStatus'], 'reviewed_none');
      // and the note has to say why, since the page does print a footnote
      final n = _reviews()[kEntry]!['sourceReferencesNote'] as String;
      expect(n.contains('713'), isTrue);
    });

    test('neither record raises a Quranic candidate', () {
      // A candidate detector, within its limits: shared runs of 25 characters
      // or more in the vowel-stripped skeleton, nothing shorter, nothing
      // across a difference of rasm. A clean run is not a verdict on where
      // the text came from. Run here because these two were never scanned
      // until the page-64 batch — the pack-wide guard is what surfaced that.
      final corpus = (jsonDecode(File(kCorpus).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      expect(corpus.length, 6236);
      final hay =
          corpus.map((a) => _skeleton(a['aya_text'] as String)).join(' | ');
      const window = 25;
      for (final id in [kEntry, kHadith]) {
        final s = _skeleton(_ar(id));
        String? hit;
        for (var i = 0; i + window <= s.length; i++) {
          final w = s.substring(i, i + window);
          if (hay.contains(w)) {
            hit = w;
            break;
          }
        }
        expect(hit, isNull, reason: '$id raises the candidate «$hit»');
      }
    });

    test('no other record in the pack claims Muslim 713', () {
      for (final e in _entries()) {
        if (e['duaId'] == kHadith) continue;
        for (final r
            in (e['sourceReferences'] as List).cast<Map<String, dynamic>>()) {
          expect(r['collection'] == 'صحيح مسلم' && r['reference'] == '713',
              isFalse,
              reason: '${e['duaId']} must not carry page 64\'s footnote');
        }
      }
    });
  });

  group('the hadith cannot be voiced, by any path', () {
    test('its kind makes it unrecitable', () {
      expect(_entry(kHadith)['contentKind'], 'contextual_evidence');
      expect(_model(kHadith).contentKind,
          SupplicationContentKind.contextualEvidence);
      expect(
          _reviews()[kHadith]!['contentKindConfirmed'], 'contextual_evidence');
      expect(_reviews()[kHadith]!['contentKindChangedFrom'], 'mosque_entry');
    });

    test('manual play, auto play and the dua section are all closed to it', () {
      final m = _model(kHadith);
      // canPlayManually is the guard _playDua checks, and voice search calls
      // _playDua directly when a spoken query leaves exactly one result —
      // no button in between. This is the assertion that matters.
      expect(m.canPlayManually, isFalse);
      expect(m.isAutoPlayable, isFalse);
      expect(m.contentKind.isRecitable, isFalse);
      expect(m.contentKind.belongsInDuaSection, isFalse);
    });

    test('its card names it a prophetic hadith', () {
      // The badge for this kind reads «أثر موثّق», which on its own leaves
      // open that it might be a Companion's report. The title carries the
      // attribution instead — data only, no interface change.
      final title = _entry(kHadith)['title'] as Map<String, dynamic>;
      expect(title['ar'], contains('حديث نبوي'));
      expect(title['en'], contains('Prophetic hadith'));
      expect(_model(kHadith).contentKind.badgeAr(),
          'أثر موثّق — للفائدة لا للترديد');
    });

    test('it is held out of import until the card ships', () {
      final r = _reviews()[kHadith]!;
      expect(r['deploymentBlocked'], isTrue);
      expect(r['excludedFromImport'], isTrue);
      expect(r['deploymentBlockReason'], 'content_kind_not_yet_deployed');
      expect(r['reviewStatus'], 'passed',
          reason: 'the TEXT passed; the hold is a product limitation and '
              'must never be recorded as a fault in the religious text');
      final lift = r['deploymentBlockLiftConditions'] as Map<String, dynamic>;
      expect(lift['codeMerged'], isFalse);
      expect(lift['appAndWorkerReleased'], isFalse);
      expect(lift['badgeAndNoAutoPlayVerifiedOnDevice'], isFalse);
      expect(lift['liftedAt'], isNull);
      expect(lift['liftedBy'], isNull);
    });
  });

  group('the first record stays reachable, and stays unlocated', () {
    test('it is still mosque_entry and still playable on request', () {
      final m = _model(kEntry);
      expect(_entry(kEntry)['contentKind'], 'mosque_entry');
      expect(m.contentKind, SupplicationContentKind.mosqueEntry);
      expect(m.canPlayManually, isTrue);
      expect(m.contentKind.belongsInDuaSection, isTrue);
      expect(_reviews()[kEntry]!['deploymentBlocked'], isFalse);
      expect(_reviews()[kEntry]!['excludedFromImport'], isFalse);
    });

    test('no zone was invented for it', () {
      // The source says the wording is general to every mosque. Empty zone
      // fields are the faithful representation of that, not a gap: with no
      // zoneKey and no appliesToZoneKeys, appliesToZone is false everywhere,
      // so it can never be read out at a location.
      final e = _entry(kEntry);
      expect(e['zoneKey'], '');
      expect(e['zoneId'], '');
      expect(e['appliesToZoneKeys'], isNull);
      expect(e['ritualKey'], isNull);
      expect(e['recitationPolicy'], isNull);
      final m = _model(kEntry);
      expect(m.contentKind.isTiedToLocation, isFalse);
      for (final z in ['mataf', 'kaaba', 'masaa', 'mina', 'arafat']) {
        expect(m.appliesToZone(z), isFalse, reason: z);
      }
      expect(m.contentKind.badgeAr(), 'عام لدخول المساجد');
    });
  });

  group('the review is closed', () {
    test('every record is reviewed, once, and none is verified', () {
      final rs = _rawReviews();
      final ids = rs.map((r) => r['recordId']).toSet();
      expect(_entries(), hasLength(85));
      expect(ids.length, rs.length, reason: 'no record reviewed twice');
      expect(ids.length, 85, reason: 'no record left unreviewed');
      expect(_entries().every((e) => e['verificationStatus'] == 'unverified'),
          isTrue);
      expect(_entries().every((e) => e['contentHash'] == null), isTrue);
    });

    test('the counters add up across every status the schema supports', () {
      final s = (jsonDecode(
        File('review/human_review_ledger.json').readAsStringSync(),
      ) as Map<String, dynamic>)['summary'] as Map<String, dynamic>;
      final rs = _rawReviews();
      expect(s['totalReviews'], 85);
      expect(s['passed'], 84);
      expect(s['blocked'], 1);
      expect(s['pending'], 0);
      expect(s['failed'], 0);
      for (final st in ['passed', 'blocked', 'pending', 'failed']) {
        expect(s[st], rs.where((r) => r['reviewStatus'] == st).length,
            reason: 'summary.$st disagrees with the reviews array');
      }
      expect(
          (s['passed'] as int) +
              (s['blocked'] as int) +
              (s['pending'] as int) +
              (s['failed'] as int),
          s['totalReviews']);
      expect(s['verifiedRecords'], 0);
      expect(s['firestoreVerificationPerformed'], isFalse);
    });

    test('the audio set shrank by exactly this one record', () {
      // Recounted from the pack, not carried over. The hadith left the
      // recitable set when it stopped being mosque_entry.
      const recitable = {
        'specific_text',
        'general_dua',
        'general_dhikr',
        'mosque_entry',
      };
      final rec = _entries()
          .where((e) => recitable.contains(e['contentKind']))
          .toList();
      expect(rec, hasLength(59));
      expect(_entries().length - rec.length, 26);
      final texts = rec
          .map((e) => sha256
              .convert(
                  utf8.encode('${e['text']['ar']}\u0000${e['text']['en']}'))
              .toString())
          .toSet();
      expect(texts, hasLength(58),
          reason: 'two records share البقرة 201 and must share one file');
      expect(rec.any((e) => e['duaId'] == kHadith), isFalse);
      expect(rec.any((e) => e['duaId'] == kEntry), isTrue);
      expect(
          _entries().every((e) => (e['text']['en'] as String).trim().isEmpty),
          isTrue,
          reason: 'no English audio is implied by this pack');
    });

    test('the eligible audio set is smaller than the canonical one', () {
      // Two different numbers, and conflating them would be a real mistake:
      // 58 is every canonical recitable text; 54 is what may be voiced now.
      // A held record must not get an audio file — a file is a second
      // playback path around the hold — so held records are excluded here.
      //
      // Counted over distinct TEXTS, never by subtracting records: if a held
      // record ever shares its text with a free one, the text is still needed
      // and subtraction would undercount. That does not happen today, and
      // this is written so it stays correct when it does.
      const recitable = {
        'specific_text',
        'general_dua',
        'general_dhikr',
        'mosque_entry',
      };
      final reviews = _reviews();
      bool held(String id) {
        final r = reviews[id];
        if (r == null) return true;
        return r['reviewStatus'] == 'blocked' ||
            r['deploymentBlocked'] == true ||
            r['excludedFromImport'] == true;
      }

      String text(Map<String, dynamic> e) => sha256
          .convert(utf8.encode('${e['text']['ar']}\u0000${e['text']['en']}'))
          .toString();

      final rec = _entries()
          .where((e) => recitable.contains(e['contentKind']))
          .toList();
      final eligible = rec.where((e) => !held(e['duaId'] as String)).toList();

      expect(rec.map(text).toSet(), hasLength(58));
      expect(eligible, hasLength(55));
      expect(eligible.map(text).toSet(), hasLength(54));

      // exactly these four recitable records are held, each with a reason
      final heldIds = rec.map((e) => e['duaId'] as String).where(held).toList()
        ..sort();
      expect(heldIds, [
        'moia-1446-safa-ayah',
        'moia-1446-safa-dhikr',
        'moia-mukhtasar-1446-general-009',
        'moia-mukhtasar-1446-umrah-talbiyah-ziyadah',
      ]);
      for (final id in heldIds) {
        final r = reviews[id]!;
        final reason = r['reviewStatus'] == 'blocked'
            ? (r['reviewBlockReason'] ?? r['blockReason'])
            : r['deploymentBlockReason'];
        expect(reason, isNotNull, reason: '$id is held with no reason');
      }

      // the one shared text survives on both sides: two records, one file
      final shared = rec
          .where((e) => const [
                'moia-mukhtasar-1446-tawaf-between-corners',
                'moia-mukhtasar-1446-general-001',
              ].contains(e['duaId']))
          .toList();
      expect(shared, hasLength(2));
      expect(shared.map(text).toSet(), hasLength(1));
      expect(shared.every((e) => !held(e['duaId'] as String)), isTrue);
    });
  });
}
