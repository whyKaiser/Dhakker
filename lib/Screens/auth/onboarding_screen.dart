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
  final _nameCtrl = TextEditingController();
  String _tripType = 'hajj'; // 'hajj' or 'umrah'

  // total pages = info pages + 1 setup page
  static const int _setupPageIndex = 4;

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
    final totalPages = _pages.length + 1; // +1 for setup page
    if (_page < totalPages - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeInOutCubic);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_page == _setupPageIndex) {
      await CashHelper.saveCash(key: 'pilgrim_name', value: _nameCtrl.text.trim());
      await CashHelper.saveCash(key: 'trip_type', value: _tripType);
    }
    await CashHelper.saveCash(key: 'onboarding_done', value: true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final gold = isDark ? DhakkerColors.gold : DhakkerColors.gold2;
    final textColor = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    final totalPages = _pages.length + 1;
    final isLast = _page == totalPages - 1;

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
                  itemCount: _pages.length + 1,
                  itemBuilder: (_, i) {
                    if (i < _pages.length) {
                      return _PageView(page: _pages[i], gold: gold, textColor: textColor, muted: muted);
                    }
                    return _SetupPage(
                      gold: gold,
                      textColor: textColor,
                      muted: muted,
                      isDark: isDark,
                      nameCtrl: _nameCtrl,
                      tripType: _tripType,
                      onTripTypeChanged: (v) => setState(() => _tripType = v),
                    );
                  },
                ),
              ),
              // مؤشرات الصفحات
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length + 1, (i) {
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

class _SetupPage extends StatelessWidget {
  final Color gold;
  final Color textColor;
  final Color muted;
  final bool isDark;
  final TextEditingController nameCtrl;
  final String tripType;
  final ValueChanged<String> onTripTypeChanged;

  const _SetupPage({
    required this.gold,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.nameCtrl,
    required this.tripType,
    required this.onTripTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF1E2329) : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 90, height: 90,
            margin: const EdgeInsets.only(bottom: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [gold.withOpacity(.22), gold.withOpacity(.08)]),
              border: Border.all(color: gold.withOpacity(.4), width: 1.5),
            ),
            child: Icon(Icons.waving_hand_rounded, color: gold, size: 44),
          ),
          Text('أخبرنا عنك', textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.w900, fontFamily: 'AlamirBold')),
          const SizedBox(height: 8),
          Text('حتى نُهيّئ التجربة لك', textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 15)),
          const SizedBox(height: 32),
          // حقل الاسم
          TextField(
            controller: nameCtrl,
            textAlign: TextAlign.right,
            style: TextStyle(color: textColor, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'اسمك (اختياري)',
              hintStyle: TextStyle(color: muted),
              filled: true,
              fillColor: cardColor,
              prefixIcon: Icon(Icons.person_outline_rounded, color: gold),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(height: 20),
          // نوع الرحلة
          Text('نوع رحلتك', style: TextStyle(color: muted, fontSize: 14), textAlign: TextAlign.right),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _TripTypeBtn(label: 'حج', icon: Icons.mosque_rounded, selected: tripType == 'hajj',
                  gold: gold, cardColor: cardColor, textColor: textColor, onTap: () => onTripTypeChanged('hajj'))),
              const SizedBox(width: 12),
              Expanded(child: _TripTypeBtn(label: 'عمرة', icon: Icons.loop_rounded, selected: tripType == 'umrah',
                  gold: gold, cardColor: cardColor, textColor: textColor, onTap: () => onTripTypeChanged('umrah'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _TripTypeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color gold;
  final Color cardColor;
  final Color textColor;
  final VoidCallback onTap;
  const _TripTypeBtn({required this.label, required this.icon, required this.selected,
      required this.gold, required this.cardColor, required this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? gold.withOpacity(.15) : cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? gold : gold.withOpacity(.2), width: selected ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? gold : textColor.withOpacity(.5), size: 28),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: selected ? gold : textColor, fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
      ),
    );
  }
}
