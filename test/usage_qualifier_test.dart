// `usageQualifier` — the field that lets the app say a text is an optional
// addition without implying every other text is obligatory.
//
// The rule this file defends, stated once: **absence is not obligation.**
// A record with no qualifier is a record the source did not describe. There
// is no `mandatory` value, no "required" badge, and no code path that
// derives one from a null. These tests fail if any of that changes.
//
// The second half covers the defect that made the field necessary to test
// end-to-end: the Talbiyah carries `zoneKey: ""` because the source ties it
// to a rite, not a place. Pinning it to one miqat hides it from the other
// two; leaving it unrouted hid it from all three.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';
import 'package:dhakker/services/assistant_service.dart';

SupplicationModel _model({
  String duaId = 'x',
  String zoneKey = '',
  SupplicationContentKind kind = SupplicationContentKind.specificText,
  SupplicationUsageQualifier? qualifier,
  String ritualKey = '',
  List<String> appliesTo = const [],
}) {
  return SupplicationModel(
    duaId: duaId,
    zoneId: '',
    title: const {'ar': 'ع', 'en': 'e'},
    text: const {'ar': 'نص', 'en': ''},
    audioMode: 'tts',
    audioUrl: '',
    languageCodes: const ['ar'],
    isActive: true,
    updatedAt: null,
    usageCount: 0,
    contentKind: kind,
    zoneKey: zoneKey,
    usageQualifier: qualifier,
    ritualKey: ritualKey,
    appliesToZoneKeys: appliesTo,
  );
}

const _miqats = [
  'miqat_dhul_hulayfah',
  'miqat_yalamlam',
  'miqat_qarn_manazil',
];

