// When hosted audio fails, the pilgrim must still hear the text.
//
// The service used to treat a failed file the same as a finished one: reset
// the button and return. That produced silence — no sound, no message, no
// spoken text — for someone standing in the tawaf who had just pressed play.
// It was strictly worse than having no file at all, because a missing file
// falls through to TTS from the start.
//
// These tests drive the real play() logic through a subclass that replaces
// only the five plugin calls, so no device, network or method channel is
// involved and every branch below is the shipping code path.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Home/models/supplication_model.dart';
import 'package:dhakker/Screens/Piligram/Home/services/dua_playback_service.dart';

/// Records what the service asked the platform to do, and can be told to
/// fail the file the way a dead URL or a flat network would.
class _FakePlayback extends DuaPlaybackService {
  _FakePlayback({this.fileThrows = false});

  final bool fileThrows;

  final List<String> playedFiles = <String>[];
  final List<String> spoken = <String>[];
  final List<String> languages = <String>[];
  final List<Map<String, String>> voices = <Map<String, String>>[];
  int stopCalls = 0;

  /// Every platform call in order, so a test can assert that the file was
  /// tried BEFORE the speech, and that neither happened twice.
  final List<String> calls = <String>[];

  @override
  Future<void> playFile(String url) async {
    calls.add('playFile:$url');
    playedFiles.add(url);
    if (fileThrows) {
      throw Exception('simulated playback failure');
    }
  }

  @override
  Future<void> speakText(String text) async {
    calls.add('speak:$text');
    spoken.add(text);
  }

  @override
  Future<void> setTtsLanguage(String language) async {
    calls.add('lang:$language');
    languages.add(language);
  }

  @override
  Future<void> setTtsVoice(Map<String, String> voice) async {
    calls.add('voice');
    voices.add(voice);
  }

  @override
  Future<void> stopEngines() async {
    calls.add('stop');
    stopCalls++;
  }
}

const String kArabic = 'رَبَّنَآ ءَاتِنَا فِي ٱلدُّنۡيَا حَسَنَةٗ';

SupplicationModel _dua({
  required String audioMode,
  String audioUrl = '',
  String ar = kArabic,
  String en = 'Our Lord, give us good in this world',
  String contentKind = 'general_dua',
}) {
  return SupplicationModel.fromJson({
    'duaId': 'test-record',
    'title': {'ar': 'دعاء', 'en': 'Dua'},
    'text': {'ar': ar, 'en': en},
    'audioMode': audioMode,
    'audioUrl': audioUrl,
    'contentKind': contentKind,
    'isActive': true,
    'verificationStatus': 'unverified',
  });
}

