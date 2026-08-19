import 'package:flutter_test/flutter_test.dart';
import 'package:dhakker/services/assistant_service.dart';

void main() {
  group('PilgrimContext', () {
    test('toJson returns null (sends nothing) when consent is false', () {
      const ctx = PilgrimContext(consent: false, ritual: 'tawaf', zone: 'haram');
      expect(ctx.toJson(), isNull);
    });

    test('toJson returns null for the default "none" instance', () {
      expect(PilgrimContext.none.toJson(), isNull);
    });

    test('toJson includes only populated fields plus consent when consented', () {
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

    test('toJson never carries a raw lat/lng key regardless of construction', () {
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
          {'documentId': 'd1', 'title': 'T', 'authority': 'A', 'section': 'S', 'url': 'https://x'},
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

    test('drops citations missing required fields (no invented citations survive parsing)', () {
      final resp = AssistantResponse.fromJson({
        'answer': 'Some answer',
        'grounded': true,
        'citations': [
          {'documentId': 'd1'}, // missing title/authority
          {'title': 'no id'}, // missing documentId/authority
        ],
      }, 'en');

      expect(resp.citations, isEmpty);
    });

    test('empty citations + grounded=false yields a client object with zero citations', () {
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

    test('falls back to a safe localized answer when "answer" is missing/empty', () {
      final resp = AssistantResponse.fromJson(const {}, 'ar');
      expect(resp.answer, isNotEmpty);
      expect(resp.answer, isNot('null'));
    });

    test('unverified() factory always sets requiresHumanGuide and no citations', () {
      final resp = AssistantResponse.unverified('en', notice: 'assistant_unavailable');
      expect(resp.requiresHumanGuide, isTrue);
      expect(resp.grounded, isFalse);
      expect(resp.citations, isEmpty);
      expect(resp.safetyNotice, 'assistant_unavailable');
    });

    test('offline() factory marks isOffline true and never grounded', () {
      final resp = AssistantResponse.offline('Tawaf is seven circuits (offline fact).', 'en');
      expect(resp.isOffline, isTrue);
      expect(resp.grounded, isFalse);
      expect(resp.citations, isEmpty);
    });
  });

  group('AssistantService', () {
    test('isConfigured is false with no proxy URL / API key (dev environment default)', () {
      final service = AssistantService();
      expect(service.isConfigured, isFalse);
    });

    test('ask() returns a safe unverified response (never throws) when not configured', () async {
      final service = AssistantService();
      final resp = await service.ask('What is Tawaf?', language: 'en');
      expect(resp.requiresHumanGuide, isTrue);
      expect(resp.citations, isEmpty);
      expect(resp.grounded, isFalse);
    });

    test('ask() with an empty message returns a safe response without mutating history', () async {
      final service = AssistantService();
      await service.ask('   ', language: 'en');
      expect(service.history, isEmpty);
    });

    test('clearHistory empties the conversation log', () async {
      final service = AssistantService();
      await service.ask('hello', language: 'en'); // not configured -> no history added
      service.clearHistory();
      expect(service.history, isEmpty);
    });
  });
}
