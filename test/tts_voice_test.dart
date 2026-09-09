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

    test('Gulf Arabic is preferred over Egyptian when Saudi is absent', () {
      // The app is read in the Haramain. Every one of these voices reads
      // Modern Standard Arabic — the region is an accent, not a dialect —
      // but the accent of the place is the right default, and Egyptian is
      // the most audibly marked of them.
      final picked = pickVoiceForLocale([
        {'name': 'Google Egyptian Arabic', 'locale': 'ar-EG'},
        {'name': 'ar-ae-x-default', 'locale': 'ar-AE'},
      ], 'ar-SA');
      expect(picked!['locale'], 'ar-ae');
    });

    test('a Google Egyptian voice does not outrank a plain Gulf one', () {
      // Region is ranked BEFORE the Google preference: a neural voice in the
      // wrong accent is still the wrong accent.
      final picked = pickVoiceForLocale([
        {'name': 'Google Arabic (Egypt)', 'locale': 'ar-EG'},
        {'name': 'ar-kw-x-basic', 'locale': 'ar-KW'},
      ], 'ar-SA');
      expect(picked!['locale'], 'ar-kw');
    });

    test('Saudi still wins outright when it is installed', () {
      final picked = pickVoiceForLocale([
        {'name': 'Google Egyptian Arabic', 'locale': 'ar-EG'},
        {'name': 'ar-sa-x-default', 'locale': 'ar-SA'},
      ], 'ar-SA');
      expect(picked!['locale'], 'ar-sa');
    });

    test('Egyptian is still used rather than reading Arabic in English', () {
      // Ordering, not exclusion. A marked Arabic accent beats an English
      // voice spelling out Arabic phonemes, which is the original bug.
      final picked = pickVoiceForLocale([
        {'name': 'Google US English', 'locale': 'en-US'},
        {'name': 'Google Egyptian Arabic', 'locale': 'ar-EG'},
      ], 'ar-SA');
      expect(picked!['locale'], 'ar-eg');
    });

    test('an unlisted Arabic region is not ranked below a deprioritised one',
        () {
      // Unknown is not a reason to rank below one we deliberately pushed down.
      final picked = pickVoiceForLocale([
        {'name': 'Google Egyptian Arabic', 'locale': 'ar-EG'},
        {'name': 'ar-xx-experimental', 'locale': 'ar-XX'},
      ], 'ar-SA');
      expect(picked!['locale'], 'ar-xx');
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

  group('speech rate', () {
    test('normal speed on Android and the web is 1.0', () {
      // The platforms disagree about the number: Android and web call 1.0
      // normal. The old hard-coded 0.42 was 42% of it — the reported drawl.
      expect(naturalSpeechRate(isWeb: true, platformName: 'android'), 1.0);
      expect(naturalSpeechRate(isWeb: false, platformName: 'android'), 1.0);
      expect(naturalSpeechRate(isWeb: false, platformName: 'windows'), 1.0);
      expect(naturalSpeechRate(isWeb: false, platformName: 'linux'), 1.0);
    });

    test('normal speed on Apple platforms is 0.5, not 1.0', () {
      // AVSpeechSynthesizer treats 1.0 as roughly double speed. One constant
      // cannot be right on both families, which is why this is a function.
      expect(naturalSpeechRate(isWeb: false, platformName: 'ios'), 0.5);
      expect(naturalSpeechRate(isWeb: false, platformName: 'macOS'), 0.5);
    });

    test('the web is web whatever platform reports underneath it', () {
      // Safari on an iPhone is still the Web Speech API: 1.0 is normal there.
      expect(naturalSpeechRate(isWeb: true, platformName: 'ios'), 1.0);
    });

    test('nothing is left at the old drawl', () {
      for (final p in [
        'android',
        'ios',
        'macos',
        'windows',
        'linux',
        'fuchsia'
      ]) {
        for (final web in [true, false]) {
          expect(naturalSpeechRate(isWeb: web, platformName: p),
              greaterThanOrEqualTo(0.5),
              reason:
                  '$p (web: $web) is slower than any platform calls normal');
        }
      }
    });

    test('an unknown platform gets the common default, not silence', () {
      expect(naturalSpeechRate(isWeb: false, platformName: 'plan9'), 1.0);
      expect(naturalSpeechRate(isWeb: false, platformName: ''), 1.0);
    });
  });
}
