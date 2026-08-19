import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dhakker/services/assistant_service.dart';

/// A minimal standalone widget mirroring the citation/offline/human-guide
/// badges rendered in `assistant_screen.dart`'s `_responseMeta`, so this can
/// be verified without needing to boot the full app (Firebase, Bloc
/// providers, etc.) that the real screen depends on.
class _ResponseMetaBadges extends StatelessWidget {
  final AssistantResponse response;
  const _ResponseMetaBadges(this.response);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (response.isOffline) const Text('Offline', key: Key('badge-offline')),
        if (!response.isOffline && response.grounded)
          const Text('Grounded', key: Key('badge-grounded')),
        if (response.requiresHumanGuide)
          const Text('Consult an authorized guide', key: Key('badge-human-guide')),
        for (final c in response.citations)
          Text('${c.title} — ${c.authority}', key: const Key('citation')),
      ],
    );
  }
}

void main() {
  testWidgets('shows the Grounded badge and citations for a grounded response', (tester) async {
    final response = AssistantResponse.fromJson({
      'answer': 'Tawaf is seven circuits.',
      'grounded': true,
      'confidence': 'high',
      'citations': [
        {'documentId': 'd1', 'title': 'Sample Guide', 'authority': 'Dev Fixture', 'section': '', 'url': ''},
      ],
      'requiresHumanGuide': false,
    }, 'en');

    await tester.pumpWidget(MaterialApp(home: _ResponseMetaBadges(response)));

    expect(find.byKey(const Key('badge-grounded')), findsOneWidget);
    expect(find.byKey(const Key('badge-offline')), findsNothing);
    expect(find.byKey(const Key('badge-human-guide')), findsNothing);
    expect(find.text('Sample Guide — Dev Fixture'), findsOneWidget);
  });

  testWidgets('shows the Offline badge and no citations for an offline response', (tester) async {
    final response = AssistantResponse.offline('Basic ritual facts only.', 'en');

    await tester.pumpWidget(MaterialApp(home: _ResponseMetaBadges(response)));

    expect(find.byKey(const Key('badge-offline')), findsOneWidget);
    expect(find.byKey(const Key('badge-grounded')), findsNothing);
    expect(find.byKey(const Key('citation')), findsNothing);
  });

  testWidgets('shows the human-guide badge with zero citations for an ungrounded response', (tester) async {
    final response = AssistantResponse.unverified('en', notice: 'no_retrieval');

    await tester.pumpWidget(MaterialApp(home: _ResponseMetaBadges(response)));

    expect(find.byKey(const Key('badge-human-guide')), findsOneWidget);
    expect(find.byKey(const Key('citation')), findsNothing);
  });
}
