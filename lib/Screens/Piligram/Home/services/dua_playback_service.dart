import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/supplication_model.dart';

class DuaPlaybackService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  // --- [إضافة الذاكرة الذكية لتتبع الزونات وتصفيرها تلقائياً] ---
  String? _lastPlayedZoneId;

  /// دالة مخصصة لتصفير الزون عند الخروج، يتم استدعاؤها برمجياً أو تلقائياً
  void resetZoneMemory() {
    _lastPlayedZoneId = null;
  }
  // -------------------------------------------------------------

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

  /// زر إعادة التشغيل اليدوي (يتخطى حماية التكرار دائماً ويشغل الصوت فوراً)
  Future<void> replay({
    required SupplicationModel dua,
    required String langCode,
  }) async {
    await play(
      dua: dua,
      langCode: langCode,
      forcePlay: true, // نمرر إذن الإجبار هنا
    );
  }

  /// دالة التشغيل التلقائي الذكية والمحمية من التكرار المزعج
  Future<void> play({
    required SupplicationModel dua,
    required String langCode,
    String? zoneId,       // نمرر الـ zoneId الحالي هنا لتتبعه
    bool forcePlay = false, // لتحديد هل الدخول يدوي أو تلقائي من الجيوفنس
  }) async {
    // إذا كان الخروج للنطاق المفتوح (zoneId == null)، نصفّر الذاكرة فوراً ونقفل التشغيل
    if (zoneId == null && !forcePlay) {
      resetZoneMemory();
      await stop();
      return;
    }

    // إذا كان التشغيل تلقائي من الجيوفنس والزون الحالي هو نفسه اللي توه اشتغل، نرفض التكرار
    if (!forcePlay && zoneId != null && _lastPlayedZoneId == zoneId) {
      return;
    }

    await stop();

    // حفظ الزون الحالي في الذاكرة عشان ما يرجع يكرر تلقائياً داخل نفس المكان
    if (zoneId != null) {
      _lastPlayedZoneId = zoneId;
    }

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