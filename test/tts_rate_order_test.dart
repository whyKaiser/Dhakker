// The rate must be applied BEFORE the text is spoken, on every utterance.
//
// It used to be set once at init, before any language or voice existed — and
// both are chosen per utterance now. A rate applied after `speak` is a no-op,
// and a test that only checked the VALUE would pass while the pilgrim still
// heard a drawl. So this asserts the order.

import 'package:dhakker/Screens/Assistant/tts_voice.dart';
import 'package:dhakker/Screens/Piligram/Home/services/dua_playback_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _OrderRecordingPlayback extends DuaPlaybackService {
  final List<String> calls = <String>[];
  final List<double> rates = <double>[];

  @override
  Future<void> setTtsRate(double rate) async {
    calls.add('rate');
    rates.add(rate);
  }

  @override
  Future<void> speakOnly(String text) async {
    calls.add('speak');
  }
}

void main() {
  test('the rate is applied before speaking, not after', () async {
    final playback = _OrderRecordingPlayback();
    await playback.speakText('اللهم لبيك');
    expect(playback.calls, ['rate', 'speak']);
  });

  test('the rate applied is the platform\'s normal speed', () async {
    final playback = _OrderRecordingPlayback();
    await playback.speakText('test');
    expect(
        playback.rates.single,
        naturalSpeechRate(
            isWeb: kIsWeb, platformName: defaultTargetPlatform.name));
    // And never the old drawl, whatever platform the test runs on.
    expect(playback.rates.single, greaterThanOrEqualTo(0.5));
  });

  test('every utterance re-applies it, not just the first', () async {
    // A language or voice switch happens between utterances; a rate set once
    // is exactly the bug this replaced.
    final playback = _OrderRecordingPlayback();
    await playback.speakText('one');
    await playback.speakText('two');
    expect(playback.calls, ['rate', 'speak', 'rate', 'speak']);
  });
}
