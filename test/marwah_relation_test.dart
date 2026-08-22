// Batch E — the Marwah guidance, and the one canonical dhikr it points at.
//
// Printed page 73 says, of Marwah: «ويقولَ مثل ما قال على الصفا». It gives no
// independent text. So the record is an INSTRUCTION, and the only correct
// implementation of "the like of what he said" is a pointer to the record
// that holds that text — never a second copy of it.
//
// Two copies of one religious text are two texts as soon as either is
// edited. These tests hold the pack to exactly one.
//
// The scoping matters as much as the duplication. Page 72 says the Safa
// Quran excerpt is read once before Sa'i begins «ولا يقرؤها مرة أخرى». The
// Marwah repetition therefore reaches the dhikr and the pilgrim's own dua,
// and stops there. Nothing in this app may tell a pilgrim to repeat the
// verse at Marwah.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Duas/widgets/content_kind_card.dart';
import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';

const String kMarwah = 'moia-1446-marwah-same';
const String kDhikr = 'moia-1446-safa-dhikr';
const String kAyah = 'moia-1446-safa-ayah';

Map<String, dynamic> _pack() => jsonDecode(
      File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
    ) as Map<String, dynamic>;

List<Map<String, dynamic>> _entries() =>
    (_pack()['entries'] as List).cast<Map<String, dynamic>>();

SupplicationModel _model(String id) =>
    SupplicationModel.fromJson(_entries().firstWhere((e) => e['duaId'] == id));

List<SupplicationModel> _zone(String zoneKey) => _entries()
    .where((e) => e['zoneKey'] == zoneKey)
    .map(SupplicationModel.fromJson)
    .toList(growable: false);

// The controller's own selection expressions.
List<SupplicationModel> _autoPlayable(List<SupplicationModel> all) =>
    all.where((e) => e.isAutoPlayable).toList();

