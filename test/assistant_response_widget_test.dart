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
}
