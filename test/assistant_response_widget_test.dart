import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dhakker/data/offline_knowledge_repository.dart';
import 'package:dhakker/services/assistant_service.dart';
import 'package:dhakker/Screens/Assistant/assistant_screen.dart';

/// Widget tests against the REAL production widgets used by
/// `AssistantScreen` — `AssistantResponseMeta` and `AssistantMetaChip`,
/// extracted from `_AssistantScreenState` specifically so they can be
/// exercised here without booting Firebase, speech-to-text, TTS, or Bloc
/// providers (which the full `AssistantScreen` needs to build).
void main() {
  Widget harness(AssistantResponse response, {bool isRtl = false}) {
    return MaterialApp(
      home: Scaffold(
        body: AssistantResponseMeta(
          response: response,
          isRtl: isRtl,
          textSecondary: Colors.grey,
        ),
      ),
    );
  }

  group('AssistantResponseMeta — grounded state', () {
    testWidgets('shows the Grounded chip and renders citations',
        (tester) async {
      final response = AssistantResponse.fromJson({
        'answer': 'Tawaf is seven circuits.',
        'grounded': true,
        'confidence': 'high',
        'citations': [
          {
            'documentId': 'd1',
            'title': 'Sample Guide',
            'authority': 'Dev Fixture',
            'section': '',
            'url': ''
          },
        ],
        'requiresHumanGuide': false,
      }, 'en');

      await tester.pumpWidget(harness(response));

      expect(find.text('Grounded'), findsOneWidget);
      expect(find.text('Sign-in required'), findsNothing);
      expect(find.text('Offline'), findsNothing);
      expect(find.textContaining('Sample Guide'), findsOneWidget);
      expect(find.byType(AssistantMetaChip), findsOneWidget);
    });
  });

  group('AssistantResponseMeta — ungrounded state', () {
    testWidgets('shows the human-guide chip and zero citations',
        (tester) async {
      final response =
          AssistantResponse.unverified('en', notice: 'no_retrieval');

      await tester.pumpWidget(harness(response));

      expect(find.text('Consult an authorized guide'), findsOneWidget);
      expect(find.text('Grounded'), findsNothing);
      expect(find.textContaining(' — '), findsNothing);
    });

    testWidgets(
        'a response claiming grounded:true with empty citations never shows Grounded',
        (tester) async {
      // Server/Worker misbehavior simulation: raw JSON claims grounded:true
      // with no valid citations. AssistantResponse.fromJson must have
      // already forced grounded:false (defense in depth) — this asserts the
      // widget layer reflects that safe state, not the raw claim.
      final response = AssistantResponse.fromJson({
        'answer': 'Some answer',
        'grounded': true,
        'confidence': 'high',
        'citations': [],
        'requiresHumanGuide': false,
      }, 'en');

      expect(response.grounded, isFalse);
      expect(response.requiresHumanGuide, isTrue);

      await tester.pumpWidget(harness(response));

      expect(find.text('Grounded'), findsNothing);
      expect(find.text('Consult an authorized guide'), findsOneWidget);
    });
  });

  group('AssistantResponseMeta — offline state', () {
    testWidgets('shows the Offline chip and no citations', (tester) async {
      final response = AssistantResponse.offline(
          OfflineKnowledgeRepository.replyFor('where is the exit', 'en'));

      await tester.pumpWidget(harness(response));

      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Grounded'), findsNothing);
      expect(find.text('Sign-in required'), findsNothing);
    });

    testWidgets(
        'an offline ritual question is shown as unavailable, NOT as verified guidance',
        (tester) async {
      final response = AssistantResponse.offline(
          OfflineKnowledgeRepository.replyFor('tawaf', 'en'));

      await tester.pumpWidget(harness(response));

      // Must be clearly marked unavailable-without-an-approved-source, and
      // must never be presented as grounded/approved guidance.
      expect(find.text('Unavailable offline — no approved source'),
          findsOneWidget);
      expect(find.text('Approved offline guidance'), findsNothing);
      expect(find.text('Grounded'), findsNothing);
      expect(find.text('Consult an authorized guide'), findsOneWidget);
    });

    testWidgets(
        'the offline unavailable state renders its Arabic label under RTL',
        (tester) async {
      final response = AssistantResponse.offline(
          OfflineKnowledgeRepository.replyFor('الطواف', 'ar'));

      await tester.pumpWidget(harness(response, isRtl: true));

      expect(
          find.text('غير متاح دون اتصال — لا يوجد مصدر معتمد'), findsOneWidget);
    });
  });

  group('AssistantResponseMeta — sign-in-required state', () {
    testWidgets('shows a distinct Sign-in required chip, not a generic error',
        (tester) async {
      final response = AssistantResponse.signInRequired('en');

      await tester.pumpWidget(harness(response));

      expect(find.text('Sign-in required'), findsOneWidget);
      expect(find.text('Offline'), findsNothing);
      expect(find.text('Grounded'), findsNothing);
      // Sign-in-required is not itself an "escalate to a human guide" state.
      expect(find.text('Consult an authorized guide'), findsNothing);
    });

    testWidgets('renders the Arabic label under RTL', (tester) async {
      final response = AssistantResponse.signInRequired('ar');

      await tester.pumpWidget(harness(response, isRtl: true));

      expect(find.text('يلزم تسجيل الدخول'), findsOneWidget);
    });
  });

  group('AssistantMetaChip', () {
    testWidgets('renders its icon and label', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AssistantMetaChip(
              icon: Icons.verified_rounded,
              label: 'Grounded',
              color: Colors.green),
        ),
      ));

      expect(find.text('Grounded'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });
  });

  // ── Verified excerpts render as their own card ──────────────────────
  //
  // The server returns verified religious text byte-for-byte so it does not
  // pass through the model. That is only worth anything if the UI actually
  // shows it, separately from the generated explanation — otherwise the
  // pilgrim reads the model's paraphrase and the guarantee is invisible.

  const uthmani =
      'رَبَّنَآ ءَاتِنَا فِي ٱلدُّنۡيَا حَسَنَةٗ وَفِي ٱلۡأٓخِرَةِ حَسَنَةٗ وَقِنَا عَذَابَ ٱلنَّارِ';

  AssistantResponse withExcerpt({String answer = 'A short explanation.'}) {
    return AssistantResponse(
      answer: answer,
      language: 'en',
      grounded: true,
      confidence: 'high',
      citations: const [
        AssistantCitation(
          documentId: 'd1',
          title: 'Supplication',
          authority: 'Example Authority',
        ),
      ],
      requiresHumanGuide: false,
      verifiedExcerpts: const [
        VerifiedExcerpt(
          documentId: 'd1',
          title: 'Supplication',
          authority: 'Example Authority',
          text: uthmani,
          textLanguage: 'ar',
        ),
      ],
    );
  }

  testWidgets('a verified excerpt is shown as its own labelled card',
      (tester) async {
    await tester.pumpWidget(harness(withExcerpt()));

    expect(find.byType(VerifiedExcerptCard), findsOneWidget);
    expect(
        find.text('Verified text — as recorded in the source'), findsOneWidget);
    expect(find.text(uthmani), findsOneWidget);
  });

  testWidgets('the excerpt text is rendered byte-for-byte', (tester) async {
    await tester.pumpWidget(harness(withExcerpt()));

    final widget = tester.widget<SelectableText>(
      find.descendant(
        of: find.byType(VerifiedExcerptCard),
        matching: find.byType(SelectableText),
      ),
    );
    final shown = widget.data!;
    // Code-point equality, not "looks the same": a stripped diacritic or a
    // normalised Uthmanic glyph must fail here.
    expect(shown, uthmani);
    expect(shown.runes.toList(), uthmani.runes.toList());
    for (final cp in ['ۡ', 'ٗ', 'ٓ', 'ٱ']) {
      expect(shown.split(cp).length, uthmani.split(cp).length, reason: cp);
    }
  });

  testWidgets('the excerpt does not disappear when chips are present',
      (tester) async {
    await tester.pumpWidget(harness(withExcerpt(), isRtl: true));
    expect(find.byType(VerifiedExcerptCard), findsOneWidget);
    expect(find.text('نص موثّق — كما ورد في المصدر'), findsOneWidget);
  });

  testWidgets('the verified text is not duplicated inside the explanation',
      (tester) async {
    // The model echoing the āyah in `answer` must not produce two copies on
    // screen; the meta block renders the stored text exactly once.
    await tester.pumpWidget(harness(withExcerpt(answer: uthmani)));
    expect(find.byType(VerifiedExcerptCard), findsOneWidget);
    expect(find.text(uthmani), findsOneWidget);
  });

  testWidgets('one card per excerpt, no repeats', (tester) async {
    const r = AssistantResponse(
      answer: 'Explanation',
      language: 'ar',
      grounded: true,
      confidence: 'high',
      citations: [
        AssistantCitation(documentId: 'a', title: 'A', authority: 'Auth'),
        AssistantCitation(documentId: 'b', title: 'B', authority: 'Auth'),
      ],
      requiresHumanGuide: false,
      verifiedExcerpts: [
        VerifiedExcerpt(
            documentId: 'a',
            title: 'A',
            authority: 'Auth',
            text: 'نص أول',
            textLanguage: 'ar'),
        VerifiedExcerpt(
            documentId: 'b',
            title: 'B',
            authority: 'Auth',
            text: 'نص ثانٍ',
            textLanguage: 'ar'),
      ],
    );
    await tester.pumpWidget(harness(r, isRtl: true));

    expect(find.byType(VerifiedExcerptCard), findsNWidgets(2));
    expect(find.text('نص أول'), findsOneWidget);
    expect(find.text('نص ثانٍ'), findsOneWidget);
  });

  testWidgets('no excerpts means no card, and nothing else breaks',
      (tester) async {
    const r = AssistantResponse(
      answer: 'Explanation only',
      language: 'en',
      grounded: false,
      confidence: 'low',
      citations: [],
      requiresHumanGuide: true,
    );
    await tester.pumpWidget(harness(r));

    expect(find.byType(VerifiedExcerptCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('an older proxy that does not send the field', () {
    test('a missing verifiedExcerpts parses to an empty list, not an error',
        () {
      final r = AssistantResponse.fromJson(const {
        'answer': 'hello',
        'language': 'en',
        'grounded': false,
        'confidence': 'low',
        'citations': [],
        'requiresHumanGuide': true,
      }, 'en');
      expect(r.verifiedExcerpts, isEmpty);
      expect(r.answer, 'hello');
    });

    test('a malformed verifiedExcerpts is ignored rather than crashing', () {
      for (final bad in [
        'not a list',
        42,
        [
          {'documentId': '', 'text': 'x'},
          {'documentId': 'd', 'text': ''},
          {'documentId': 'd'},
          'string entry',
        ],
      ]) {
        final r = AssistantResponse.fromJson({
          'answer': 'hello',
          'language': 'en',
          'grounded': false,
          'confidence': 'low',
          'citations': const [],
          'requiresHumanGuide': true,
          'verifiedExcerpts': bad,
        }, 'en');
        expect(r.verifiedExcerpts, isEmpty, reason: '$bad');
      }
    });

    test('excerpt text is never trimmed on parse', () {
      final r = AssistantResponse.fromJson(const {
        'answer': 'x',
        'language': 'ar',
        'grounded': false,
        'confidence': 'low',
        'citations': [],
        'requiresHumanGuide': true,
        'verifiedExcerpts': [
          {
            'documentId': 'd',
            'title': 't',
            'authority': 'a',
            'text': '  نص فيه مسافات  ',
            'textLanguage': 'ar',
          }
        ],
      }, 'ar');
      expect(r.verifiedExcerpts.single.text, '  نص فيه مسافات  ');
    });
  });
}