void main() {
  group('marwah-same is guidance, and is playable by no path at all', () {
    test('it is classified as procedural guidance', () {
      expect(_model(kMarwah).contentKind,
          SupplicationContentKind.proceduralGuidance);
    });

    test('no path plays it: manual, auto, or voice search', () {
      final m = _model(kMarwah);
      expect(m.canPlayManually, isFalse,
          reason: 'the audio button is gated on canPlayManually');
      expect(m.isAutoPlayable, isFalse);
      expect(m.contentKind.isRecitable, isFalse);
      expect(m.contentKind.belongsInDuaSection, isFalse);
      // Voice search plays its single result without passing a button; the
      // guard in _playDua is the only thing between it and the speaker.
      final src =
          File('lib/Screens/Piligram/Duas/duas_screen.dart').readAsStringSync();
      expect(src.contains('if (!dua.canPlayManually) return;'), isTrue);
    });

    test('it renders as a guidance card, never as a dua', () {
      final p = SupplicationPartition.of(_zone('masaa'));
      expect(p.guidance.map((e) => e.duaId), contains(kMarwah));
      expect(p.recitable.map((e) => e.duaId), isNot(contains(kMarwah)));
      expect(p.evidence.map((e) => e.duaId), isNot(contains(kMarwah)));
    });

    test('its text is never handed to TTS, because TTS reads recitables', () {
      // DuaPlaybackService.play speaks textByLanguage(...). The only callers
      // are the controller (isAutoPlayable) and _playDua (canPlayManually);
      // marwah-same satisfies neither, so no caller can reach the speaker.
      final m = _model(kMarwah);
      expect(m.isAutoPlayable || m.canPlayManually, isFalse);
      expect(m.audioUrl.trim(), isEmpty,
          reason: 'an audio file would be a second playback path');
    });
  });

  group('entering generic masaa auto-plays nothing', () {
    test('none of the three records auto-play on zone entry', () {
      final auto = _autoPlayable(_zone('masaa')).map((e) => e.duaId);
      expect(auto, isNot(contains(kAyah)));
      expect(auto, isNot(contains(kDhikr)));
      expect(auto, isNot(contains(kMarwah)));
    });

    test('the whole Sa\'i corridor now auto-plays nothing at all', () {
      // Before Batch E, marwah-same was the single auto-playable record in
      // the corridor: entering it spoke an instructional sentence aloud in
      // a recitation voice. Nothing is spoken by location here any more.
      expect(_autoPlayable(_zone('masaa')), isEmpty);
    });
  });

  group('one canonical dhikr, pointed at rather than copied', () {
    test('exactly one record in the pack holds the dhikr text', () {
      final text = _model(kDhikr).text['ar']!.trim();
      final holders = _entries()
          .where((e) => (e['text']?['ar'] ?? '').toString().trim() == text)
          .map((e) => e['duaId'])
          .toList();
      expect(holders, [kDhikr],
          reason: 'a second copy would drift from this one on first edit');
    });

    test('no two records in one zone hold the same text', () {
      // Scoped to a zone on purpose. The ministry legitimately prints one
      // ayah in two places under two classifications — البقرة 201 appears
      // location-specific between the corners (p69) and again as a general
      // dua (p94) — and collapsing those would destroy a real distinction.
      // What must never happen is one text stored twice for one place,
      // which is exactly what copying the dhikr onto Marwah would create.
      final byZoneText = <String, List<String>>{};
      for (final e in _entries()) {
        final t = (e['text']?['ar'] ?? '').toString().trim();
        if (t.isEmpty) continue;
        byZoneText
            .putIfAbsent('${e['zoneKey']}\u0000$t', () => [])
            .add(e['duaId'] as String);
      }
      final dupes =
          byZoneText.entries.where((e) => e.value.length > 1).toList();
      expect(dupes, isEmpty,
          reason: 'same text twice in one zone: '
              '${dupes.map((e) => e.value).toList()}');
    });

    test('the cross-zone repeats of one text are only the known pair', () {
      // Pinned rather than asserted away: a NEW cross-zone duplicate is a
      // finding that must surface here, and this pair is documented above.
      final byText = <String, List<String>>{};
      for (final e in _entries()) {
        final t = (e['text']?['ar'] ?? '').toString().trim();
        if (t.isEmpty) continue;
        byText.putIfAbsent(t, () => []).add(e['duaId'] as String);
      }
      final dupes = byText.values.where((v) => v.length > 1).toList();
      expect(dupes, [
        [
          'moia-mukhtasar-1446-tawaf-between-corners',
          'moia-mukhtasar-1446-general-001'
        ],
      ]);
    });

    test('no record duplicates another\'s audio', () {
      final urls = _entries()
          .map((e) => (e['audioUrl'] ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      expect(urls.toSet().length, urls.length);
    });

    test('marwah points at the dhikr by id, and carries none of its text', () {
      final m = _model(kMarwah);
      expect(m.relatedRecordIds, [kDhikr]);
      final dhikrText = _model(kDhikr).text['ar']!.trim();
      expect(m.text['ar']!.contains(dhikrText), isFalse);
      expect(m.text['ar']!.contains('لا إله إلا الله'), isFalse,
          reason: 'the instruction must not quote the dhikr');
    });

    test('the relationship is a declared recitation link', () {
      final m = _model(kMarwah);
      expect(m.relatedRecordRole, SupplicationModel.recitationLink);
      expect(m.hasRecitationLink, isTrue);
      // The target really is recitable — the whole point of the role check.
      expect(_model(kDhikr).contentKind.isRecitable, isTrue);
    });

    test('a pointer with no declared role renders no link at all', () {
      final raw = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(_model(kMarwah).toJson()))
              as Map<String, dynamic>);
      raw.remove('relatedRecordRole');
      expect(SupplicationModel.fromJson(raw).hasRecitationLink, isFalse);
      raw['relatedRecordRole'] = 'teleport';
      expect(SupplicationModel.fromJson(raw).hasRecitationLink, isFalse,
          reason: 'an unknown role reads as no role, never as a link');
    });

    test('the link cannot bypass the target\'s manual-only policy', () {
      // Following the pointer lands the pilgrim on the target's own card.
      // Nothing about being pointed at changes what that card does.
      final target = _model(kDhikr);
      expect(target.isAutoPlayable, isFalse,
          reason: 'still blocked from location-driven playback');
      expect(target.recitationPolicy!.autoPlayCapability,
          RecitationPolicy.manualOnlyUntilTriggerSupported);
      // And the pointing card gains no policy and no playability of its own.
      final m = _model(kMarwah);
      expect(m.recitationPolicy, isNull);
      expect(m.canPlayManually, isFalse);
      expect(m.isAutoPlayable, isFalse);
    });

    test('following the link requires an explicit tap, and plays nothing', () {
      final src =
          File('lib/Screens/Piligram/Duas/duas_screen.dart').readAsStringSync();
      // The handler filters the list. It must not call playback.
      final body = src.substring(src.indexOf('void _openRelated('),
          src.indexOf('Future<void> _playDua('));
      expect(body.contains('_playDua'), isFalse);
      expect(body.contains('playbackService'), isFalse);
      expect(body.contains('_playbackService'), isFalse);
      // And it is wired to a button's onPressed, not to any lifecycle hook.
      expect(src.contains('onOpenRelated: () => _openRelated('), isTrue);
      final card = File(
        'lib/Screens/Piligram/Duas/widgets/content_kind_card.dart',
      ).readAsStringSync();
      expect(card.contains('onPressed: onOpenRelated'), isTrue);
    });

    test('the pointer changes neither recitability nor verification', () {
      final m = _model(kMarwah);
      expect(m.canPlayManually, isFalse,
          reason: 'pointing at a recitable record does not make one');
      expect(m.isVerifiedSource, isFalse);
      final target = _model(kDhikr);
      expect(target.canPlayManually, isTrue,
          reason: 'and the target keeps its own button');
      expect(target.isVerifiedSource, isFalse);
    });

    test('the dhikr keeps its policy, and is manual-only at both ends', () {
      final p = _model(kDhikr).recitationPolicy!;
      expect(p.frequency, 'repeat_count');
      expect(p.repeatCount, 3);
      expect(p.interleave, 'personal_dua');
      expect(p.autoRepeat, isFalse);
      expect(p.autoPlayCapability,
          RecitationPolicy.manualOnlyUntilTriggerSupported);
      expect(_model(kDhikr).canPlayManually, isTrue);
      expect(_model(kDhikr).isAutoPlayable, isFalse);
      // masaa is one zone spanning the corridor, so the single record is
      // already reachable at Safa and at Marwah with no second copy.
      expect(_model(kDhikr).zoneKey, 'masaa');
      expect(_model(kMarwah).zoneKey, 'masaa');
    });

    test('one press is one recitation — no path loops on repeatCount', () {
      for (final path in [
        'lib/Screens/Piligram/Home/services/dua_playback_service.dart',
        'lib/Screens/Piligram/Home/controllers/home_dua_controller.dart',
        'lib/Screens/Piligram/Duas/duas_screen.dart',
      ]) {
        expect(File(path).readAsStringSync().contains('repeatCount'), isFalse,
            reason: '$path: a player that repeated three times would speak '
                'over the dua the pilgrim is meant to make between them');
      }
    });
  });

  group('the verse is never presented as repeatable at Marwah', () {
    test('safa-ayah stays once-per-ritual and manual-only', () {
      final m = _model(kAyah);
      final p = m.recitationPolicy!;
      expect(p.isOncePerRitual, isTrue);
      expect(p.autoPlayCapability,
          RecitationPolicy.manualOnlyUntilTriggerSupported);
      expect(m.isAutoPlayable, isFalse);
      expect(m.canPlayManually, isTrue);
    });

    test('it displays the explicit non-repetition sentence', () {
      expect(_model(kAyah).usageNoteAr,
          'تُقرأ عند الصفا مرة واحدة قبل بدء السعي، ولا تُعاد عند المروة.');
    });

    test('the Marwah guidance scopes the repetition to the dhikr', () {
      final note = _model(kMarwah).usageNoteAr;
      expect(note, contains('ذكر الصفا'));
      expect(note, contains('ولا تُعاد عند المروة'),
          reason: 'the card must say what is NOT repeated, not only what is');
    });

    test('marwah points at the dhikr and at nothing else', () {
      expect(_model(kMarwah).relatedRecordIds, [kDhikr],
          reason: '«مثل ما قال على الصفا» reaches the dhikr, not the verse');
      expect(_model(kMarwah).relatedRecordIds, isNot(contains(kAyah)));
      // No other record in the pack points at the verse either.
      for (final e in _entries()) {
        final ids = (e['relatedRecordIds'] as List?)?.cast<String>() ?? [];
        expect(ids, isNot(contains(kAyah)),
            reason: '${e['duaId']} must not link the once-only verse');
      }
    });

    test('no usage note anywhere tells the pilgrim to repeat the verse', () {
      for (final e in _entries()) {
        final note = (e['usageNoteAr'] ?? '').toString();
        if (!note.contains('الصفا وَٱلۡمَرۡوَةَ') &&
            !note.contains('إِنَّ ٱلصَّفَا')) {
          continue;
        }
        expect(note.contains('لا تُعاد'), isTrue,
            reason: '${e['duaId']}: mentions the verse without its '
                'once-only scope');
      }
    });
  });

  group('the Worker distinguishes the once-only verse from the dhikr', () {
    final worker = File('assistant-proxy/worker.js').readAsStringSync();

    test('the prompt forbids extending a repetition to a neighbour', () {
      expect(worker.contains('REPEATED VS ONCE-ONLY'), isTrue);
      expect(
          worker.contains(
              'never tell the pilgrim to repeat a Quranic text whose own record says'),
          isTrue);
    });

    test('the prompt forbids reproducing a pointed-to text', () {
      expect(worker.contains('RELATED RECORDS'), isTrue);
      expect(
          worker.contains(
              'You must NOT reproduce the pointed-to text as though the pointing record'),
          isTrue);
    });

    test('the prompt says a repeat count is not an instruction to the app', () {
      expect(
          worker.contains('is a DESCRIPTION, never an instruction to the app'),
          isTrue);
      expect(
          worker.contains('of three does not mean the app will play the text'),
          isTrue);
    });

    test('the relation reaches the model as ids, never as text', () {
      expect(worker.contains('relatedRecordIds=\${JSON.stringify('), isTrue);
    });
  });

  group('online/offline round trips preserve the relation and the policies',
      () {
    test('marwah keeps its pointer, its note, and its unplayability', () {
      final back = SupplicationModel.fromJson(
          jsonDecode(jsonEncode(_model(kMarwah).toJson()))
              as Map<String, dynamic>);
      expect(back.relatedRecordIds, [kDhikr]);
      expect(back.relatedRecordRole, SupplicationModel.recitationLink);
      expect(back.hasRecitationLink, isTrue);
      expect(back.usageNoteAr, _model(kMarwah).usageNoteAr);
      expect(back.canPlayManually, isFalse);
      expect(back.isAutoPlayable, isFalse);
      expect(back.contentKind, SupplicationContentKind.proceduralGuidance);
    });

    test('the dhikr keeps its full policy offline', () {
      final back = SupplicationModel.fromJson(
          jsonDecode(jsonEncode(_model(kDhikr).toJson()))
              as Map<String, dynamic>);
      expect(back.recitationPolicy!.repeatCount, 3);
      expect(back.recitationPolicy!.interleave, 'personal_dua');
      expect(back.recitationPolicy!.autoRepeat, isFalse);
      expect(back.recitationPolicy!.autoPlayCapability,
          RecitationPolicy.manualOnlyUntilTriggerSupported);
      expect(back.usageNoteAr, isNotEmpty);
      expect(back.text['ar'], _model(kDhikr).text['ar']);
    });

    test('the verse keeps its once-only note offline', () {
      final back = SupplicationModel.fromJson(
          jsonDecode(jsonEncode(_model(kAyah).toJson()))
              as Map<String, dynamic>);
      expect(back.usageNoteAr, contains('ولا تُعاد عند المروة'));
      expect(back.recitationPolicy!.isOncePerRitual, isTrue);
    });

    test('a cached self-reference or duplicate is dropped on the way in', () {
      // Client leniency: the importer refuses these outright, but a record
      // cached before that check existed must not resurrect them.
      final raw = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(_model(kMarwah).toJson()))
              as Map<String, dynamic>);
      raw['relatedRecordIds'] = [kMarwah, kDhikr, kDhikr, '  '];
      final back = SupplicationModel.fromJson(raw);
      expect(back.relatedRecordIds, [kDhikr]);
    });
  });

  group('every record stays unverified', () {
    test('all 85 of them', () {
      final entries = _entries();
      expect(entries, hasLength(85));
      for (final e in entries) {
        expect(e['verificationStatus'], 'unverified', reason: '${e['duaId']}');
        expect(e['verifiedAt'], isNull);
        expect(e['verifiedBy'], isNull);
      }
    });
  });
}
