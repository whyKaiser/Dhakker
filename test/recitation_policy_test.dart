// `recitationPolicy` — HOW a text is performed.
//
// Kept out of `usageQualifier` deliberately. That field says what a text IS
// (an optional addition); this says how it is performed (once, or three
// times with the pilgrim's own dua between). Folding them into one field
// would make «جائزة» and «ثلاث مرات» compete for one slot when both can be
// true of one text.
//
// The rule that matters most: the policy never makes anything recitable.
// `contentKind` decides that and stays authoritative.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Duas/widgets/content_kind_card.dart';
import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';
import 'package:dhakker/services/assistant_service.dart';

Map<String, dynamic> _entry(String id) {
  final pack = jsonDecode(
    File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return (pack['entries'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((e) => e['duaId'] == id);
}

void main() {
  group('Batch D classifications', () {
    test('return-hajar is guidance, and can never be played', () {
      final e = _entry('moia-1446-return-hajar');
      expect(e['contentKind'], 'procedural_guidance');

      final m = SupplicationModel.fromJson(e);
      expect(m.contentKind.isRecitable, isFalse);
      expect(m.contentKind.belongsInDuaSection, isFalse);
      expect(m.isAutoPlayable, isFalse,
          reason: 'a description of what the pilgrim does must not be read '
              'aloud as though it were a dhikr');
      expect(SupplicationPartition.of([m]).recitable, isEmpty);
      expect(SupplicationPartition.of([m]).guidance, hasLength(1));
    });

    test('safa-ayah keeps its kind, text and Quran authority', () {
      final e = _entry('moia-1446-safa-ayah');
      expect(e['contentKind'], 'specific_text');
      expect(e['textAuthority'], 'مجمع الملك فهد لطباعة المصحف الشريف');
      expect(e['quranRef'], {
        'surah': 2,
        'ayat': [158]
      });
      // Compared against the pinned file, not a literal typed here: a
      // hand-copied Arabic string in a test is the same transcription hazard
      // the record itself was rescued from. This assertion caught exactly
      // that when it was first written as a literal.
      final rows = (jsonDecode(
        File('third_party/kfgqpc/hafsData_v2-0.json').readAsStringSync(),
      ) as List)
          .cast<Map<String, dynamic>>();
      final official = (rows.firstWhere((r) =>
              int.parse('${r['sura_no']}') == 2 &&
              int.parse('${r['aya_no']}') == 158)['aya_text'] as String)
          .replaceAll(RegExp(r'[\uFB50-\uFDFF\uFE70-\uFEFF]+$'), '')
          .trim();
      expect(official.contains(e['text']['ar'] as String), isTrue,
          reason: 'the stored text must be a contiguous slice of 2:158');
    });

    test('safa-dhikr keeps its kind and its exact wording', () {
      final e = _entry('moia-1446-safa-dhikr');
      expect(e['contentKind'], 'specific_text');
      expect(e['text']['ar'], startsWith('لَا إِلَهَ إِلَّا اللهُ وَحْدَهُ'));
      expect(e['text']['ar'], endsWith('وَهَزَمَ الْأَحْزَابَ وَحْدَهُ'));
    });
  });

  group('the policies say what the printed page says', () {
    test('safa-ayah is once per ritual, triggered at the first approach', () {
      final p = _entry('moia-1446-safa-ayah')['recitationPolicy']
          as Map<String, dynamic>;
      expect(p['frequency'], 'once_per_ritual');
      expect(p['trigger'], 'first_safa_approach');
      expect(p['autoRepeat'], isFalse);
      expect(p.containsKey('repeatCount'), isFalse,
          reason: 'a count belongs only to repeat_count');
    });

    test('safa-dhikr is three times with personal dua between', () {
      final p = _entry('moia-1446-safa-dhikr')['recitationPolicy']
          as Map<String, dynamic>;
      expect(p['frequency'], 'repeat_count');
      expect(p['repeatCount'], 3);
      expect(p['interleave'], 'personal_dua');
      expect(p['autoRepeat'], isFalse,
          reason: 'a repetition the pilgrim fills with their own dua cannot '
              'be performed for them by a player');
    });

    test('safa-dhikr carries only the citation the page prints', () {
      final refs = (_entry('moia-1446-safa-dhikr')['sourceReferences'] as List)
          .cast<Map<String, dynamic>>();
      expect(refs, hasLength(1));
      expect(refs.single['collection'], 'صحيح مسلم');
      expect(refs.single['reference'], '1218');
      expect(refs.single['citedBy'], 'moia_1446');
      expect(refs.single['citedOnPage'], 72);
    });

    test('records the source did not qualify carry no policy', () {
      expect(_entry('moia-1446-return-hajar')['recitationPolicy'], isNull);
      expect(_entry('moia-1446-maqam-ayah')['recitationPolicy'], isNull);
    });
  });

  group('the policy never grants recitability', () {
    SupplicationModel withPolicy(
            SupplicationContentKind kind, RecitationPolicy? p) =>
        SupplicationModel(
          duaId: 'x',
          zoneId: '',
          title: const {'ar': 'ع'},
          text: const {'ar': 'ن'},
          audioMode: 'tts',
          audioUrl: '',
          languageCodes: const ['ar'],
          isActive: true,
          updatedAt: null,
          usageCount: 0,
          contentKind: kind,
          zoneKey: 'masaa',
          recitationPolicy: p,
        );

    const thrice = RecitationPolicy(
      frequency: 'repeat_count',
      repeatCount: 3,
      interleave: 'personal_dua',
    );

    test('a repeat count on guidance does not make it recitable', () {
      final m = withPolicy(SupplicationContentKind.proceduralGuidance, thrice);
      expect(m.recitationPolicy, isNotNull);
      expect(m.contentKind.isRecitable, isFalse);
      expect(m.isAutoPlayable, isFalse);
    });

    test('nor on a narration', () {
      expect(
          withPolicy(SupplicationContentKind.contextualEvidence, thrice)
              .isAutoPlayable,
          isFalse);
    });

    test('a recitable text with no policy still behaves as before', () {
      expect(
          withPolicy(SupplicationContentKind.specificText, null).isAutoPlayable,
          isTrue);
    });

    test('the policy has no bearing on verification', () {
      final e = _entry('moia-1446-safa-dhikr');
      expect(e['recitationPolicy'], isNotNull);
      expect(e['verificationStatus'], 'unverified');
      expect(e['verifiedAt'], isNull);
      expect(e['contentHash'], isNull);
    });
  });

  group('parsing refuses to invent a policy', () {
    test('an unknown frequency reads as no policy at all', () {
      for (final bad in [
        {'frequency': 'mandatory'},
        {'frequency': 'always'},
        {'frequency': ''},
        {'repeatCount': 3},
      ]) {
        expect(RecitationPolicy.fromJson(bad), isNull, reason: '$bad');
      }
      expect(RecitationPolicy.fromJson(null), isNull);
      expect(RecitationPolicy.fromJson('nope'), isNull);
    });

    test('an out-of-range or missing repeat count voids the policy', () {
      for (final n in [0, 11, -1, null]) {
        expect(
            RecitationPolicy.fromJson(
                {'frequency': 'repeat_count', 'repeatCount': n}),
            isNull,
            reason: 'repeatCount $n');
      }
    });

    test('unknown trigger or interleave values are dropped, not carried', () {
      final p = RecitationPolicy.fromJson({
        'frequency': 'once_per_ritual',
        'trigger': 'whenever_you_like',
        'interleave': 'a_song',
      })!;
      expect(p.trigger, isNull);
      expect(p.interleave, isNull);
    });

    test('autoRepeat is forced false whenever an interleave is present', () {
      // Even if a pack somehow claimed otherwise.
      final p = RecitationPolicy.fromJson({
        'frequency': 'repeat_count',
        'repeatCount': 3,
        'interleave': 'personal_dua',
        'autoRepeat': true,
      })!;
      expect(p.autoRepeat, isFalse);
    });

    test('there is no mandatory frequency, and none can be read in', () {
      expect(RecitationPolicy.fromJson({'frequency': 'mandatory'}), isNull);
      final src = File(
        'lib/Screens/Piligram/Home/models/supplication_model.dart',
      ).readAsStringSync();
      expect(src.contains("'mandatory'"), isFalse);
    });
  });

  group('the instruction text is fixed, not generated', () {
    test('once per ritual reads as the source states it', () {
      const p = RecitationPolicy(
          frequency: 'once_per_ritual', trigger: 'first_safa_approach');
      expect(p.instructionAr(), 'تُقرأ مرة واحدة عند بداية السعي، ولا تُعاد');
    });

    test('three times with dua between reads as the source states it', () {
      const p = RecitationPolicy(
          frequency: 'repeat_count',
          repeatCount: 3,
          interleave: 'personal_dua');
      expect(p.instructionAr(), 'يُكرَّر 3 مرات، ويدعو بين المرات');
    });

    test('a repeat with no interleave omits the dua clause', () {
      const p = RecitationPolicy(frequency: 'repeat_count', repeatCount: 3);
      expect(p.instructionAr(), 'يُكرَّر 3 مرات');
    });
  });

  group('the instruction reaches the pilgrim', () {
    testWidgets('the note renders the once-only instruction', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: RecitationPolicyNote(
            policy: RecitationPolicy(
                frequency: 'once_per_ritual', trigger: 'first_safa_approach'),
          ),
        ),
      ));
      expect(find.text('تُقرأ مرة واحدة عند بداية السعي، ولا تُعاد'),
          findsOneWidget);
    });

    testWidgets('and the three-times instruction', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: RecitationPolicyNote(
            policy: RecitationPolicy(
                frequency: 'repeat_count',
                repeatCount: 3,
                interleave: 'personal_dua'),
          ),
        ),
      ));
      expect(find.text('يُكرَّر 3 مرات، ويدعو بين المرات'), findsOneWidget);
    });

    testWidgets('a record with no policy shows no note', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: RecitationPolicyNote(policy: null)),
      ));
      expect(find.byType(Text), findsNothing);
    });
  });

  group('nothing repeats the text on the pilgrim\'s behalf', () {
    test('the stored text is one recitation, not three concatenated', () {
      final text = _entry('moia-1446-safa-dhikr')['text']['ar'] as String;
      const opening = 'لَا إِلَهَ إِلَّا اللهُ وَحْدَهُ لَا شَرِيكَ لَهُ';
      expect(opening.allMatches(text).length, 1,
          reason: 'the record must hold ONE recitation; the count lives in '
              'the policy, never in duplicated text');
    });

    test('no code multiplies text by repeatCount', () {
      // The failure this guards: a player that "helpfully" plays three times
      // would speak over the dua the pilgrim is meant to make between them.
      for (final path in [
        'lib/Screens/Piligram/Home/services/dua_playback_service.dart',
        'lib/Screens/Piligram/Home/controllers/home_dua_controller.dart',
        'lib/Screens/Piligram/Duas/duas_screen.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(RegExp(r'repeatCount').hasMatch(src), isFalse,
            reason: '$path consults repeatCount — playback must stay one '
                'recitation per user action');
      }
    });

    test('autoRepeat is false on every policy in the pack', () {
      final pack = jsonDecode(
        File('source_packs/moia_mukhtasar_1446_umrah.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final e in (pack['entries'] as List).cast<Map<String, dynamic>>()) {
        final p = e['recitationPolicy'];
        if (p == null) continue;
        expect((p as Map)['autoRepeat'], isFalse, reason: '${e['duaId']}');
      }
    });
  });

  group('online and offline agree', () {
    test('the policy survives a full JSON round trip', () {
      final m = SupplicationModel.fromJson(_entry('moia-1446-safa-dhikr'));
      expect(m.recitationPolicy, isNotNull);
      final again = SupplicationModel.fromJson(
          jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
      expect(again.recitationPolicy!.frequency, 'repeat_count');
      expect(again.recitationPolicy!.repeatCount, 3);
      expect(again.recitationPolicy!.interleave, 'personal_dua');
      expect(again.recitationPolicy!.autoRepeat, isFalse);
      expect(again.recitationPolicy!.instructionAr(),
          m.recitationPolicy!.instructionAr());
    });

    test('once-per-ritual survives too', () {
      final m = SupplicationModel.fromJson(_entry('moia-1446-safa-ayah'));
      final again = SupplicationModel.fromJson(
          jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
      expect(again.recitationPolicy!.isOncePerRitual, isTrue);
      expect(again.recitationPolicy!.trigger, 'first_safa_approach');
    });

    test('an old client that sends no policy still parses', () {
      final m = SupplicationModel.fromJson({
        'duaId': 'x',
        'title': {'ar': 'ع'},
        'text': {'ar': 'ن'},
        'contentKind': 'specific_text',
      });
      expect(m.recitationPolicy, isNull);
      expect(m.isAutoPlayable, isTrue,
          reason: 'the absence of a policy must not change old behaviour');
    });
  });

  group('the assistant carries the policy as a fact', () {
    test('VerifiedExcerpt parses a known policy and drops an unknown one', () {
      final ok = VerifiedExcerpt.listFrom([
        {
          'documentId': 'a',
          'title': 't',
          'authority': 'x',
          'text': 'نص',
          'textLanguage': 'ar',
          'recitationPolicy': {'frequency': 'repeat_count', 'repeatCount': 3},
        },
      ]);
      expect(ok.single.recitationPolicy!['repeatCount'], 3);

      final bad = VerifiedExcerpt.listFrom([
        {
          'documentId': 'b',
          'title': 't',
          'authority': 'x',
          'text': 'نص',
          'textLanguage': 'ar',
          'recitationPolicy': {'frequency': 'mandatory'},
        },
      ]);
      expect(bad.single.recitationPolicy, isNull,
          reason: 'an unknown policy must read as absent, never as invented');
    });
  });
}
