// The semantic trigger gap at the Sa'i corridor.
//
// `masaa` is ONE polygon covering the whole corridor between Safa and
// Marwah. Entering it proves the pilgrim is somewhere in the Sa'i — it does
// NOT prove they are on their first approach to Safa. The app owns no event
// that means "first Safa approach", and `currentRitual` is a zone
// classifier ('tawaf' / 'sai'), not a ritual session identity.
//
// So the two Safa records declare `autoPlayCapability:
// manual_only_until_trigger_supported`. The failure this prevents: the
// pilgrim walks back past Safa on a later circuit and the app recites
// «إِنَّ الصَّفَا وَالْمَرْوَةَ…» at them as though they had just begun.
//
// The fix is fail-closed in one direction only: location may not start the
// audio, the pilgrim's own finger still may. Blocking a recitation from
// being read TO someone is not blocking them from reading it.
//
// These tests reproduce the entry into `masaa` by applying the controller's
// own selection expressions to the pack records carrying `zoneKey: masaa`.
// `HomeDuaController` cannot be constructed under `flutter test` (it takes
// live `FirebaseFirestore` and `FirebaseAuth` handles), so the last group
// pins the controller source to the expressions reproduced here — if the
// controller ever stops filtering on `isAutoPlayable`, that guard fails and
// this simulation stops silently drifting from the code it stands in for.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Duas/widgets/content_kind_card.dart';
import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';

