import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../admin_bloc/admin_cubit.dart';
import '../../../admin_bloc/admin_states.dart';
import '../../../generated/l10n.dart';
import '../../../locale_controller.dart';
import '../../../theme/dhakker_theme.dart';


class AdminHomeLayout extends StatelessWidget {
  const AdminHomeLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;

    return BlocConsumer<AdminCubit, AdminState>(
      listener: (context, state) {},
      builder: (context, state) {
        final cubit = AdminCubit.get(context);

        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: bg,
            extendBody: false,
            appBar: _AdminTopBar(
              onLanguageTap: LocaleController.toggle,
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
                          DhakkerColors.gold2.withOpacity(.10),
                          DhakkerColors.lightBg.withOpacity(.0),
                          DhakkerColors.lightBg,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey(cubit.currentScreen),
                    child: cubit.screens[cubit.currentScreen],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _AdminBottomNav(
              currentIndex: cubit.currentScreen,
              onTap: cubit.changeScreen,
            ),
          ),
        );
      },
    );
  }
}

class _AdminTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onLanguageTap;

  const _AdminTopBar({required this.onLanguageTap});

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final titleColor = isDark ? DhakkerColors.gold : DhakkerColors.gold2;
    final lineColor = isDark ? DhakkerColors.gold2.withOpacity(.06) : const Color(0xFFE6E8EC);

    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';

    return AppBar(
      backgroundColor: bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 76,
      automaticallyImplyLeading: false,
      title: Text(
        isAr?AdminCubit.get(context).screenAr[AdminCubit.get(context).currentScreen]:AdminCubit.get(context).screenEn[AdminCubit.get(context).currentScreen],
        style: TextStyle(
          color: titleColor,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            children: [
              _LangPill(
                label: isAr ? s.langEnglish : s.langArabic,
                onTap: onLanguageTap,
              ),
            ],
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

class _LangPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LangPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightCard;
    final border = isDark ? DhakkerColors.gold.withOpacity(.65) : DhakkerColors.gold2.withOpacity(.55);
    final text = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: text.withOpacity(.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
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
    final selected = isDark ? DhakkerColors.gold : DhakkerColors.gold2;
    final unselected = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .30 : .08),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: selected.withOpacity(isDark ? .10 : .12),
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        height: 95,
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: navBg,
          elevation: 0,
          iconSize: 26,
          selectedItemColor: selected,
          unselectedItemColor: unselected,
          selectedFontSize: 13,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          items: [
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(Icons.dashboard_rounded),
              ),
              label: s.adminNavDashboard,
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(Icons.location_on_rounded),
              ),
              label: s.adminNavZones,
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(Icons.menu_book_rounded),
              ),
              label: s.adminNavSupplications,
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(Icons.settings_rounded),
              ),
              label: s.adminNavSettings,
            ),
          ],
        ),
      ),
    );
  }
}