import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // للتحكم بالاهتزاز الحسّي التفاعلي
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../admin_bloc/admin_cubit.dart';
import '../../../admin_bloc/admin_states.dart';
import '../../../generated/l10n.dart';
import '../../../locale_controller.dart';
import '../../../theme/dhakker_theme.dart';

class AdminHomeLayout extends StatefulWidget {
  const AdminHomeLayout({super.key});

  @override
  State<AdminHomeLayout> createState() => _AdminHomeLayoutState();
}

class _AdminHomeLayoutState extends State<AdminHomeLayout> {
  // وحدة تحكم لربط حركة التبويبات بالـ PageView الناعم بسلايد فيزياء الـ iOS
  late PageController _adminPageController;

  @override
  void initState() {
    super.initState();
    // تهيئة الـ Controller بناءً على الشاشة الحالية المعتمدة بالـ Cubit فوراً
    _adminPageController = PageController(initialPage: AdminCubit.get(context).currentScreen);
  }

  @override
  void dispose() {
    _adminPageController.dispose(); // تنظيف الذاكرة لمنع تسريبها
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;

    return BlocConsumer<AdminCubit, AdminState>(
      listener: (context, state) {
        // الحفاظ على تزامن الـ PageController إذا تم تغيير الشاشة خارجياً من داخل كود الشاشات
        if (AdminCubit.get(context).currentScreen != _adminPageController.page?.round()) {
          _adminPageController.jumpToPage(AdminCubit.get(context).currentScreen);
        }
      },
      builder: (context, state) {
        final cubit = AdminCubit.get(context);

        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: Material(
            color: bg,
            child: Scaffold(
              backgroundColor: bg,
              extendBody: false,
              appBar: _AdminTopBar(
                onLanguageTap: LocaleController.toggle,
                isAr: isAr,
                currentScreen: cubit.currentScreen,
              ),
              body: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.0, -0.10),
                          radius: 0.95,
                          colors: isDark
                              ? [
                            DhakkerColors.gold.withOpacity(.10),
                            DhakkerColors.bg.withOpacity(.0),
                            DhakkerColors.bg,
                          ]
                              : [
                            DhakkerColors.gold.withOpacity(.10),
                            DhakkerColors.lightBg.withOpacity(.0),
                            DhakkerColors.lightBg,
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // استبدال الوجت الجامد القديم بـ PageView لمنح تجربة سحب هيدروليكية بالكامل للأدمن
                  PageView.builder(
                    controller: _adminPageController,
                    physics: const BouncingScrollPhysics(), // فيزياء ارتداد وتمطيط ناعمة تريح اليد
                    itemCount: cubit.screens.length,
                    onPageChanged: (index) {
                      cubit.changeScreen(index);
                    },
                    itemBuilder: (context, index) {
                      return cubit.screens[index];
                    },
                  ),
                ],
              ),
              bottomNavigationBar: _AdminBottomNav(
                currentIndex: cubit.currentScreen,
                onTap: (index) {
                  // انتقال حركي أنيق ومريح للعين عند نقر تبويبات الأدمن بالأسفل
                  _adminPageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOutCubic, // منحنى فخم متناسق مع حركات المنظومة الذكية
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AdminTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onLanguageTap;
  final bool isAr;
  final int currentScreen;

  const _AdminTopBar({
    required this.onLanguageTap,
    required this.isAr,
    required this.currentScreen,
  });

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final cubit = AdminCubit.get(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    const titleColor = DhakkerColors.gold;
    final lineColor = isDark ? DhakkerColors.gold.withOpacity(.06) : const Color(0xFFE6E8EC);

    return AppBar(
      backgroundColor: bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 76,
      automaticallyImplyLeading: false,
      title: Text(
        isAr ? cubit.screenAr[currentScreen] : cubit.screenEn[currentScreen],
        style: const TextStyle(
          color: titleColor,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _LangPill(
            label: isAr ? "EN" : "AR",
            onTap: onLanguageTap,
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: lineColor),
      ),
    );
  }
}

// تلغيم كبس زر اللغة بالأدمن بالتأثير المطاطي والاهتزاز الحسّي
class _LangPill extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _LangPill({required this.label, required this.onTap});

  @override
  State<_LangPill> createState() => _LangPillState();
}

class _LangPillState extends State<_LangPill> {
  double _pillScale = 1.0;

  @override
  Widget build(BuildContext context) {
    const text = DhakkerColors.gold;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pillScale = 0.94),
      onTapUp: (_) {
        setState(() => _pillScale = 1.0);
        HapticFeedback.lightImpact(); // نبضة حسية ناعمة مع كبس الحبة
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pillScale = 1.0),
      child: AnimatedScale(
        scale: _pillScale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: text.withOpacity(.5)),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(color: text, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _AdminBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AdminBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final navBg = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    const selected = DhakkerColors.gold;

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: navBg,
      selectedItemColor: selected,
      unselectedItemColor: Colors.grey,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.dashboard_rounded),
          label: s.adminNavDashboard,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.location_on_rounded),
          label: s.adminNavZones,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.menu_book_rounded),
          label: s.adminNavSupplications,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.settings_rounded),
          label: s.adminNavSettings,
        ),
      ],
    );
  }
}