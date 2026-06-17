import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../services/assistant_service.dart';

/// شاشة المساعد الصوتي الذكي للحج والعمرة.
/// الحاج يختار لغته، يضغط الميكروفون ويتكلم، فيسمعه المساعد ويرد بصوت بنفس اللغة.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _Msg {
  final String text;
  final bool fromUser;
  final bool isError;
  _Msg(this.text, {this.fromUser = false, this.isError = false});
}

class _Lang {
  final String label;
  final String sttLocale;
  final String ttsLocale;
  const _Lang(this.label, this.sttLocale, this.ttsLocale);
}

class _AssistantPalette {
  final Color bg;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color divider;

  const _AssistantPalette({
    required this.bg,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.divider,
  });

  factory _AssistantPalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _AssistantPalette(
        bg: Color(0xFF0B0D10),
        card: Color(0xFF1A1D23),
        textPrimary: Colors.white,
        textSecondary: Color(0xFF9AA4B2),
        border: Color(0x1FFFFFFF),
        divider: Color(0x1AFFFFFF),
      );
    }
    return const _AssistantPalette(
      bg: Color(0xFFF7F7F8),
      card: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF121316),
      textSecondary: Color(0xFF667085),
      border: Color(0xFFE5E7EB),
      divider: Color(0xFFE5E7EB),
    );
  }
}

class _AssistantScreenState extends State<AssistantScreen> {
  static const _gold = Color(0xFFD4AF37);
  static const _gold2 = Color(0xFFB98B2E);
  static const _danger = Color(0xFFE0463F);

  _AssistantPalette _p = _AssistantPalette.fromBrightness(true);

  static const List<_Lang> _languages = [
    _Lang('العربية', 'ar_SA', 'ar-SA'),
    _Lang('English', 'en_US', 'en-US'),
    _Lang('اردو', 'ur_PK', 'ur-PK'),
    _Lang('Türkçe', 'tr_TR', 'tr-TR'),
    _Lang('Indonesia', 'id_ID', 'id-ID'),
    _Lang('Français', 'fr_FR', 'fr-FR'),
  ];

