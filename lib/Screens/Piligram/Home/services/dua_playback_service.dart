import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/supplication_model.dart';

class DuaPlaybackService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  void Function(bool isPlaying)? onPlayingStateChanged;

  void _updatePlayingState(bool value) {
    _isPlaying = value;
    onPlayingStateChanged?.call(value);
  }

  Future<void> init() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.42);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _audioPlayer.onPlayerComplete.listen((_) {
      _updatePlayingState(false);
    });

    _tts.setStartHandler(() {
      _updatePlayingState(true);
    });

    _tts.setCompletionHandler(() {
      _updatePlayingState(false);
    });

    _tts.setCancelHandler(() {
      _updatePlayingState(false);
    });

    _tts.setErrorHandler((_) {
      _updatePlayingState(false);
    });
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    await _tts.stop();
    _updatePlayingState(false);
  }

  /// زر إعادة التشغيل اليدوي
  Future<void> replay({
    required SupplicationModel dua,
    required String langCode,
  }) async {
    await play(
      dua: dua,
      langCode: langCode,
    );
  }

  /// تشغيل الدعاء: يوقف أي تشغيل سابق ثم يبدأ من جديد.
  /// منطق منع التكرار (داخل نفس النطاق، وإعادة التشغيل عند العودة) يتكفّل
  /// به HomeDuaController، فمهمة هذه الدالة هي التشغيل فقط.
  Future<void> play({
    required SupplicationModel dua,
    required String langCode,
  }) async {
    await stop();

    final hasFile = dua.audioMode == 'file' && dua.audioUrl.trim().isNotEmpty;

    if (hasFile) {
      _updatePlayingState(true);
      await _audioPlayer.play(UrlSource(dua.audioUrl.trim()));
      return;
    }

    final text = dua.textByLanguage(langCode).trim();
    if (text.isEmpty) {
      _updatePlayingState(false);
      return;
    }

    if (langCode == 'ar') {
      await _tts.setLanguage('ar-SA');
    } else {
      await _tts.setLanguage('en-US');
    }

    await _tts.speak(text);
  }

  Future<void> dispose() async {
    await stop();
  }
}