void main() {
  group('a working file is played, and nothing is spoken', () {
    test('the file is played and TTS is never reached', () async {
      final s = _FakePlayback();
      await s.play(
          dua: _dua(audioMode: 'file', audioUrl: 'https://x/a.mp3'),
          langCode: 'ar');

      expect(s.playedFiles, ['https://x/a.mp3']);
      expect(s.spoken, isEmpty,
          reason: 'a file that plays must not be doubled by speech');
      expect(s.languages, isEmpty);
      expect(s.voices, isEmpty);
    });

    test('the url is trimmed before it is played', () async {
      final s = _FakePlayback();
      await s.play(
          dua: _dua(audioMode: 'file', audioUrl: '  https://x/a.mp3  '),
          langCode: 'ar');
      expect(s.playedFiles, ['https://x/a.mp3']);
    });

    test('isPlaying stays true while the file plays', () async {
      final s = _FakePlayback();
      await s.play(
          dua: _dua(audioMode: 'file', audioUrl: 'https://x/a.mp3'),
          langCode: 'ar');
      // The player owns the end of playback: onPlayerComplete clears it.
      expect(s.isPlaying, isTrue);
    });
  });

  group('a failing file falls through to TTS instead of going silent', () {
    test('the text is spoken after the file throws', () async {
      final s = _FakePlayback(fileThrows: true);
      await s.play(
          dua: _dua(audioMode: 'file', audioUrl: 'https://x/gone.mp3'),
          langCode: 'ar');

      expect(s.playedFiles, ['https://x/gone.mp3'],
          reason: 'the file must still be attempted first');
      expect(s.spoken, [kArabic],
          reason: 'THE regression: this list used to be empty and the '
              'pilgrim heard nothing at all');
    });

    test('it speaks the right language, not the other one', () async {
      final ar = _FakePlayback(fileThrows: true);
      await ar.play(
          dua: _dua(audioMode: 'file', audioUrl: 'https://x/a.mp3'),
          langCode: 'ar');
      expect(ar.spoken.single, kArabic);
      expect(ar.languages, ['ar-SA']);

      final en = _FakePlayback(fileThrows: true);
      await en.play(
          dua: _dua(audioMode: 'file', audioUrl: 'https://x/a.mp3'),
          langCode: 'en');
      expect(en.spoken.single, 'Our Lord, give us good in this world');
      expect(en.languages, ['en-US']);
    });

    test('the file is tried once and the text spoken once — no loop', () async {
      final s = _FakePlayback(fileThrows: true);
      await s.play(
          dua: _dua(audioMode: 'file', audioUrl: 'https://x/a.mp3'),
          langCode: 'ar');

      // The fallback falls THROUGH the function; it must never re-enter
      // play(), which would re-run stop() and could spin forever while the
      // file keeps failing.
      expect(s.calls,
          ['stop', 'playFile:https://x/a.mp3', 'lang:ar-SA', 'speak:$kArabic']);
      expect(s.playedFiles, hasLength(1));
      expect(s.spoken, hasLength(1));
      expect(s.stopCalls, 1, reason: 'a re-entry would stop twice');
    });

    test('a failing file with no text at all still ends cleanly', () async {
      final s = _FakePlayback(fileThrows: true);
      await s.play(
          dua: _dua(
              audioMode: 'file', audioUrl: 'https://x/a.mp3', ar: '', en: ''),
          langCode: 'ar');
      expect(s.spoken, isEmpty, reason: 'there is nothing to say');
      expect(s.isPlaying, isFalse,
          reason: 'the button must not be left stuck on "playing"');
    });

    test('isPlaying is not left stuck after the file fails', () async {
      final s = _FakePlayback(fileThrows: true);
      final seen = <bool>[];
      s.onPlayingStateChanged = seen.add;
      await s.play(
          dua: _dua(audioMode: 'file', audioUrl: 'https://x/a.mp3'),
          langCode: 'ar');
      // false (stop) → true (file starting) → false (file failed). The last
      // word belongs to TTS's own start handler on a real device.
      expect(seen, [false, true, false]);
      expect(s.isPlaying, isFalse);
    });
  });

  group('the paths that already worked are unchanged', () {
    test('audioMode "file" with an empty url speaks, and tries no file',
        () async {
      final s = _FakePlayback();
      await s.play(dua: _dua(audioMode: 'file', audioUrl: ''), langCode: 'ar');
      expect(s.playedFiles, isEmpty);
      expect(s.spoken, [kArabic]);
    });

    test('a whitespace-only url counts as empty', () async {
      final s = _FakePlayback();
      await s.play(
          dua: _dua(audioMode: 'file', audioUrl: '   '), langCode: 'ar');
      expect(s.playedFiles, isEmpty);
      expect(s.spoken, [kArabic]);
    });

    test('audioMode "tts" speaks and never touches the player', () async {
      final s = _FakePlayback();
      await s.play(
          dua: _dua(audioMode: 'tts', audioUrl: 'https://x/a.mp3'),
          langCode: 'ar');
      expect(s.playedFiles, isEmpty,
          reason: 'a url is irrelevant unless the mode says file');
      expect(s.spoken, [kArabic]);
    });

    test('empty text with no file speaks nothing', () async {
      final s = _FakePlayback();
      await s.play(dua: _dua(audioMode: 'tts', ar: '', en: ''), langCode: 'ar');
      expect(s.spoken, isEmpty);
      expect(s.isPlaying, isFalse);
    });

    test('stop() resets the state and stops both engines', () async {
      final s = _FakePlayback();
      await s.play(
          dua: _dua(audioMode: 'file', audioUrl: 'https://x/a.mp3'),
          langCode: 'ar');
      expect(s.isPlaying, isTrue);
      await s.stop();
      expect(s.isPlaying, isFalse);
      expect(s.stopCalls, 2, reason: 'once inside play(), once explicitly');
    });

    test('switching tracks stops the previous one first', () async {
      final s = _FakePlayback();
      await s.play(dua: _dua(audioMode: 'tts'), langCode: 'ar');
      await s.play(dua: _dua(audioMode: 'tts', ar: 'نص آخر'), langCode: 'ar');
      expect(s.stopCalls, 2);
      expect(s.spoken, [kArabic, 'نص آخر']);
      // The language was applied once and not re-applied for the same code.
      expect(s.languages, ['ar-SA']);
    });

    test('replay goes through the same path', () async {
      final s = _FakePlayback(fileThrows: true);
      await s.replay(
          dua: _dua(audioMode: 'file', audioUrl: 'https://x/a.mp3'),
          langCode: 'ar');
      expect(s.spoken, [kArabic],
          reason: 'the manual replay button gets the fallback too');
    });
  });

  group('this change does not make anything newly playable', () {
    test('the service is not a gate, and was not turned into one', () {
      // play() has never consulted contentKind, and still does not: the
      // caller decides. Non-recitable kinds are kept away by canPlayManually
      // at the call sites, which this change does not touch.
      for (final kind in ['procedural_guidance', 'contextual_evidence']) {
        final m = _dua(audioMode: 'tts', contentKind: kind);
        expect(m.canPlayManually, isFalse,
            reason: '$kind must not be offered a play button');
        expect(m.isAutoPlayable, isFalse);
      }
      for (final kind in [
        'general_dua',
        'specific_text',
        'general_dhikr',
        'mosque_entry'
      ]) {
        expect(
            _dua(audioMode: 'tts', contentKind: kind).canPlayManually, isTrue,
            reason: '$kind is recitable and was already playable');
      }
    });

    test('the call sites still check the gate before calling the service', () {
      // The guard that actually protects a pilgrim lives in the screen, and
      // the fallback must not tempt anyone to relax it. Voice search is the
      // sharp edge: one spoken result is played with no button press.
      final screen =
          File('lib/Screens/Piligram/Duas/duas_screen.dart').readAsStringSync();
      expect(screen.contains('if (!dua.canPlayManually) return;'), isTrue,
          reason: 'the playback gate was removed from the screen');

      final controller =
          File('lib/Screens/Piligram/Home/controllers/home_dua_controller.dart')
              .readAsStringSync();
      expect(controller.contains('.where((e) => e.isAutoPlayable)'), isTrue,
          reason: 'automatic playback must stay on the narrower gate');
    });
  });
}
