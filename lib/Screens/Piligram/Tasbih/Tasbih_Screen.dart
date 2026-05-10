import 'package:flutter/material.dart';
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

    await CashHelper.saveCash(
      key: _countKey,
      value: newValue,
    );
  }

  Future<void> _reset() async {
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
                    onTap: _inc,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
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
                          Text(
                            '$_count',
                            style: TextStyle(
                              color: palette.gold,
                              fontSize: 58,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
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
              const SizedBox(height: 18),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _reset,
                                child: Ink(
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