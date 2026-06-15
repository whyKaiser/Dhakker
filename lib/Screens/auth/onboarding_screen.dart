import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/network/local/cash_helper.dart';
import '../../theme/dhakker_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  int _page = 0;

  static const _pages = [
    _OPage(
      icon: Icons.mosque_rounded,
      title: 'مرحباً بك في ذكّر',
      subtitle: 'رفيقك الذكي في رحلة الحج والعمرة — أدعية وإرشادات حسب موقعك لحظة بلحظة',
    ),
    _OPage(
      icon: Icons.loop_rounded,
      title: 'عدّاد الطواف والسعي',
      subtitle: 'يحسب أشواط الطواف والسعي تلقائياً بمجرد وجودك في المنطقة — بلا ضغط أي زر',
    ),
    _OPage(
      icon: Icons.auto_awesome_rounded,
      title: 'المساعد الذكي',
      subtitle: 'اسأل عن مناسك الحج والعمرة بلغتك — عربي، إنجليزي، أردو، فرنسي وأكثر',
    ),
    _OPage(
      icon: Icons.campaign_rounded,
      title: 'تنبيهات فورية',
      subtitle: 'يصلك إشعار فوري من إدارة المسجد عند أي تحديث أو تنبيه مهم',
    ),
  ];

  void _next() {
    HapticFeedback.lightImpact();
    if (_page < _pages.length - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeInOutCubic);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await CashHelper.saveCash(key: 'onboarding_done', value: true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final gold = isDark ? DhakkerColors.gold : DhakkerColors.gold2;
    final textColor = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    final isLast = _page == _pages.length - 1;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: TextButton(
                  onPressed: _finish,
                  child: Text('تخطّى', style: TextStyle(color: muted, fontSize: 14)),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _pages.length,
                  itemBuilder: (_, i) => _PageView(
                    page: _pages[i],
                    gold: gold,
                    textColor: textColor,
                    muted: muted,
                  ),
                ),
              ),
              // مؤشرات الصفحات
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _page ? gold : gold.withOpacity(.3),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [gold, isDark ? DhakkerColors.gold2 : DhakkerColors.gold],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _next,
                        child: Center(
                          child: Text(
                            isLast ? 'ابدأ الآن' : 'التالي',
                            style: const TextStyle(
                              color: Color(0xFF14171C),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  final _OPage page;
  final Color gold;
  final Color textColor;
  final Color muted;

  const _PageView({required this.page, required this.gold, required this.textColor, required this.muted});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [gold.withOpacity(.22), gold.withOpacity(.08)],
                ),
                border: Border.all(color: gold.withOpacity(.4), width: 1.5),
              ),
              child: Icon(page.icon, color: gold, size: 52),
            ),
            const SizedBox(height: 32),
            Text(
              page.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2,
                fontFamily: 'AlamirBold',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              page.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OPage {
  final IconData icon;
  final String title;
  final String subtitle;
  const _OPage({required this.icon, required this.title, required this.subtitle});
}
