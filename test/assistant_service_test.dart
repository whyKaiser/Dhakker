import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dhakker/services/assistant_service.dart';

void main() {
  group('PilgrimContext', () {
    test('toJson returns null (sends nothing) when consent is false', () {
      const ctx =
          PilgrimContext(consent: false, ritual: 'tawaf', zone: 'haram');
      expect(ctx.toJson(), isNull);
    });

    test('toJson returns null for the default "none" instance', () {
      expect(PilgrimContext.none.toJson(), isNull);
    });

    test('toJson includes only populated fields plus consent when consented',
        () {
      const ctx = PilgrimContext(
        consent: true,
        ritual: 'tawaf',
        tawafLapsCompleted: 3,
        zone: 'Al-Haram',
      );
      final json = ctx.toJson();
      expect(json, isNotNull);
      expect(json!['consent'], true);
      expect(json['ritual'], 'tawaf');
      expect(json['tawafLapsCompleted'], 3);
      expect(json['zone'], 'Al-Haram');
      // Fields never set must not appear at all.
      expect(json.containsKey('saiLapsCompleted'), isFalse);
      expect(json.containsKey('mobility'), isFalse);
    });

    test('toJson never carries a raw lat/lng key regardless of construction',
        () {
      const ctx = PilgrimContext(consent: true, zone: 'Mina');
      final json = ctx.toJson()!;
      expect(json.containsKey('lat'), isFalse);
      expect(json.containsKey('lng'), isFalse);
      expect(json.containsKey('latitude'), isFalse);
      expect(json.containsKey('longitude'), isFalse);
    });
  });

  group('AssistantCitation', () {
    test('isValid requires documentId, title, and authority', () {
      final valid = AssistantCitation.fromJson({
        'documentId': 'd1',
        'title': 'T',
        'authority': 'A',
      });
      expect(valid.isValid, isTrue);

      final missingAuthority = AssistantCitation.fromJson({
        'documentId': 'd1',
        'title': 'T',
      });
      expect(missingAuthority.isValid, isFalse);

      final empty = AssistantCitation.fromJson(const {});
      expect(empty.isValid, isFalse);
    });
  });

  group('AssistantResponse.fromJson', () {
    test('parses a grounded response with valid citations', () {
      final resp = AssistantResponse.fromJson({
        'answer': 'Tawaf is seven circuits.',
        'language': 'en',
        'grounded': true,
        'confidence': 'high',
        'citations': [
          {
            'documentId': 'd1',
            'title': 'T',
            'authority': 'A',
            'section': 'S',
            'url': 'https://x'
          },
        ],
        'recommendedAction': null,
        'requiresHumanGuide': false,
        'safetyNotice': null,
      }, 'en');

      expect(resp.grounded, isTrue);
      expect(resp.confidence, 'high');
      expect(resp.citations.length, 1);
      expect(resp.requiresHumanGuide, isFalse);
      expect(resp.isOffline, isFalse);
    });

    test(
        'drops citations missing required fields (no invented citations survive parsing)',
        () {
      final resp = AssistantResponse.fromJson({
        'answer': 'Some answer',
        'grounded': true,
        'citations': [
          {'documentId': 'd1'}, // missing title/authority
          {'title': 'no id'}, // missing documentId/authority
        ],
      }, 'en');

      expect(resp.citations, isEmpty);
      // Core safety invariant: grounded can NEVER be true once the
      // validated citations list ends up empty, regardless of the raw
      // JSON's claim.
      expect(resp.grounded, isFalse);
      expect(resp.confidence, 'low');
      expect(resp.requiresHumanGuide, isTrue);
    });

    test(
        'grounded:true with an empty citations array is forced to grounded:false/low/requiresHumanGuide:true',
        () {
      final resp = AssistantResponse.fromJson({
        'answer': 'Some answer',
        'grounded': true,
        'confidence': 'high',
        'citations': <Map<String, dynamic>>[],
        'requiresHumanGuide': false,
      }, 'en');

      expect(resp.grounded, isFalse);
      expect(resp.confidence, 'low');
      expect(resp.requiresHumanGuide, isTrue);
    });

    test(
        'empty citations + grounded=false yields a client object with zero citations',
        () {
      final resp = AssistantResponse.fromJson({
        'answer': 'I cannot verify this.',
        'grounded': false,
        'confidence': 'low',
        'citations': [],
        'requiresHumanGuide': true,
      }, 'ar');

      expect(resp.grounded, isFalse);
      expect(resp.citations, isEmpty);
      expect(resp.requiresHumanGuide, isTrue);
    });

    test('falls back to a safe localized answer when "answer" is missing/empty',
        () {
      final resp = AssistantResponse.fromJson(const {}, 'ar');
      expect(resp.answer, isNotEmpty);
      expect(resp.answer, isNot('null'));
    });

    test('unverified() factory always sets requiresHumanGuide and no citations',
        () {
      final resp =
          AssistantResponse.unverified('en', notice: 'assistant_unavailable');
      expect(resp.requiresHumanGuide, isTrue);
      expect(resp.grounded, isFalse);
      expect(resp.citations, isEmpty);
      expect(resp.safetyNotice, 'assistant_unavailable');
    });

    test('offline() factory marks isOffline true and never grounded', () {
      final resp = AssistantResponse.offline(
          'Tawaf is seven circuits (offline fact).', 'en');
      expect(resp.isOffline, isTrue);
      expect(resp.grounded, isFalse);
      expect(resp.citations, isEmpty);
    });
  });

  group('AssistantService', () {
    test(
        'isConfigured is false with no proxy URL / API key (dev environment default)',
        () {
      final service = AssistantService();
      expect(service.isConfigured, isFalse);
    });

    test(
        'ask() returns a safe unverified response (never throws) when not configured',
        () async {
      final service = AssistantService();
      final resp = await service.ask('What is Tawaf?', language: 'en');
      expect(resp.requiresHumanGuide, isTrue);
      expect(resp.citations, isEmpty);
      expect(resp.grounded, isFalse);
    });

    test(
        'ask() with an empty message returns a safe response without mutating history',
        () async {
      final service = AssistantService();
      await service.ask('   ', language: 'en');
      expect(service.history, isEmpty);
    });

    test('clearHistory empties the conversation log', () async {
      final service = AssistantService();
      await service.ask('hello',
          language: 'en'); // not configured -> no history added
      service.clearHistory();
      expect(service.history, isEmpty);
    });
  });

  // ── Firebase auth wiring (proxy mode) ──────────────────────────────────
  //
  // These force proxy mode via the test-only `proxyUrl` constructor param
  // (the real app instead relies on the compile-time `ASSISTANT_PROXY_URL`
  // define) and fake the token provider / HTTP transport, since there is no
  // live Firebase project available in this test environment.
  group('AssistantService — auth (proxy mode)', () {
    test(
        'missing token (no authenticated user) returns signInRequired without any network call',
        () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('{}', 200);
      });
      final service = AssistantService(
          proxyUrl: 'https://proxy.example/assistant', client: client)
        ..idTokenProvider = () async => null;

      final resp = await service.ask('What is Tawaf?', language: 'en');

      expect(resp.signInRequired, isTrue);
      expect(resp.grounded, isFalse);
      expect(callCount, 0); // never even attempted the request without a token
      expect(service.history, isEmpty); // user turn rolled back
    });

    test(
        'valid token attaches an Authorization header and returns the structured response',
        () async {
      String? seenAuthHeader;
      final client = MockClient((request) async {
        seenAuthHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'answer': 'Tawaf is seven circuits.',
            'grounded': true,
            'confidence': 'high',
            'citations': [
              {
                'documentId': 'd1',
                'title': 'T',
                'authority': 'A',
                'section': '',
                'url': ''
              }
            ],
            'requiresHumanGuide': false,
          }),
          200,
        );
      });
      final service = AssistantService(
          proxyUrl: 'https://proxy.example/assistant', client: client)
        ..idTokenProvider = () async => 'valid-fresh-token';

      final resp = await service.ask('What is Tawaf?', language: 'en');

      expect(seenAuthHeader, 'Bearer valid-fresh-token');
      expect(resp.grounded, isTrue);
      expect(resp.signInRequired, isFalse);
    });

    test(
        'expired/rejected token (server 401) returns signInRequired, not a generic error',
        () async {
      final client = MockClient(
          (request) async => http.Response('{"error":"unauthenticated"}', 401));
      final service = AssistantService(
          proxyUrl: 'https://proxy.example/assistant', client: client)
        ..idTokenProvider = () async => 'expired-token';

      final resp = await service.ask('What is Tawaf?', language: 'en');

      expect(resp.signInRequired, isTrue);
      expect(resp.grounded, isFalse);
    });

    test(
        'token refresh: idTokenProvider is invoked fresh on every request, never cached across calls',
        () async {
      var tokenCallCount = 0;
      final seenHeaders = <String?>[];
      final client = MockClient((request) async {
        seenHeaders.add(request.headers['Authorization']);
        return http.Response(
            jsonEncode({'answer': 'ok', 'grounded': false, 'citations': []}),
            200);
      });
      final service = AssistantService(
          proxyUrl: 'https://proxy.example/assistant', client: client)
        ..idTokenProvider = () async {
          tokenCallCount++;
          return 'token-$tokenCallCount'; // a new token string each call, simulating force-refresh
        };

      await service.ask('first question', language: 'en');
      await service.ask('second question', language: 'en');

      expect(tokenCallCount, 2); // fetched fresh each time, never reused/cached
      expect(seenHeaders, ['Bearer token-1', 'Bearer token-2']);
    });

    test(
        'no context key is serialized in the request body when consent is false',
        () async {
      Map<String, dynamic>? sentBody;
      final client = MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
            jsonEncode({'answer': 'ok', 'grounded': false, 'citations': []}),
            200);
      });
      final service = AssistantService(
          proxyUrl: 'https://proxy.example/assistant', client: client)
        ..idTokenProvider = () async => 'tok';

      await service.ask(
        'What is Tawaf?',
        language: 'en',
        context: const PilgrimContext(
            consent: false, ritual: 'tawaf', zone: 'Al-Haram'),
      );

      expect(sentBody, isNotNull);
      expect(sentBody!.containsKey('context'), isFalse);
    });
  });
}