List<SupplicationModel> _zone(String zoneKey) {
  final pack = jsonDecode(
    File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return (pack['entries'] as List)
      .cast<Map<String, dynamic>>()
      .where((e) => e['zoneKey'] == zoneKey)
      .map(SupplicationModel.fromJson)
      .toList(growable: false);
}

SupplicationModel _one(String duaId) =>
    _zone('masaa').firstWhere((e) => e.duaId == duaId);

// The controller's own two expressions, reproduced verbatim.
List<SupplicationModel> _recitable(List<SupplicationModel> all) =>
    all.where((e) => e.contentKind.belongsInDuaSection).toList();
List<SupplicationModel> _autoPlayable(List<SupplicationModel> all) =>
    all.where((e) => e.isAutoPlayable).toList();

void main() {
  group('entering the generic masaa zone starts nothing', () {
    test('safa-ayah does not auto-play on masaa entry', () {
      final entered = _zone('masaa');
      expect(entered.map((e) => e.duaId), contains('moia-1446-safa-ayah'));
      expect(_autoPlayable(entered).map((e) => e.duaId),
          isNot(contains('moia-1446-safa-ayah')),
          reason: 'being inside the corridor is not being at the first Safa '
              'approach; nothing in the app can tell the two apart');
    });

    test('safa-dhikr does not auto-play on masaa entry', () {
      expect(_autoPlayable(_zone('masaa')).map((e) => e.duaId),
          isNot(contains('moia-1446-safa-dhikr')));
    });

    test('the block is the declared capability, not the id or the title', () {
      for (final id in ['moia-1446-safa-ayah', 'moia-1446-safa-dhikr']) {
        final m = _one(id);
        expect(m.recitationPolicy!.autoPlayCapability,
            RecitationPolicy.manualOnlyUntilTriggerSupported,
            reason: '$id must declare the block explicitly');
        expect(m.recitationPolicy!.blocksAutoPlay, isTrue);
      }
      // Nothing anywhere may special-case these two records by identity.
      // (`first_safa_approach` in the trigger vocabulary is a value the data
      // declares, not a branch on a record — that one is allowed.)
      for (final path in [
        'lib/Screens/Piligram/Home/models/supplication_model.dart',
        'lib/Screens/Piligram/Home/controllers/home_dua_controller.dart',
        'lib/Screens/Piligram/Duas/duas_screen.dart',
      ]) {
        final src = File(path).readAsStringSync();
        for (final needle in ['moia-1446-safa', 'safa-ayah', 'safa-dhikr']) {
          expect(src.contains(needle), isFalse,
              reason: '$path names a record; the rule must be data-driven');
        }
      }
    });

    test('a masaa record with no such capability is unaffected', () {
      // The block must be a property of the two records, not of the zone.
      final marwah = _one('moia-1446-marwah-same');
      expect(marwah.recitationPolicy, isNull);
      expect(_autoPlayable(_zone('masaa')).map((e) => e.duaId),
          contains('moia-1446-marwah-same'));
    });
  });

  group('both Safa records stay visible and manually playable', () {
    test('they are still in the recitable section', () {
      final ids = _recitable(_zone('masaa')).map((e) => e.duaId);
      expect(ids, contains('moia-1446-safa-ayah'));
      expect(ids, contains('moia-1446-safa-dhikr'));
    });

    test('their audio button still works', () {
      for (final id in ['moia-1446-safa-ayah', 'moia-1446-safa-dhikr']) {
        final m = _one(id);
        expect(m.canPlayManually, isTrue,
            reason: '$id: the pilgrim may always choose to recite');
        expect(m.isAutoPlayable, isFalse);
      }
    });

    test('the screen guard admits them, and refuses guidance', () {
      // `_playDua` is guarded on `canPlayManually`, the last check before
      // speech — voice search reaches playback without passing a button.
      final src =
          File('lib/Screens/Piligram/Duas/duas_screen.dart').readAsStringSync();
      expect(src.contains('if (!dua.canPlayManually) return;'), isTrue);
      expect(src.contains('if (!dua.isAutoPlayable) return;'), isFalse,
          reason: 'guarding manual playback on the auto-play rule would stop '
              'the pilgrim from reciting the ayah at all');
      expect(_one('moia-1446-sai-seven').canPlayManually, isFalse);
    });

    test('the partition shows them as duas, not as guidance', () {
      final p = SupplicationPartition.of(_zone('masaa'));
      final duaIds = p.recitable.map((e) => e.duaId);
      expect(duaIds, contains('moia-1446-safa-ayah'));
      expect(duaIds, contains('moia-1446-safa-dhikr'));
      expect(p.guidance.map((e) => e.duaId),
          containsAll(['moia-1446-sai-seven', 'moia-1446-sai-sunan']));
    });
  });

  group('return-hajar is never playable, by any path', () {
    test('not manually, not automatically, not in the dua section', () {
      final pack = jsonDecode(
        File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final m = SupplicationModel.fromJson((pack['entries'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['duaId'] == 'moia-1446-return-hajar'));
      expect(m.contentKind, SupplicationContentKind.proceduralGuidance);
      expect(m.canPlayManually, isFalse);
      expect(m.isAutoPlayable, isFalse);
      expect(m.contentKind.isRecitable, isFalse);
      expect(_recitable([m]), isEmpty);
      expect(_autoPlayable([m]), isEmpty);
      expect(SupplicationPartition.of([m]).guidance, hasLength(1));
    });
  });

  group('the instructions survive an online/offline round trip', () {
    test('the capability is persisted, not recomputed on the wire', () {
      for (final id in ['moia-1446-safa-ayah', 'moia-1446-safa-dhikr']) {
        final cached = jsonDecode(jsonEncode(_one(id).toJson()));
        final back = SupplicationModel.fromJson(cached as Map<String, dynamic>);
        expect(back.recitationPolicy!.autoPlayCapability,
            RecitationPolicy.manualOnlyUntilTriggerSupported,
            reason: '$id: an offline cache that drops the capability would '
                'auto-play the ayah with no network');
        expect(back.isAutoPlayable, isFalse, reason: id);
        expect(back.canPlayManually, isTrue, reason: id);
        expect(back.recitationPolicy!.instructionAr(),
            _one(id).recitationPolicy!.instructionAr());
      }
    });

    test(
        'a cached client that never heard of the capability fails open '
        'only for auto-play, never for the text', () {
      // Forward compatibility runs one way: a client may ignore a value it
      // does not know (it is only ever a restriction), but the importer may
      // not — see scripts/import_source_pack.mjs.
      final stripped = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(_one('moia-1446-safa-ayah').toJson()))
              as Map<String, dynamic>);
      (stripped['recitationPolicy'] as Map)['autoPlayCapability'] = 'newer';
      final back = SupplicationModel.fromJson(stripped);
      expect(back.recitationPolicy!.autoPlayCapability, isNull,
          reason: 'an unrecognised capability reads as absent, never as a '
              'capability the client cannot honour');
      expect(back.recitationPolicy!.frequency, 'once_per_ritual',
          reason: 'the rest of the policy must survive intact');
      expect(back.text['ar'], _one('moia-1446-safa-ayah').text['ar']);
    });
  });

  group('the simulation above still matches the controller', () {
    final src = File(
      'lib/Screens/Piligram/Home/controllers/home_dua_controller.dart',
    ).readAsStringSync();

    test('auto-play is selected by isAutoPlayable', () {
      expect(src.contains('.where((e) => e.isAutoPlayable)'), isTrue,
          reason: 'if this expression changes, the masaa tests above stop '
              'testing what the app actually does');
    });

    test('the dua section is selected by belongsInDuaSection', () {
      expect(src.contains('.where((e) => e.contentKind.belongsInDuaSection)'),
          isTrue);
    });

    test('the once-per-ritual limitation is documented, not claimed away', () {
      // There is no durable ritual-session identifier in the app; the memory
      // is per controller instance. The block above is what makes that
      // harmless today — so the honesty has to stay in the source.
      expect(src.contains('_playedOncePerRitual'), isTrue);
      expect(src.contains('resetRitualPlaybackState'), isTrue);
      expect(src.contains('ليست مفروضة فرضًا كاملًا'), isTrue,
          reason: 'the limitation must remain stated where it lives');
    });
  });
}
