import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/supplication_model.dart';

class DuaPlaybackService {
  // Lazily built. Both plugin objects wire platform channels the moment they
  // are constructed, so creating them eagerly would make this service
  // impossible to exercise off-device even when every call it makes is
  // replaced. `late final` defers that to first real use — on a device that
  // is init(), which is unchanged; in a test that overrides the seams below,
  // it never happens at all.
  late final FlutterTts _tts = FlutterTts();
  late final AudioPlayer _audioPlayer = AudioPlayer();

  // ── platform seams ──────────────────────────────────────────────────────
  //
  // The five calls below are the only places this service touches a plugin.
  // They are separated out so a test can subclass and drive the fallback
  // without a device, a network, or a method channel — every other line of
  // logic then runs for real. Nothing else about them is special: each is a
  // one-line forward to the engine it wraps.

  @protected
  @visibleForTesting
  Future<void> playFile(String url) => _audioPlayer.play(UrlSource(url));

  @protected
  @visibleForTesting
  Future<void> speakText(String text) => _tts.speak(text);

  @protected
  @visibleForTesting
  Future<void> setTtsLanguage(String language) => _tts.setLanguage(language);

  @protected
  @visibleForTesting
  Future<void> setTtsVoice(Map<String, String> voice) => _tts.setVoice(voice);

  @protected
  @visibleForTesting
  Future<void> stopEngines() async {
    await _audioPlayer.stop();
    await _tts.stop();
  }

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
        if (n.contains('enhanced') ||
            n.contains('neural') ||
            n.contains('premium')) s += 4;
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
    await stopEngines();
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
      try {
        await playFile(dua.audioUrl.trim());
        return;
      } catch (_) {
        // فشل تحميل/تشغيل الرابط: شبكة ضعيفة، أو ملف تالف، أو كائن محذوف.
        //
        // كان هذا الموضع يكتفي بإعادة الحالة ثم `return`، فيصمت التطبيق
        // صمتًا تامًّا: لا صوت، ولا رسالة، ولا نصّ منطوق. والحاجّ يضغط زر
        // التشغيل وهو في الطواف. والصمت هنا أسوأ من غياب الملف أصلًا، لأن
        // غياب الملف يسقط إلى TTS منذ البداية.
        //
        // فبدل الخروج، نُعيد ضبط حالة مشغّل الملف ثم نتابع إلى مسار TTS
        // أدناه — بالسقوط خلال الدالة نفسها، لا باستدعائها من جديد: العودة
        // إلى play() هنا تعيد تنفيذ stop() وتفتح باب حلقة لا تنتهي إن ظلّ
        // الملف يفشل.
        _updatePlayingState(false);
      }
    }

    final text = dua.textByLanguage(langCode).trim();
    if (text.isEmpty) {
      _updatePlayingState(false);
      return;
    }

    if (langCode == 'ar') {
      if (_currentLangCode != 'ar') {
        await setTtsLanguage('ar-SA');
        _currentLangCode = 'ar';
      }
      if (_bestArabicVoice != null && _currentVoice != _bestArabicVoice) {
        try {
          await setTtsVoice(_bestArabicVoice!);
          _currentVoice = _bestArabicVoice;
        } catch (_) {}
      }
    } else {
      if (_currentLangCode != langCode) {
        await setTtsLanguage('en-US');
        _currentLangCode = langCode;
        _currentVoice = null;
      }
    }

    await speakText(text);
  }

  Future<void> dispose() async {
    await stop();
  }
}
