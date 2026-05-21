import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // مستدعاة للتحكم بالاهتزازات الحسية بالملي
import '../../../generated/l10n.dart';
import '../../../shared/network/local/cash_helper.dart';

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  static const String _countKey = 'tasbih_count';

  int _count = 0;
  bool _isLoading = true;

  // متغيرات للتحكم بالتحجيم المطاطي للدائرة الكبيرة وزر التصفير
  double _circleScale = 1.0;
  double _buttonScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final cached = CashHelper.getCash(key: _countKey);

    if (!mounted) return;

    setState(() {
      _count = cached is int ? cached : 0;
      _isLoading = false;
    });
  }

  Future<void> _inc() async {
    final newValue = _count + 1;

    setState(() {
      _count = newValue;
    });

    // لغة الحركة: نبضات حسية ذكية متوافقة مع الأذكار والتسبيح
    if (newValue % 33 == 0) {
      HapticFeedback.mediumImpact(); // نبضة واضحة تنبه الحاج عند الوصول لـ 33 أو مضاعفاتها
    } else {
      HapticFeedback.lightImpact(); // نبضة ناعمة وخفيفة جداً مع كل خرزة تسبيح
    }

    await CashHelper.saveCash(
      key: _countKey,
      value: newValue,
    );
  }

  Future<void> _reset() async {
    HapticFeedback.vibrate(); // اهتزاز متتابع يؤكد للحاج نجاح تصفير السبحة

    setState(() {
      _count = 0;
    });

    await CashHelper.saveCash(
      key: _countKey,
      value: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final palette = _TasbihPalette.fromBrightness(isDark);

    return Container(
      color: palette.bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                child: Text(
                  s.tasbihTitle,
                  style: TextStyle(
                    color: palette.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'AlamirBold',
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 1,
                color: palette.divider.withOpacity(.18),
              ),
              const SizedBox(height: 26),
              Expanded(
                flex: 2,
                child: Center(
                  child: _isLoading
                      ? CircularProgressIndicator(
                    color: palette.gold,
                  )
                      : GestureDetector(
                    onTapDown: (_) {
                      setState(() {
                        _circleScale = 0.94; // كبس الدائرة الكبيرة للداخل عند الضغط
                      });
                    },
                    onTapUp: (_) {
                      setState(() {
                        _circleScale = 1.0; // الارتداد المرن فور رفع الإصبع
                      });
                      _inc();
                    },
                    onTapCancel: () {
                      setState(() {
                        _circleScale = 1.0;
                      });
                    },
                    child: AnimatedScale(
                      scale: _circleScale,
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.circleBg,
                          border: Border.all(
                            color: palette.stroke.withOpacity(.88),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: palette.shadow.withOpacity(.18),
                              blurRadius: 28,
                              offset: const Offset(0, 16),
                            ),
                            BoxShadow(
                              color: palette.gold.withOpacity(.06),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // أنميشن تدحرج وصعود الأرقام الأنيق
                            SizedBox(
                              height: 62,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 240),
                                transitionBuilder: (Widget child, Animation<double> animation) {
                                  final isReset = child.key == const ValueKey(0);

                                  // إذا كانت العملية تصفير (Reset)، تتدحرج الأرقام من الأعلى، وإذا كانت تسبيح تصعد من الأسفل
                                  final offsetIn = isReset
                                      ? const Offset(0.0, -0.6)
                                      : const Offset(0.0, 0.6);
                                  final offsetOut = isReset
                                      ? const Offset(0.0, 0.6)
                                      : const Offset(0.0, -0.6);

                                  return SlideTransition(
                                    position: Tween<Offset>(
                                      begin: child.key == ValueKey(_count) ? offsetIn : Offset.zero,
                                      end: child.key == ValueKey(_count) ? Offset.zero : offsetOut,
                                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Text(
                                  '$_count',
                                  key: ValueKey(_count),
                                  style: TextStyle(
                                    color: palette.gold,
                                    fontSize: 58,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              s.tasbihTapHint,
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: palette.card,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: palette.border.withOpacity(.95),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: palette.shadow.withOpacity(.10),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            s.tasbihTapHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTapDown: (_) {
                              setState(() {
                                _buttonScale = 0.96; // تأثير الكبس لزر التصفير
                              });
                            },
                            onTapUp: (_) {
                              setState(() {
                                _buttonScale = 1.0;
                              });
                              _reset();
                            },
                            onTapCancel: () {
                              setState(() {
                                _buttonScale = 1.0;
                              });
                            },
                            child: AnimatedScale(
                              scale: _buttonScale,
                              duration: const Duration(milliseconds: 100),
                              curve: Curves.easeOutCubic,
                              child: Container(
                                width: double.infinity,
                                height: 58,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: palette.buttonBg,
                                  border: Border.all(
                                    color: palette.border.withOpacity(.95),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    s.tasbihReset,
                                    style: TextStyle(
                                      color: palette.buttonText,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _TasbihPalette {
  final Color bg;
  final Color gold;
  final Color muted;
  final Color card;
  final Color circleBg;
  final Color buttonBg;
  final Color buttonText;
  final Color stroke;
  final Color border;
  final Color divider;
  final Color shadow;

  const _TasbihPalette({
    required this.bg,
    required this.gold,
    required this.muted,
    required this.card,
    required this.circleBg,
    required this.buttonBg,
    required this.buttonText,
    required this.stroke,
    required this.border,
    required this.divider,
    required this.shadow,
  });

  factory _TasbihPalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _TasbihPalette(
        bg: Color(0xFF0B0D10),
        gold: Color(0xFFD4AF37),
        muted: Color(0xFF9AA4B2),
        card: Color(0xFF303030),
        circleBg: Color(0xFF111317),
        buttonBg: Color(0xFF303030),
        buttonText: Colors.white,
        stroke: Color(0xFF3B3F46),
        border: Color(0xFF1B1F26),
        divider: Colors.white,
        shadow: Colors.black,
      );
    }

    return const _TasbihPalette(
      bg: Color(0xFFF7F7F8),
      gold: Color(0xFFD4AF37),
      muted: Color(0xFF667085),
      card: Colors.white,
      circleBg: Color(0xFFFFFFFF),
      buttonBg: Color(0xFFF3F4F6),
      buttonText: Color(0xFF121316),
      stroke: Color(0xFFE5E7EB),
      border: Color(0xFFE5E7EB),
      divider: Color(0xFF121316),
      shadow: Color(0x22000000),
    );
  }
}