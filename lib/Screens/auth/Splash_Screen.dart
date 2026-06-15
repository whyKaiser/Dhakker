import 'dart:async';
import 'package:dhakker/Screens/Admin/layout/admin_home_layout.dart';
import 'package:dhakker/Screens/Piligram/layout/Home_Layout.dart';
import 'package:flutter/material.dart';
// استيراد حزمة الموقع لطلب الصلاحية برمجياً من الآيفون
import 'package:geolocator/geolocator.dart';
import '../../../generated/l10n.dart';
import '../../../theme/dhakker_theme.dart';
import '../auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  final int userTypeIndex;
  const SplashScreen(this.userTypeIndex, {super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _pulseController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _textOffset;
  Timer? _timer;

  // دالة ذكية ومضمونة تطلب إذن الموقع من الآيفون فوراً عند فتح التطبيق
  Future<void> _requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (e) {
      print("خطأ أثناء طلب صلاحية الموقع: $e");
    }
  }

  @override
  void initState() {
    super.initState();

    // تشغيل طلب الصلاحية أول ما تفتح الشاشة مباشرة
    _requestLocationPermission();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _logoScale = Tween<double>(begin: .72, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.easeOutBack,
      ),
    );

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0, .55, curve: Curves.easeOut),
      ),
    );

    _textOffset = Tween<Offset>(
      begin: const Offset(0, .18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(.28, 1, curve: Curves.easeOutCubic),
      ),
    );

    _mainController.forward();
    _pulseController.repeat();

    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      switch(widget.userTypeIndex)
      {
        case 0:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            ),
          );
        case 1:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>  const AdminHomeLayout(),
            ),
          );
        case 2:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>  const AppHomeLayout(),
            ),
          );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final gold = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    return Scaffold(
      backgroundColor: bg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
              DhakkerColors.bg,
              const Color(0xFF111418),
              DhakkerColors.bg,
            ]
                : [
              DhakkerColors.lightBg,
              const Color(0xFFF9F4E8),
              DhakkerColors.lightBg,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -40,
                right: -30,
                child: _GlowCircle(
                  size: 180,
                  color: gold.withOpacity(isDark ? .10 : .12),
                ),
              ),
              Positioned(
                bottom: 60,
                left: -40,
                child: _GlowCircle(
                  size: 140,
                  color: gold.withOpacity(isDark ? .08 : .10),
                ),
              ),
              Center(
                child: FadeTransition(
                  opacity: _logoFade,
                  child: SlideTransition(
                    position: _textOffset,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final pulse = _pulseController.value;
                            return SizedBox(
                              width: 210,
                              height: 210,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  _PulseRing(
                                    progress: pulse,
                                    color: gold,
                                  ),
                                  _PulseRing(
                                    progress: (pulse + .35) % 1,
                                    color: gold,
                                  ),
                                  ScaleTransition(
                                    scale: _logoScale,
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: card,
                                        border: Border.all(
                                          color: gold.withOpacity(.35),
                                          width: 1.4,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: gold.withOpacity(.18),
                                            blurRadius: 28,
                                            offset: const Offset(0, 14),
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              isDark ? .24 : .06,
                                            ),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.menu_book_rounded,
                                        color: gold,
                                        size: 52,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 22),
                        Text(
                          s.appTitle,
                          style: TextStyle(
                            color: text,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Text(
                            s.splashSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          width: 120,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              minHeight: 5,
                              backgroundColor:
                              (isDark ? Colors.white : Colors.black)
                                  .withOpacity(.08),
                              valueColor: AlwaysStoppedAnimation(gold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.splashLoading,
                          style: TextStyle(
                            color: muted.withOpacity(.9),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  final double progress;
  final Color color;

  const _PulseRing({
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final size = 120 + (progress * 70);
    final opacity = (1 - progress).clamp(0.0, 1.0) * .22;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withOpacity(opacity),
          width: 2,
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 80,
              spreadRadius: 12,
            ),
          ],
        ),
      ),
    );
  }
}