void main() {
  group('absence of a qualifier is never an obligation', () {
    test('there is no mandatory/required value in the enum', () {
      final names =
          SupplicationUsageQualifier.values.map((e) => e.name).toList();
      expect(names, ['optionalAddition']);
      for (final n in names) {
        expect(n.toLowerCase(), isNot(contains('mandat')));
        expect(n.toLowerCase(), isNot(contains('requir')));
        expect(n.toLowerCase(), isNot(contains('oblig')));
      }
    });

    test('an unqualified record reads as null, not as a default value', () {
      expect(_model().usageQualifier, isNull);
      expect(SupplicationUsageQualifier.fromRaw(null), isNull);
      expect(SupplicationUsageQualifier.fromRaw(''), isNull);
      expect(SupplicationUsageQualifier.fromRaw('   '), isNull);
    });

    test('an unknown qualifier degrades to null, never to an invented one', () {
      // A future value this build does not know must not be guessed at.
      expect(SupplicationUsageQualifier.fromRaw('mandatory'), isNull);
      expect(SupplicationUsageQualifier.fromRaw('optional'), isNull);
      expect(SupplicationUsageQualifier.fromRaw('OPTIONAL_ADDITION'), isNull);
    });

    test('the optional addition round-trips through raw', () {
      expect(SupplicationUsageQualifier.fromRaw('optional_addition'),
          SupplicationUsageQualifier.optionalAddition);
      expect(
          SupplicationUsageQualifier.optionalAddition.raw, 'optional_addition');
    });

    test('badges exist in both languages and name only optionality', () {
      const q = SupplicationUsageQualifier.optionalAddition;
      expect(q.badgeAr(), 'زيادة جائزة');
      expect(q.badgeEn(), 'Optional addition');
    });
  });

  group('the field survives every hop it has to make', () {
    test('fromJson reads it, toJson writes it', () {
      final decoded = SupplicationModel.fromJson({
        'duaId': 'z',
        'title': {'ar': 'ع'},
        'text': {'ar': 'ن'},
        'contentKind': 'specific_text',
        'zoneKey': '',
        'usageQualifier': 'optional_addition',
        'ritualKey': 'ihram',
        'appliesToZoneKeys': _miqats,
      });
      expect(
          decoded.usageQualifier, SupplicationUsageQualifier.optionalAddition);
      expect(decoded.ritualKey, 'ihram');
      expect(decoded.appliesToZoneKeys, _miqats);

      final json = decoded.toJson();
      expect(json['usageQualifier'], 'optional_addition');
      expect(json['ritualKey'], 'ihram');
      expect(json['appliesToZoneKeys'], _miqats);

      // A full round trip — this is the offline cache path, where a dropped
      // field means the badge vanishes as soon as the app goes offline.
      final again = SupplicationModel.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(json)) as Map));
      expect(again.usageQualifier, decoded.usageQualifier);
      expect(again.ritualKey, decoded.ritualKey);
      expect(again.appliesToZoneKeys, decoded.appliesToZoneKeys);
    });

    test('an unqualified record serialises null, not a placeholder', () {
      final json = _model().toJson();
      expect(json.containsKey('usageQualifier'), isTrue,
          reason: 'the key must be written, so its absence is not ambiguous');
      expect(json['usageQualifier'], isNull);
      expect(SupplicationModel.fromJson(json).usageQualifier, isNull);
    });

    test('a record with no ritual scope stays empty, not defaulted', () {
      final m = _model();
      expect(m.ritualKey, '');
      expect(m.appliesToZoneKeys, isEmpty);
    });

    test('VerifiedExcerpt carries the qualifier from the proxy', () {
      final list = VerifiedExcerpt.listFrom([
        {
          'documentId': 'a',
          'title': 't',
          'authority': 'x',
          'text': 'نص',
          'textLanguage': 'ar',
          'usageQualifier': 'optional_addition',
        },
        {
          'documentId': 'b',
          'title': 't',
          'authority': 'x',
          'text': 'نص',
          'textLanguage': 'ar',
        },
      ]);
      expect(list, hasLength(2));
      expect(list[0].usageQualifier, 'optional_addition');
      expect(list[0].isOptionalAddition, isTrue);
      // An older proxy sends no such field — that is silence, not obligation.
      expect(list[1].usageQualifier, isNull);
      expect(list[1].isOptionalAddition, isFalse);
    });
  });

  group('an optional addition is shown but never auto-played', () {
    final optional = _model(
      duaId: 'ziyadah',
      qualifier: SupplicationUsageQualifier.optionalAddition,
    );
    final plain = _model(duaId: 'talbiyah');

    test('it is still a recitable text the pilgrim may choose', () {
      expect(optional.contentKind.belongsInDuaSection, isTrue,
          reason: 'it must remain visible and manually playable');
    });

    test('it is excluded from automatic playback', () {
      expect(optional.isAutoPlayable, isFalse);
      expect(plain.isAutoPlayable, isTrue);
    });

    test('guidance stays excluded too, for its own reason', () {
      final guidance = _model(kind: SupplicationContentKind.proceduralGuidance);
      expect(guidance.isAutoPlayable, isFalse);
    });

    test('the real Talbiyah and its addition are two separate texts', () {
      // Nothing may concatenate the addition onto the base text: heard or
      // read as one run, the addition reads as part of the Talbiyah. Checked
      // against the actual pack rather than fixtures — identical dummy
      // strings would make this pass without proving anything.
      final pack = jsonDecode(
        File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final entries = (pack['entries'] as List).cast<Map<String, dynamic>>();
      String textOf(String id) =>
          (entries.firstWhere((e) => e['duaId'] == id)['text']
              as Map<String, dynamic>)['ar'] as String;

      final base = textOf('moia-mukhtasar-1446-umrah-talbiyah');
      final addition = textOf('moia-mukhtasar-1446-umrah-talbiyah-ziyadah');

      expect(base, isNotEmpty);
      expect(addition, isNotEmpty);
      expect(base, isNot(addition));
      expect(base, isNot(contains(addition)),
          reason: 'the addition must not be embedded in the base text');
      expect(addition, isNot(contains(base)),
          reason: 'the base text must not be embedded in the addition');
    });
  });

  group('ritual-scoped texts reach every zone they name', () {
    final talbiyah = _model(
      duaId: 'talbiyah',
      zoneKey: '',
      ritualKey: 'ihram',
      appliesTo: _miqats,
    );

    for (final miqat in _miqats) {
      test('the Talbiyah applies at $miqat', () {
        expect(talbiyah.appliesToZone(miqat), isTrue);
      });
    }

    test('it does not appear in a zone it does not name', () {
      for (final other in ['hajar_aswad', 'mataf', 'masaa', 'arafat', '']) {
        expect(talbiyah.appliesToZone(other), isFalse,
            reason: 'a rite-scoped text must not leak into $other');
      }
    });

    test('its zoneKey stays empty — it is not pinned to one miqat', () {
      expect(talbiyah.zoneKey, '');
      expect(talbiyah.ritualKey, 'ihram');
    });

    test('a place-tied record still matches by zoneKey alone', () {
      final tied = _model(duaId: 'hajar', zoneKey: 'hajar_aswad');
      expect(tied.appliesToZone('hajar_aswad'), isTrue);
      expect(tied.appliesToZone('mataf'), isFalse);
    });

    test('a record tied to nothing matches nothing', () {
      expect(_model().appliesToZone('hajar_aswad'), isFalse);
      expect(_model().appliesToZone(''), isFalse);
    });
  });

  group('the source pack states all of this', () {
    final pack = jsonDecode(
      File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final entries = (pack['entries'] as List).cast<Map<String, dynamic>>();

    Map<String, dynamic> entry(String id) =>
        entries.firstWhere((e) => e['duaId'] == id);

    test('the base Talbiyah carries no qualifier at all', () {
      final base = entry('moia-mukhtasar-1446-umrah-talbiyah');
      expect(base.containsKey('usageQualifier'), isFalse,
          reason: 'absence is the statement — do not add a null placeholder');
    });

    test('the ziyadah is marked optional_addition', () {
      final z = entry('moia-mukhtasar-1446-umrah-talbiyah-ziyadah');
      expect(z['usageQualifier'], 'optional_addition');
    });

    test('both stay tied to the rite, not to one miqat', () {
      for (final id in [
        'moia-mukhtasar-1446-umrah-talbiyah',
        'moia-mukhtasar-1446-umrah-talbiyah-ziyadah',
      ]) {
        final e = entry(id);
        expect(e['zoneKey'], '');
        expect(e['ritualKey'], 'ihram');
        expect((e['appliesToZoneKeys'] as List).cast<String>(), _miqats);
      }
    });

    test('no record in the pack claims to be mandatory', () {
      for (final e in entries) {
        final q = e['usageQualifier'];
        if (q == null) continue;
        expect(q, 'optional_addition',
            reason: '${e['duaId']} uses an unsupported qualifier');
      }
    });

    test('nothing in the pack was verified by this change', () {
      for (final e in entries) {
        expect(e['verificationStatus'], 'unverified');
      }
    });
  });
}