  final AssistantService _service = AssistantService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<_Msg> _messages = [];
  _Lang _lang = _languages.first;
  bool _speechReady = false;
  bool _listening = false;
  bool _sending = false;
  String? _speakingText;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);
    // نحاول اختيار أفضل صوت عربي متاح على الجهاز (Google > غيره).
    try {
      final voices = await _tts.getVoices as List?;
      if (voices != null) {
        final arVoices = voices
            .whereType<Map>()
            .where((v) {
              final locale = (v['locale'] ?? v['language'] ?? '').toString().toLowerCase();
              return locale.startsWith('ar');
            })
            .toList();
        // نفضّل Google TTS ثم أي صوت عربي آخر.
        final best = arVoices.firstWhere(
          (v) => (v['name'] ?? '').toString().toLowerCase().contains('google'),
          orElse: () => arVoices.isNotEmpty ? arVoices.first : <String, dynamic>{},
        );
        if (best.isNotEmpty == true && best['name'] != null) {
          await _tts.setVoice({'name': best['name'], 'locale': best['locale'] ?? best['language'] ?? 'ar-SA'});
        }
      }
    } catch (_) {
      // فشل اختيار الصوت — يعود للافتراضي.
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechReady = await _speech.initialize(
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            if (mounted) setState(() => _listening = false);
          }
        },
        onError: (e) {
          if (!mounted) return;
          setState(() => _listening = false);
          final msg = e.errorMsg.toLowerCase();
          if (msg.contains('language') ||
              msg.contains('not_supported') ||
              msg.contains('unavailable')) {
            _showVoiceUnavailable();
          }
        },
      );
    } catch (_) {
      _speechReady = false;
    }
    if (mounted) setState(() {});
  }

  void _showVoiceUnavailable() {
    final ar = _isRtl(_lang.label);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _p.card,
        behavior: SnackBarBehavior.floating,
        content: Text(
          ar
              ? 'صوت «${_lang.label}» غير مثبّت بجهازك — اكتب سؤالك بدلاً من الميكروفون.'
              : 'Voice for "${_lang.label}" isn\'t installed on your device — please type instead.',
          style: TextStyle(color: _p.textPrimary),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speech.cancel();
    _tts.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _isRtl(String t) => RegExp(r'[؀-ۿ]').hasMatch(t);

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleListen() async {
    HapticFeedback.mediumImpact();
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) return;
    }
    await _tts.stop();
    setState(() => _listening = true);
    await _speech.listen(
      localeId: _lang.sttLocale,
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      onResult: (r) {
        _input.text = r.recognizedWords;
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
          _send(r.recognizedWords);
        }
      },
    );
  }

  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _sending) return;

    if (_listening) {
      await _speech.stop();
    }

    setState(() {
      _messages.add(_Msg(msg, fromUser: true));
      _input.clear();
      _listening = false;
      _sending = true;
    });
    _scrollToEnd();

    try {
      final reply = await _service.ask(msg);
      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(reply));
        _sending = false;
      });
      _scrollToEnd();
      await _speak(reply);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(_friendlyError(e), isError: true));
        _sending = false;
      });
      _scrollToEnd();
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('GROQ_API_KEY')) {
      return 'مفتاح المساعد غير مُفعّل بعد. يُشغَّل التطبيق بمفتاح Groq عبر '
          '--dart-define=GROQ_API_KEY';
    }
    return 'تعذّر الوصول للمساعد الآن. تحقّق من الاتصال وحاول مرة أخرى.';
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    if (_speakingText == text) {
      await _tts.stop();
      if (mounted) setState(() => _speakingText = null);
      return;
    }
    try {
      if (mounted) setState(() => _speakingText = text);
      await _tts.setLanguage(_ttsLocaleFor(text));
      await _tts.speak(text);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _speakingText = null);
    }
  }

  String _ttsLocaleFor(String text) {
    if (_isRtl(text)) return _lang.ttsLocale;
    return _lang.ttsLocale == 'ar-SA' ? 'en-US' : _lang.ttsLocale;
  }

  void _clear() {
    _tts.stop();
    _service.clearHistory();
    setState(() => _messages.clear());
  }

  List<String> _suggestionsFor(String locale) {
    switch (locale) {
      case 'ar_SA':
        return [
          'ماذا أفعل بعد الطواف؟',
          'اشرح لي دعاء الإحرام',
          'أنا كبير في السن، كيف أؤدي السعي؟',
          'ما حكم الطواف بغير وضوء؟',
          'متى يكون رمي الجمرات؟',
        ];
      case 'en_US':
        return [
          'What do I do after Tawaf?',
          'Explain the Ihram supplication',
          'How do I perform Sa\'i if I am elderly?',
          'When do I stone the Jamarat?',
          'What is the correct Talbiyah?',
        ];
      case 'ur_PK':
        return [
          'طواف کے بعد کیا کریں؟',
          'احرام کی دعا بتائیں',
          'سعی کیسے کریں؟',
        ];
      case 'tr_TR':
        return [
          'Tavaftan sonra ne yapmalıyım?',
          'İhram duasını açıklar mısın?',
          'Cemrelere ne zaman taş atılır?',
        ];
      case 'id_ID':
        return [
          'Apa yang harus dilakukan setelah tawaf?',
          'Jelaskan doa ihram',
          'Kapan waktu melempar jumrah?',
        ];
      case 'fr_FR':
        return [
          'Que faire après le Tawaf ?',
          'Expliquez la supplication de l\'Ihram',
          'Comment effectuer le Sa\'i ?',
        ];
      default:
        return [
          'What do I do after Tawaf?',
          'Explain the Ihram supplication',
          'How do I perform Sa\'i?',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _p = _AssistantPalette.fromBrightness(isDark);

    return Directionality(
      textDirection: _isRtl(_lang.label) ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        color: _p.bg,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              _languageBar(),
              Expanded(
                child: _messages.isEmpty ? _welcome() : _chatList(),
              ),
              if (_sending) _thinkingBar(),
              _inputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 2),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: _gold, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'المساعد الذكي',
              style: TextStyle(color: _gold, fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ),
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: _clear,
              icon: Icon(Icons.delete_sweep_rounded, color: _p.textSecondary),
              tooltip: 'محادثة جديدة',
            ),
        ],
      ),
    );
  }

  Widget _languageBar() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        itemCount: _languages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final l = _languages[i];
          final sel = l.sttLocale == _lang.sttLocale;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _lang = l);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? _gold.withOpacity(.16) : _p.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? _gold : _p.border,
                  width: sel ? 1.4 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                l.label,
                style: TextStyle(
                  color: sel ? _gold : _p.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _welcome() {
    final examples = _suggestionsFor(_lang.sttLocale);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_gold.withOpacity(.22), _gold2.withOpacity(.10)]),
              border: Border.all(color: _gold.withOpacity(.4), width: 1.4),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: _gold, size: 40),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'اسألني عن مناسك الحج والعمرة',
          textAlign: TextAlign.center,
          style: TextStyle(color: _p.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'اضغط الميكروفون وتكلّم بلغتك، أو اكتب سؤالك',
          textAlign: TextAlign.center,
          style: TextStyle(color: _p.textSecondary, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 26),
        ...examples.map((q) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _send(q),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _p.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _p.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.help_outline_rounded, color: _gold, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(q,
                            style: TextStyle(color: _p.textPrimary, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _chatList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _bubble(_messages[i]),
    );
  }

  Widget _bubbleEntrance(Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: c),
      ),
      child: child,
    );
  }

  Widget _bubble(_Msg m) {
    final rtl = _isRtl(m.text);
    final align = m.fromUser ? Alignment.centerLeft : Alignment.centerRight;
    final bg = m.isError
        ? _danger.withOpacity(.15)
        : (m.fromUser ? _gold.withOpacity(.16) : _p.card);
    final border = m.isError
        ? _danger.withOpacity(.5)
        : (m.fromUser ? _gold.withOpacity(.4) : _p.border);
    final color = m.isError ? const Color(0xFFFFB4B0) : _p.textPrimary;

    return _bubbleEntrance(Align(
      alignment: Directionality.of(context) == TextDirection.rtl
          ? (m.fromUser ? Alignment.centerLeft : Alignment.centerRight)
          : align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!m.fromUser && !m.isError) ...[
              const Icon(Icons.auto_awesome_rounded, color: _gold, size: 16),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Text(
                  m.text,
                  style: TextStyle(color: color, fontSize: 15, height: 1.55),
                ),
              ),
            ),
            if (!m.fromUser && !m.isError) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _speak(m.text),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _speakingText == m.text
                      ? const Icon(Icons.stop_circle_rounded, color: _gold, size: 20, key: ValueKey('playing'))
                      : Icon(Icons.volume_up_rounded, color: _p.textSecondary, size: 18, key: const ValueKey('stopped')),
                ),
              ),
            ],
          ],
        ),
      ),
    ));
  }

  Widget _thinkingBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _TypingDots(),
          const SizedBox(width: 10),
          Text('المساعد يكتب...', style: TextStyle(color: _p.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      decoration: BoxDecoration(
        color: _p.bg,
        border: Border(top: BorderSide(color: _p.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _p.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _p.border),
                ),
                child: TextField(
                  controller: _input,
                  style: TextStyle(color: _p.textPrimary),
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  decoration: InputDecoration(
                    hintText: 'اكتب سؤالك...',
                    hintStyle: TextStyle(color: _p.textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _send(_input.text),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _p.card),
                child: const Icon(Icons.send_rounded, color: _gold, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _toggleListen,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _listening ? [_danger, const Color(0xFFB23A35)] : [_gold, _gold2],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_listening ? _danger : _gold).withOpacity(.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _listening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: const Color(0xFF14171C),
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ثلاث نقاط ذهبية تنبض بالتتابع — مؤشّر «يكتب» حيّ بإحساس عصري.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_c.value - i * 0.18) % 1.0;
            final scale = 0.6 + 0.4 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: gold.withOpacity(0.4 + 0.6 * (scale - 0.6) / 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
