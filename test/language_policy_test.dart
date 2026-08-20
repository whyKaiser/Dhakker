// Language-routing tests.
//
// The bug these exist to prevent: the assistant used to take its reply
// language from a picker that always started on Arabic, so an English app
// user was answered in Arabic; and the dev path asked the MODEL to detect
// the language, so the two paths could disagree. The rule is now one rule —
// the app's selected locale decides, message detection is only a fallback —
// and these tests pin each step of that precedence.

import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/data/offline_knowledge_repository.dart';
import 'package:dhakker/services/assistant_service.dart';
import 'package:dhakker/services/language_policy.dart';

void main() {
  group('precedence', () {
    test('Arabic app locale + English message → Arabic reply', () {
      // The headline case. The user typed in English, but their app is set to
      // Arabic; the setting wins and the message is not consulted.
      final d = LanguagePolicy.resolve(
        userLocale: 'ar-SA',
        latestUserMessage: 'What do I say at the Black Stone?',
      );
      expect(d.responseLanguage, 'ar');
      expect(d.userLocale, 'ar-SA');
      expect(d.source, LanguageSource.appLocale);
    });

    test('English app locale + Arabic message → English reply', () {
      final d = LanguagePolicy.resolve(
        userLocale: 'en-US',
        latestUserMessage: 'ماذا أقول عند الحجر الأسود؟',
      );
      expect(d.responseLanguage, 'en');
      expect(d.source, LanguageSource.appLocale);
    });

    test('an explicit responseLanguage outranks the app locale', () {
      final d = LanguagePolicy.resolve(
        responseLanguage: 'fr',
        userLocale: 'ar-SA',
        latestUserMessage: 'ماذا أقول؟',
      );
      expect(d.responseLanguage, 'fr');
      expect(d.source, LanguageSource.explicitSetting);
    });

    test('missing locale falls back to the latest message language', () {
      final ar = LanguagePolicy.resolve(
        latestUserMessage: 'كيف أطوف حول الكعبة؟',
      );
      expect(ar.responseLanguage, 'ar');
      expect(ar.source, LanguageSource.messageDetection);

      final en =
          LanguagePolicy.resolve(latestUserMessage: 'How do I do tawaf?');
      expect(en.responseLanguage, 'en');
      expect(en.source, LanguageSource.messageDetection);
    });

    test('nothing at all → the documented default, not Arabic', () {
      final d = LanguagePolicy.resolve();
      expect(d.responseLanguage, 'en');
      expect(d.source, LanguageSource.defaultLanguage);
    });

    test('an unsupported locale is ignored, not passed through', () {
      final d = LanguagePolicy.resolve(
        userLocale: 'de-DE',
        latestUserMessage: 'Wie mache ich Tawaf?',
      );
      expect(LanguagePolicy.supported, isNot(contains('de')));
      expect(d.responseLanguage, 'en');
    });
  });

  group('locale handling', () {
    test('Arabic canonicalises to ar-SA', () {
      expect(LanguagePolicy.localeFor('ar'), 'ar-SA');
      expect(
          LanguagePolicy.resolve(responseLanguage: 'ar').userLocale, 'ar-SA');
    });

    test('underscore and dash locale forms both parse', () {
      for (final locale in ['ar_SA', 'ar-SA', 'AR', 'ar']) {
        expect(LanguagePolicy.languageFromLocale(locale), 'ar', reason: locale);
      }
    });

    test('every supported language has a canonical locale', () {
      for (final lang in LanguagePolicy.supported) {
        expect(LanguagePolicy.canonicalLocales[lang], isNotNull, reason: lang);
      }
    });
  });

  group('message detection is narrow on purpose', () {
    test('Arabic script is recognised, including Uthmanic text', () {
      expect(LanguagePolicy.detectFromMessage('رَبَّنَآ ءَاتِنَا'), 'ar');
    });

    test('a language it cannot tell apart is not guessed at', () {
      // Turkish/French/Indonesian all use Latin script. Rather than guess
      // between them, detection says English and lets the app locale — which
      // actually knows — decide when it is available.
      expect(LanguagePolicy.detectFromMessage('Nasıl tavaf yaparım?'), 'en');
      expect(LanguagePolicy.detectFromMessage('Comment faire le tawaf?'), 'en');
    });

    test('an empty or symbol-only message yields no detection', () {
      expect(LanguagePolicy.detectFromMessage(''), isNull);
      expect(LanguagePolicy.detectFromMessage('؟؟؟ 123 ...'), isNull);
    });

    test('mixed script prefers Arabic when Arabic dominates', () {
      expect(LanguagePolicy.detectFromMessage('ماذا أقول عند الحجر (tawaf)?'),
          'ar');
    });
  });

  group('every path uses the selected language', () {
    test('the offline reply is in the selected language', () {
      for (final lang in LanguagePolicy.supported) {
        final entry = OfflineKnowledgeRepository.replyFor(
          'ماذا أقول عند الطواف؟',
          lang,
        );
        expect(entry.language, lang, reason: lang);
        expect(entry.text.trim(), isNotEmpty, reason: lang);
      }
    });

    test('an unsupported language degrades to English, not to Arabic', () {
      final entry = OfflineKnowledgeRepository.replyFor('tawaf question', 'de');
      expect(entry.language, 'en');
    });

    test('the unverified/sign-in replies follow the selected language', () {
      for (final lang in LanguagePolicy.supported) {
        expect(AssistantResponse.unverified(lang).language, lang, reason: lang);
        expect(AssistantResponse.signInRequired(lang).language, lang,
            reason: lang);
      }
    });

    test('offline and no-source replies never claim to be grounded', () {
      final r = AssistantResponse.unverified('ar');
      expect(r.grounded, isFalse);
      expect(r.citations, isEmpty);
    });
  });
}
