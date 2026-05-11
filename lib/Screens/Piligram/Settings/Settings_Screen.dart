import 'package:dhakker/Screens/auth/Splash_Screen.dart';
import 'package:dhakker/theme_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // أضفنا البلوك

import '../../../generated/l10n.dart';
import '../../../shared/network/local/cash_helper.dart';
import '../../auth/Login_Screen.dart';
import '../../../bloc/cubit.dart'; // تأكد من المسار
import '../../../bloc/states.dart'; // تأكد من المسار


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _voiceKey = 'voice_notifications_enabled';
  static const String _autoLocationKey = 'auto_location_enabled';
  static const String _darkModeKey = 'dark_mode_enabled';

  bool _voiceNotifications = true;
  bool _autoLocation = true;
  bool _darkMode = true;
  bool _isLoading = true;
  bool _isBusy = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final voiceValue = CashHelper.getCash(key: _voiceKey);
    final autoLocationValue = CashHelper.getCash(key: _autoLocationKey);
    final darkModeValue = CashHelper.getCash(key: _darkModeKey);

    final resolvedDarkMode = darkModeValue is bool ? darkModeValue : true;

    ThemeController.setTheme(resolvedDarkMode);

    if (!mounted) return;

    setState(() {
      _voiceNotifications = voiceValue is bool ? voiceValue : true;
      _autoLocation = autoLocationValue is bool ? autoLocationValue : true;
      _darkMode = resolvedDarkMode;
      _isLoading = false;
    });
  }

  Future<void> _toggleVoiceNotifications(bool value) async {
    setState(() {
      _voiceNotifications = value;
    });

    await CashHelper.saveCash(
      key: _voiceKey,
      value: value,
    );
  }

  Future<void> _toggleAutoLocation(bool value) async {
    setState(() {
      _autoLocation = value;
    });

    await CashHelper.saveCash(
      key: _autoLocationKey,
      value: value,
    );
  }

  Future<void> _toggleDarkMode(bool value) async {
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
    final s = S.of(context);

    setState(() {
      _isBusy = true;
    });

    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      CashHelper.removeCash(key: 'uid');
      CashHelper.removeCash(key: 'userTypeIndex');
      CashHelper.removeCash(key: 'voice_notifications_enabled');
      CashHelper.removeCash(key: 'auto_location_enabled');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) =>  SplashScreen(0)),
            (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(s.settingsLogoutFailed);
    } finally {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _SettingsPalette.fromBrightness(isDark);

    return BlocBuilder<AppCubit, AppState>(
      builder: (context, state) {
        var cubit = AppCubit.get(context);

        return Container(
          color: palette.bg,
          child: SafeArea(
            bottom: false,
            child: _isLoading
                ? Center(
              child: CircularProgressIndicator(
                color: palette.gold,
              ),
            )
                : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      s.settingsTitle,
                      style: TextStyle(
                        color: palette.gold,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'AlamirBold',
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 1,
                    color: palette.divider.withOpacity(.16),
                  ),
                  const SizedBox(height: 18),

                  // --- قسم خدمات الطوارئ ---
                  _ActionTile(
                    title: "نداء استغاثة (SOS)",
                    subtitle: "إرسال موقعك الحالي عبر الواتساب للمساعدة",
                    icon: Icons.emergency_share,
                    palette: palette,
                    isDanger: true,
                    onTap: () => cubit.sendSOS(),
                  ),
                  const SizedBox(height: 14),

                  // --- قسم إعدادات الطواف ---
                  _ActionTile(
                    title: "إعادة ضبط الأشواط",
                    subtitle: "تصفير عداد الأشواط الحالي لبدء طواف جديد",
                    icon: Icons.refresh_rounded,
                    palette: palette,
                    onTap: () => cubit.resetLaps(),
                  ),
                  const SizedBox(height: 24),

                  // --- الإعدادات العامة ---
                  _SettingTile(
                    title: s.settingsSound,
                    subtitle: s.settingsSoundSubtitle,
                    value: _voiceNotifications,
                    onChanged: _voiceNotifications ? (v) => _toggleVoiceNotifications(v) : (v) => _toggleVoiceNotifications(v), // للتوضيح فقط
                    isAr: isAr,
                    palette: palette,
                    onToggle: _toggleVoiceNotifications,
                  ),
                  const SizedBox(height: 14),
                  _SettingTile(
                    title: s.settingsAutoLocation,
                    subtitle: s.settingsAutoLocationSubtitle,
                    value: _autoLocation,
                    onChanged: _toggleAutoLocation,
                    isAr: isAr,
                    palette: palette,
                    onToggle: _toggleAutoLocation,
                  ),
                  const SizedBox(height: 14),
                  _SettingTile(
                    title: s.settingsNightMode,
                    subtitle: s.settingsNightModeSubtitle,
                    value: _darkMode,
                    onChanged: _toggleDarkMode,
                    isAr: isAr,
                    palette: palette,
                    onToggle: _toggleDarkMode,
                  ),
                  const SizedBox(height: 14),
                  _ActionTile(
                    title: s.settingsLogout,
                    subtitle: s.settingsLogoutSubtitle,
                    icon: Icons.logout_rounded,
                    palette: palette,
                    isDanger: true,
                    onTap: _isBusy ? null : () => _logout(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- بقية الكلاسات المساعدة (Tiles & Palette) بنفس تصميمك ---

class _SettingsPalette {
  final Color bg, gold, gold2, muted, card, textPrimary, textSecondary, border, divider, shadow, danger;

  const _SettingsPalette({
    required this.bg, required this.gold, required this.gold2, required this.muted,
    required this.card, required this.textPrimary, required this.textSecondary,
    required this.border, required this.divider, required this.shadow, required this.danger,
  });

  factory _SettingsPalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _SettingsPalette(
        bg: Color(0xFF0B0D10), gold: Color(0xFFD4AF37), gold2: Color(0xFFB98B2E),
        muted: Color(0xFF9AA4B2), card: Color(0xFF303030), textPrimary: Colors.white,
        textSecondary: Color(0xFFCBD5E1), border: Color(0xFF1B1F26), divider: Colors.white,
        shadow: Colors.black, danger: Color(0xFFE46D6A),
      );
    }
    return const _SettingsPalette(
      bg: Color(0xFFF7F7F8), gold: Color(0xFFD4AF37), gold2: Color(0xFFB98B2E),
      muted: Color(0xFF667085), card: Colors.white, textPrimary: Color(0xFF121316),
      textSecondary: Color(0xFF475467), border: Color(0xFFE5E7EB), divider: Color(0xFF121316),
      shadow: Color(0x22000000), danger: Color(0xFFE46D6A),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onToggle;
  final bool isAr;
  final _SettingsPalette palette;

  const _SettingTile({
    required this.title, required this.subtitle, required this.value,
    required this.onToggle, required this.isAr, required this.palette,
    required ValueChanged<bool> onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card, borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border.withOpacity(.95)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: palette.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          FlutterSwitch(
            value: value, onToggle: onToggle, height: 32, width: 64, toggleSize: 26,
            activeColor: palette.gold, inactiveColor: palette.muted.withOpacity(.35),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final _SettingsPalette palette;
  final VoidCallback? onTap;
  final bool isDanger;

  const _ActionTile({
    required this.title, required this.subtitle, required this.icon,
    required this.palette, required this.onTap, this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDanger ? palette.danger : palette.gold;
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withOpacity(.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}