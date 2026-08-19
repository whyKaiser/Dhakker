import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';

import '../../../generated/l10n.dart';
import '../../../locale_controller.dart';
import '../../../shared/network/local/cash_helper.dart';
import '../../../theme/dhakker_theme.dart';
import '../../../theme_controller.dart';
import '../../auth/splash_screen.dart';

// --- السطر المصلح (تأكد أن اسم الملف مطابق لما عندك) ---
import '../SOS/admin_sos_monitor_screen.dart';
import '../Alerts/admin_alerts_screen.dart';
import '../Crowd/admin_crowd_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  static const String _darkModeKey = 'dark_mode_enabled';

  bool _isLoading = true;
  bool _darkMode = true;
  String _sosPhone = ''; // رقم طوارئ SOS الحالي من config/sos

  @override
  void initState() {
    super.initState();
    _loadThemeState();
    _loadSosPhone();
  }

  Future<void> _loadSosPhone() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('sos')
          .get();
      final phone = doc.data()?['whatsappPhone']?.toString() ?? '';
      if (mounted) setState(() => _sosPhone = phone);
    } catch (_) {/* تجاهل: يظل فارغاً */}
  }

  Future<void> _editSosPhone() async {
    final controller = TextEditingController(text: _sosPhone);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final textColor = isDark ? Colors.white : DhakkerColors.lightText;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isAr ? 'رقم طوارئ SOS' : 'SOS Emergency Number',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                isAr
                    ? 'الرقم الذي يُرسل إليه موقع الحاج عند الاستغاثة (بصيغة دولية مثل +9665XXXXXXXX).'
                    : 'The number that receives the pilgrim\'s location on SOS (international format, e.g. +9665XXXXXXXX).',
                textAlign: TextAlign.center,
                style: const TextStyle(color: DhakkerColors.muted, fontSize: 12.5, height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: '+9665XXXXXXXX',
                  prefixIcon: Icon(Icons.phone_in_talk_rounded, color: DhakkerColors.gold),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(isAr ? 'إلغاء' : 'Cancel',
                          style: const TextStyle(color: DhakkerColors.muted, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DhakkerColors.gold,
                        foregroundColor: DhakkerColors.darkText,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                      child: Text(isAr ? 'حفظ' : 'Save',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;

    try {
      await FirebaseFirestore.instance.collection('config').doc('sos').set(
        {'whatsappPhone': result},
        SetOptions(merge: true),
      );
      if (!mounted) return;
      setState(() => _sosPhone = result);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF2E7D32),
        content: Text(isAr ? 'تم حفظ رقم الطوارئ' : 'Emergency number saved'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFFCC4B47),
        content: Text(isAr ? 'تعذّر الحفظ، حاول مجدداً' : 'Could not save, try again'),
      ));
    }
  }

  Future<void> _loadThemeState() async {
    final savedDarkMode = CashHelper.getCash(key: _darkModeKey);
    final resolvedDarkMode = savedDarkMode is bool ? savedDarkMode : true;

    ThemeController.setTheme(resolvedDarkMode);

    if (!mounted) return;

    setState(() {
      _darkMode = resolvedDarkMode;
      _isLoading = false;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    setState(() {
      _darkMode = value;
    });

    ThemeController.setTheme(value);

    await CashHelper.saveCash(
      key: _darkModeKey,
      value: value,
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;


    CashHelper.removeCash(key: 'uid');
    CashHelper.removeCash(key: 'userTypeIndex');


    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) =>  const SplashScreen(0)),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final textColor = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Container(
      color: bg,
      child: SafeArea(
        bottom: false,
        child: _isLoading
            ? Center(
          child: CircularProgressIndicator(
            color: isDark ? DhakkerColors.gold : DhakkerColors.gold2,
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),

              // --- 1. كرت اللغة ---
              _SettingCard(
                cardColor: card,
                shadowDark: isDark,
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment:
                          isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.adminSettingsLanguage,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              s.adminSettingsLanguageHint,
                              style: TextStyle(
                                color: muted.withOpacity(.95),
                                fontSize: 12.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    _PillButton(
                      label: Localizations.localeOf(context).languageCode == 'ar'
                          ? s.langEnglish
                          : s.langArabic,
                      onTap: LocaleController.toggle,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // --- 2. كرت لوحة الإحصائيات الذكية ---
              _SettingCard(
                cardColor: card,
                shadowDark: isDark,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminSosMonitorScreen()),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: DhakkerColors.gold.withOpacity(.12),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: DhakkerColors.gold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Align(
                          alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr ? "مراقبة نداءات SOS" : "SOS Monitor",
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isAr ? "متابعة حالات الاستغاثة ومواقعها" : "Track emergency alerts & locations",
                                style: TextStyle(
                                  color: muted.withOpacity(.95),
                                  fontSize: 12.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 15,
                        color: DhakkerColors.gold,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // --- 2.1 كرت لوحة الازدحام اللحظية ---
              _SettingCard(
                cardColor: card,
                shadowDark: isDark,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminCrowdScreen()),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: DhakkerColors.gold.withOpacity(.12),
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: DhakkerColors.gold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Align(
                          alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr ? "الازدحام اللحظي" : "Live Crowd",
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isAr ? "عدد الحجّاج في كل منطقة الآن" : "Pilgrims per zone right now",
                                style: TextStyle(
                                  color: muted.withOpacity(.95),
                                  fontSize: 12.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 15,
                        color: DhakkerColors.gold,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // --- 2.2 كرت بثّ التنبيهات للحجّاج ---
              _SettingCard(
                cardColor: card,
                shadowDark: isDark,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminAlertsScreen()),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: DhakkerColors.gold.withOpacity(.12),
                        ),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: DhakkerColors.gold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Align(
                          alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr ? "تنبيهات الحجّاج" : "Pilgrim Alerts",
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isAr ? "إرسال تنبيهات تظهر لكل الحجّاج" : "Broadcast alerts to all pilgrims",
                                style: TextStyle(
                                  color: muted.withOpacity(.95),
                                  fontSize: 12.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 15,
                        color: DhakkerColors.gold,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // --- 2.5 كرت رقم طوارئ SOS ---
              _SettingCard(
                cardColor: card,
                shadowDark: isDark,
                child: InkWell(
                  onTap: _editSosPhone,
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: DhakkerColors.gold.withOpacity(.12),
                        ),
                        child: const Icon(
                          Icons.phone_in_talk_rounded,
                          color: DhakkerColors.gold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Align(
                          alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr ? "رقم طوارئ SOS" : "SOS Emergency Number",
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _sosPhone.isEmpty
                                    ? (isAr ? "غير محدّد — اضغط للتعيين" : "Not set — tap to set")
                                    : _sosPhone,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  color: muted.withOpacity(.95),
                                  fontSize: 12.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: DhakkerColors.gold,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // --- 3. كرت الثيم ---
              _SettingCard(
                cardColor: card,
                shadowDark: isDark,
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment:
                          isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.adminSettingsTheme,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _darkMode
                                  ? s.adminSettingsThemeDark
                                  : s.adminSettingsThemeLight,
                              style: TextStyle(
                                color: muted.withOpacity(.95),
                                fontSize: 12.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    FlutterSwitch(
                      value: _darkMode,
                      onToggle: _toggleTheme,
                      height: 36,
                      width: 72,
                      toggleSize: 30,
                      borderRadius: 40,
                      padding: 4,
                      activeColor: DhakkerColors.gold,
                      inactiveColor: (isDark ? Colors.white : Colors.black).withOpacity(.12),
                      toggleColor: Colors.white,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- 4. زر الخروج ---
              _LogoutButton(
                text: s.adminSettingsLogout,
                onTap: _logout,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// الكلاسات والويدجت المساعدة (الـ 300 سطر الباقية)
// ==========================================

class _SettingCard extends StatelessWidget {
  final Widget child;
  final Color cardColor;
  final bool shadowDark;

  const _SettingCard({
    required this.child,
    required this.cardColor,
    required this.shadowDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(shadowDark ? .35 : .08),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
        border: Border.all(
          color: (shadowDark ? Colors.white : Colors.black).withOpacity(
            shadowDark ? .06 : .05,
          ),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _PillButton({
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightCard;
    final border = isDark
        ? DhakkerColors.gold.withOpacity(.65)
        : DhakkerColors.gold2.withOpacity(.55);
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

class _LogoutButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isDark;

  const _LogoutButton({
    required this.text,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    const border = Color(0xFFEF4444);

    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border.withOpacity(.65), width: 1.3),
          boxShadow: [
            BoxShadow(
              color: border.withOpacity(isDark ? .12 : .10),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Center(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}