import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/supplication_model.dart';

class DuaPlaybackService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  // أفضل صوت عربي متوفّر بالجهاز (نختاره مرة وحدة في init)
  Map<String, String>? _bestArabicVoice;

  // آخر لغة وصوت طُبِّقا — نتجاوز setLanguage/setVoice لو ما تغيّرا
  String? _currentLangCode;
  Map<String, String>? _currentVoice;

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

    // نختار أفضل صوت عربي متوفّر بالجهاز (محسّن/شبكي إن وُجد)
    await _loadBestArabicVoice();

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

  /// يبحث عن كل الأصوات العربية المتوفّرة بالجهاز ويختار الأفضل جودة.
  /// يفضّل الأصوات المحسّنة/الشبكية (enhanced/network) على المحلية البسيطة.
  /// لو فشل أو ما فيه أصوات عربية، نكتفي بـ setLanguage العادي لاحقاً.
  Future<void> _loadBestArabicVoice() async {
    try {
      final dynamic raw = await _tts.getVoices;
      if (raw is! List) return;

      final arabic = <Map<String, String>>[];
      for (final v in raw) {
        if (v is Map) {
          final name = (v['name'] ?? '').toString();
          final locale = (v['locale'] ?? '').toString();
          if (name.isEmpty) continue;
          if (locale.toLowerCase().startsWith('ar') ||
              name.toLowerCase().startsWith('ar')) {
            arabic.add({'name': name, 'locale': locale});
          }
        }
      }
      if (arabic.isEmpty) return;

      int score(Map<String, String> v) {
        final n = v['name']!.toLowerCase();
        final loc = v['locale']!.toLowerCase();
        int s = 0;
        if (n.contains('network')) s += 4;
        if (n.contains('enhanced') || n.contains('neural') || n.contains('premium')) s += 4;
        if (loc.contains('sa')) s += 2; // العربية السعودية مفضّلة
        if (loc.contains('xa')) s += 1; // صوت قوقل العربي
        return s;
      }

      arabic.sort((a, b) => score(b).compareTo(score(a)));
      _bestArabicVoice = arabic.first;
    } catch (_) {
      _bestArabicVoice = null;
    }
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
      if (_currentLangCode != 'ar') {
        await _tts.setLanguage('ar-SA');
        _currentLangCode = 'ar';
      }
      if (_bestArabicVoice != null && _currentVoice != _bestArabicVoice) {
        try {
          await _tts.setVoice(_bestArabicVoice!);
          _currentVoice = _bestArabicVoice;
        } catch (_) {}
      }
    } else {
      if (_currentLangCode != langCode) {
        await _tts.setLanguage('en-US');
        _currentLangCode = langCode;
        _currentVoice = null;
      }
    }

    await _tts.speak(text);
  }

  Future<void> dispose() async {
    await stop();
  }
}