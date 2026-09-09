// The assistant speaks six languages. It used to speak all of them with one
// Arabic voice, because the screen pinned a voice once at open time and a
// pinned voice outranks a later setLanguage. English came out of an Arabic
// larynx — "broken", as the report put it.
//
// These pin the decision itself. The plugin needs a real platform channel, so
// a bug here is silent in a widget test and unmistakable to a pilgrim.

import 'package:dhakker/Screens/Assistant/tts_voice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('locale for a reply language', () {
    test('every language the assistant supports has its own locale', () {
      final locales = {
        'ar': ttsLocaleForLanguageCode('ar'),
        'en': ttsLocaleForLanguageCode('en'),
        'ur': ttsLocaleForLanguageCode('ur'),
        'tr': ttsLocaleForLanguageCode('tr'),
        'id': ttsLocaleForLanguageCode('id'),
        'fr': ttsLocaleForLanguageCode('fr'),
      };
      expect(locales, {
        'ar': 'ar-SA',
        'en': 'en-US',
        'ur': 'ur-PK',
        'tr': 'tr-TR',
        'id': 'id-ID',
        'fr': 'fr-FR',
      });
      // Six languages, six distinct locales: any collision means two of them
      // share a voice, which is the bug.
      expect(locales.values.toSet().length, 6);
    });

    test('Urdu is not treated as Arabic', () {
      // Both are Arabic-script, which is exactly why guessing from the text
      // got this wrong.
      expect(ttsLocaleForLanguageCode('ur'),
          isNot(ttsLocaleForLanguageCode('ar')));
    });

    test('case and whitespace do not change the answer', () {
      expect(ttsLocaleForLanguageCode(' AR '), 'ar-SA');
      expect(ttsLocaleForLanguageCode('Tr'), 'tr-TR');
    });

    test('an unknown or missing code falls back to English, not the device',
        () {
      for (final code in [null, '', '   ', 'zz', 'klingon']) {
        expect(ttsLocaleForLanguageCode(code), 'en-US');
      }
    });
  });

  group('picking an installed voice', () {
    const voices = [
      {'name': 'ar-sa-x-default', 'locale': 'ar-SA'},
      {'name': 'Google العربية', 'locale': 'ar-SA'},
      {'name': 'ar-eg-x-regional', 'locale': 'ar-EG'},
      {'name': 'Google US English', 'locale': 'en-US'},
      {'name': 'tr-tr-x-default', 'locale': 'tr-TR'},
    ];

    test('an exact locale match wins, and Google wins within it', () {
      expect(pickVoiceForLocale(voices, 'ar-SA')!['name'], 'Google العربية');
      expect(pickVoiceForLocale(voices, 'en-US')!['name'], 'Google US English');
    });

    test('a regional variant is used when the exact locale is absent', () {
      // ar-EG reading Arabic is an accent. en-US reading Arabic is the bug.
      final picked = pickVoiceForLocale([
        {'name': 'ar-eg-x-regional', 'locale': 'ar-EG'},
        {'name': 'Google US English', 'locale': 'en-US'},
      ], 'ar-SA');
      expect(picked!['locale'], 'ar-eg');
    });

    test('no voice for the language returns null rather than a wrong one', () {
      // THE regression that started this. Forcing a mismatched voice is worse
      // than letting setLanguage alone decide.
      expect(pickVoiceForLocale(voices, 'ur-PK'), isNull);
      expect(pickVoiceForLocale(voices, 'id-ID'), isNull);
      expect(pickVoiceForLocale(voices, 'fr-FR'), isNull);
    });

    test('a language never borrows another language\'s voice', () {
      for (final locale in [
        'ur-PK',
        'id-ID',
        'fr-FR',
        'tr-TR',
        'en-US',
        'ar-SA'
      ]) {
        final picked = pickVoiceForLocale(voices, locale);
        if (picked == null) continue;
        expect(
          picked['locale']!.split('-').first,
          locale.toLowerCase().split('-').first,
          reason: '$locale was given a voice from another language',
        );
      }
    });

    test('underscores and casing in a device locale still match', () {
      final picked = pickVoiceForLocale(
        [
          {'name': 'Turkish', 'language': 'TR_tr'},
        ],
        'tr-TR',
      );
      expect(picked!['name'], 'Turkish');
    });

    test('malformed entries are skipped, not crashed on', () {
      final picked = pickVoiceForLocale(
        [
          null,
          'a string',
          42,
          {'locale': 'ar-SA'}, // no name — cannot be addressed by setVoice
          {'name': ''}, // empty name
          {'name': 'usable', 'locale': 'ar-SA'},
        ],
        'ar-SA',
      );
      expect(picked!['name'], 'usable');
    });

    test('an empty or missing voice list returns null', () {
      expect(pickVoiceForLocale(null, 'ar-SA'), isNull);
      expect(pickVoiceForLocale([], 'ar-SA'), isNull);
      expect(
          pickVoiceForLocale([
            {'name': 'x'},
          ], 'ar-SA'),
          isNull);
    });
  });
}
