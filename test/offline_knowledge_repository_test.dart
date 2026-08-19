import 'package:flutter_test/flutter_test.dart';
import 'package:dhakker/data/offline_knowledge_repository.dart';

/// Religious-safety tests for the offline knowledge layer.
///
/// The central guarantee: this repository must never assert a religious or
/// ritual fact. An earlier revision shipped unattributed claims about Tawaf,
/// Sa'i, Ihram, Jamarat and Arafat (including a hadith quotation) labelled as
/// "reviewed"; these tests exist so that cannot silently return.
void main() {
  const languages = ['ar', 'en', 'ur', 'tr', 'id', 'fr'];

  group('no unapproved religious content', () {
    test('exposes no approved offline guidance until real sources are ingested',
        () {
      expect(OfflineKnowledgeRepository.approvedOfflineGuidance, isEmpty);
      expect(OfflineKnowledgeRepository.hasApprovedOfflineGuidance, isFalse);
    });

    test('never returns an entry marked approved/verified', () {
      for (final lang in languages) {
        for (final q in [
          'tawaf',
          'الطواف',
          'how many circuits',
          'where is the bus',
          '',
        ]) {
          final entry = OfflineKnowledgeRepository.replyFor(q, lang);
          expect(entry.isApproved, isFalse,
              reason: 'no offline entry may claim approval ($lang / "$q")');
          expect(entry.source, isNull,
              reason: 'no offline entry may carry citation metadata yet');
          expect(entry.status, isNot(OfflineContentStatus.approvedGuidance));
        }
      }
    });

    test(
        'offline text asserts no ritual facts — no lap counts, no rulings, no quotations',
        () {
      // Substrings that would indicate the repository is making a religious
      // claim of its own rather than referring the pilgrim onward.
      final forbidden = <RegExp>[
        RegExp(r'seven circuits', caseSensitive: false),
        RegExp(r'seven pebbles', caseSensitive: false),
        RegExp(r'counter-clockwise', caseSensitive: false),
        RegExp(r'Black Stone', caseSensitive: false),
        RegExp(r'Hajj is Arafah', caseSensitive: false),
        RegExp(r'greatest pillar', caseSensitive: false),
        RegExp(r'سبعة أشواط'),
        RegExp(r'سبع حصيات'),
        RegExp(r'الحجر الأسود'),
        RegExp(r'الحج عرفة'),
        RegExp(r'أعظم أركان'),
      ];
      for (final lang in languages) {
        for (final q in [
          'tawaf',
          'sai',
          'ihram',
          'jamarat',
          'arafat',
          'الطواف',
          'السعي',
          'ما حكم',
          'general question',
        ]) {
          final text = OfflineKnowledgeRepository.replyFor(q, lang).text;
          for (final pattern in forbidden) {
            expect(pattern.hasMatch(text), isFalse,
                reason:
                    'offline text ($lang / "$q") must not assert: ${pattern.pattern}');
          }
        }
      }
    });
  });

  group('ritual questions are referred onward, in every supported language',
      () {
    test('a ritual question yields the no-approved-source referral', () {
      for (final lang in languages) {
        final entry = OfflineKnowledgeRepository.replyFor('tawaf', lang);
        expect(entry.status, OfflineContentStatus.noApprovedSourceOffline,
            reason: 'ritual question in $lang must be referred onward');
        expect(entry.language, lang);
        expect(entry.text.trim(), isNotEmpty);
      }
    });

    test('Arabic ritual keywords are detected, not just Latin ones', () {
      for (final q in ['الطواف', 'السعي', 'الإحرام', 'ما حكم ذلك', 'عرفة']) {
        expect(OfflineKnowledgeRepository.isRitualQuestion(q), isTrue,
            reason: '"$q" must be treated as a ritual question');
      }
    });

    test('non-ritual questions yield an operational notice', () {
      for (final lang in languages) {
        final entry =
            OfflineKnowledgeRepository.replyFor('where do I find my bus', lang);
        expect(entry.status, OfflineContentStatus.operationalNotice);
        expect(entry.text.trim(), isNotEmpty);
      }
    });
  });

  group('localization', () {
    test(
        'every supported language has its own distinct text (no silent English fallback)',
        () {
      for (final status in ['tawaf', 'where is my bus']) {
        final texts = languages
            .map((l) => OfflineKnowledgeRepository.replyFor(status, l).text);
        expect(texts.toSet().length, languages.length,
            reason:
                'each language must have its own translation for "$status"');
      }
    });

    test('Arabic text is actually in Arabic script', () {
      final arabic = RegExp(r'[؀-ۿ]');
      for (final q in ['tawaf', 'where is my bus']) {
        expect(
            arabic.hasMatch(OfflineKnowledgeRepository.replyFor(q, 'ar').text),
            isTrue);
      }
    });

    test('an unsupported language code falls back to English safely', () {
      final entry = OfflineKnowledgeRepository.replyFor('tawaf', 'zz');
      expect(entry.language, 'en');
      expect(entry.text.trim(), isNotEmpty);
    });
  });
}
