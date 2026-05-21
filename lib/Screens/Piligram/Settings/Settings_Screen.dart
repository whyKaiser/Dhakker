import 'package:dhakker/Screens/auth/Splash_Screen.dart';
import 'package:dhakker/theme_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // استدعاء حزمة الاهتزاز الحسّي بالملي
import 'package:flutter_switch/flutter_switch.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../generated/l10n.dart';
import '../../../shared/network/local/cash_helper.dart';
import '../../auth/Login_Screen.dart';
import '../../../bloc/cubit.dart';
import '../../../bloc/states.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  static const String _voiceKey = 'voice_notifications_enabled';
  static const String _autoLocationKey = 'auto_location_enabled';
  static const String _darkModeKey = 'dark_mode_enabled';

  bool _voiceNotifications = true;
  bool _autoLocation = true;
  bool _darkMode = true;
  bool _isLoading = true;
  bool _isBusy = false;

  // وحدة تحكم لأنميشن الدخول المتتابع لعناصر القائمة
  late AnimationController _listAnimationController;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
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

    // تشغيل أنميشن الدخول المتتابع للعناصر فور انتهاء التحميل
    _listAnimationController.forward();
  }

  Future<void> _toggleVoiceNotifications(bool value) async {
    HapticFeedback.lightImpact(); // نبضة ناعمة مع السويتش
    setState(() {
      _voiceNotifications = value;
    });

    await CashHelper.saveCash(
      key: _voiceKey,
      value: value,
    );
  }

  Future<void> _toggleAutoLocation(bool value) async {
    HapticFeedback.lightImpact(); // نبضة ناعمة مع السويتش
    setState(() {
      _autoLocation = value;
    });

    await CashHelper.saveCash(
      key: _autoLocationKey,
      value: value,
    );
  }

  Future<void> _toggleDarkMode(bool value) async {
    HapticFeedback.lightImpact(); // نبضة ناعمة مع السويتش
    setState(() {
      _darkMode = value;
    });

    ThemeController.setTheme(value);

    await CashHelper.saveCash(
      key: _darkModeKey,
      value: value,
    );
  }

  Future<void> _showResetPasswordDialog() async {
    final s = S.of(context);
    final palette = _SettingsPalette.fromBrightness(
      Theme.of(context).brightness == Brightness.dark,
    );

    final email = _user?.email ?? s.settingsNoEmail;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: palette.gold.withOpacity(.20),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow.withOpacity(.18),
                  blurRadius: 26,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        palette.gold.withOpacity(.22),
                        palette.gold2.withOpacity(.10),
                      ],
                    ),
                    border: Border.all(
                      color: palette.gold.withOpacity(.30),
                    ),
                  ),
                  child: Icon(
                    Icons.lock_reset_rounded,
                    color: palette.gold,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  s.settingsResetPasswordTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'AlamirBold',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s.settingsResetPasswordMessage(email),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _SettingsDialogButton(
                        text: s.commonCancel,
                        isPrimary: false,
                        palette: palette,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SettingsDialogButton(
                        text: s.settingsSendResetLink,
                        isPrimary: true,
                        palette: palette,
                        onTap: () async {
                          Navigator.pop(context);
                          await _sendResetPasswordEmail();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendResetPasswordEmail() async {
    final s = S.of(context);

    final email = _user?.email;
    if (email == null || email.trim().isEmpty) {
      _showSnackBar(s.settingsNoEmailAvailable);
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());

      if (!mounted) return;
      _showSnackBar(s.settingsResetPasswordSuccess);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message ?? s.settingsResetPasswordFailed);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(s.settingsResetPasswordFailed);
    } finally {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
      });
    }
  }

  Future<void> _showLogoutDialog() async {
    final s = S.of(context);
    final palette = _SettingsPalette.fromBrightness(
      Theme.of(context).brightness == Brightness.dark,
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: palette.danger.withOpacity(.24),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow.withOpacity(.18),
                  blurRadius: 26,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        palette.danger.withOpacity(.22),
                        palette.danger.withOpacity(.08),
                      ],
                    ),
                    border: Border.all(
                      color: palette.danger.withOpacity(.30),
                    ),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: palette.danger,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  s.settingsLogoutTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'AlamirBold',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s.settingsLogoutMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _SettingsDialogButton(
                        text: s.commonCancel,
                        isPrimary: false,
                        palette: palette,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SettingsDialogButton(
                        text: s.settingsLogoutButton,
                        isPrimary: true,
                        palette: palette,
                        primaryColorOverride: palette.danger,
                        secondaryColorOverride: const Color(0xFFCC4B47),
                        onTap: () async {
                          Navigator.pop(context);
                          await _logout();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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

    return BlocBuilder<AppCubit, AppStates>(
      builder: (context, state) {
        final cubit = AppCubit.get(context);

        final List<Widget> listItems = [
          _ActionTile(
            title: isAr ? "نداء استغاثة (SOS)" : "Emergency Call (SOS)",
            subtitle: isAr ? "إرسال موقعك الحالي عبر الواتساب للمساعدة" : "Send current location via WhatsApp",
            icon: Icons.cell_tower_rounded,
            palette: palette,
            isDanger: true,
            onTap: () {
              HapticFeedback.vibrate();
              cubit.sendWhatsAppSOS();
            },
          ),
          const SizedBox(height: 14),
          _ActionTile(
            title: isAr ? "إعادة ضبط الأشواط" : "Reset Rounds",
            subtitle: isAr ? "تصفير عداد الأشواط الحالي لبدء طواف جديد" : "Reset the round counter",
            icon: Icons.refresh_rounded,
            palette: palette,
            onTap: () {
              HapticFeedback.mediumImpact();
              cubit.resetRounds();
              _showSnackBar(isAr ? "تم إعادة تصفير الأشواط بنجاح" : "Rounds reset successfully");
            },
          ),
          const SizedBox(height: 14),
          _SettingTile(
            title: s.settingsSound,
            subtitle: s.settingsSoundSubtitle,
            value: _voiceNotifications,
            onChanged: _toggleVoiceNotifications,
            isAr: isAr,
            palette: palette,
          ),
          const SizedBox(height: 14),
          _SettingTile(
            title: s.settingsAutoLocation,
            subtitle: s.settingsAutoLocationSubtitle,
            value: _autoLocation,
            onChanged: _toggleAutoLocation,
            isAr: isAr,
            palette: palette,
          ),
          const SizedBox(height: 14),
          _SettingTile(
            title: s.settingsNightMode,
            subtitle: s.settingsNightModeSubtitle,
            value: _darkMode,
            onChanged: _toggleDarkMode,
            isAr: isAr,
            palette: palette,
          ),
          const SizedBox(height: 14),
          _ActionTile(
            title: s.settingsResetPassword,
            subtitle: _user?.email ?? s.settingsNoEmail,
            icon: Icons.lock_reset_rounded,
            palette: palette,
            onTap: _isBusy ? null : _showResetPasswordDialog,
          ),
          const SizedBox(height: 14),
          _ActionTile(
            title: s.settingsLogout,
            subtitle: s.settingsLogoutSubtitle,
            icon: Icons.logout_rounded,
            palette: palette,
            isDanger: true,
            onTap: _isBusy ? null : _showLogoutDialog,
          ),
          const SizedBox(height: 24),
        ];

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
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      isAr ? "الإعدادات العامة" : "General Settings",
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

                  ListView.builder(
                    shrinkWrap: true,
                    primary: false,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: listItems.length,
                    itemBuilder: (context, index) {
                      final double start = (index * 0.05).clamp(0.0, 1.0);
                      final double end = (start + 0.35).clamp(0.0, 1.0);

                      return AnimatedBuilder(
                        animation: _listAnimationController,
                        builder: (context, child) {
                          final animationCurve = CurvedAnimation(
                            parent: _listAnimationController,
                            curve: Interval(start, end, curve: Curves.easeOutCubic),
                          );

                          return Transform.translate(
                            offset: Offset(0, 24 * (1.0 - animationCurve.value)),
                            child: Opacity(
                              opacity: animationCurve.value,
                              child: child,
                            ),
                          );
                        },
                        child: listItems[index],
                      );
                    },
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

class _SettingsPalette {
  final Color bg;
  final Color gold;
  final Color gold2;
  final Color muted;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color shadow;
  final Color danger;
  final Color divider;

  const _SettingsPalette({
    required this.bg,
    required this.gold,
    required this.gold2,
    required this.muted,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.shadow,
    required this.danger,
    required this.divider,
  });

  factory _SettingsPalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _SettingsPalette(
        bg: Color(0xFF0B0D10),
        gold: Color(0xFFD4AF37),
        gold2: Color(0xFFB98B2E),
        muted: Color(0xFF9AA4B2),
        card: Color(0xFF303030),
        textPrimary: Colors.white,
        textSecondary: Color(0xFFCBD5E1),
        border: Color(0xFF1B1F26),
        shadow: Colors.black,
        danger: Color(0xFFE46D6A),
        divider: Colors.white,
      );
    }

    return const _SettingsPalette(
      bg: Color(0xFFF7F7F8),
      gold: Color(0xFFD4AF37),
      gold2: Color(0xFFB98B2E),
      muted: Color(0xFF667085),
      card: Colors.white,
      textPrimary: Color(0xFF121316),
      textSecondary: Color(0xFF475467),
      border: Color(0xFFE5E7EB),
      shadow: Color(0x22000000),
      danger: Color(0xFFE46D6A),
      divider: Color(0xFF121316),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isAr;
  final _SettingsPalette palette;

  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isAr,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: palette.border.withOpacity(.95),
        ),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withOpacity(.12),
            blurRadius: 20,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          FlutterSwitch(
            value: value,
            onToggle: onChanged,
            height: 36,
            width: 72,
            toggleSize: 30,
            borderRadius: 40,
            padding: 4,
            activeColor: palette.gold,
            inactiveColor: palette.muted.withOpacity(.35),
            toggleColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final _SettingsPalette palette;
  final VoidCallback? onTap;
  final bool isDanger;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.palette,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final accent = widget.isDanger ? widget.palette.danger : widget.palette.gold;

    return GestureDetector(
      onTapDown: (_) {
        if (widget.onTap != null) {
          setState(() {
            _scale = 0.96;
          });
        }
      },
      onTapUp: (_) {
        if (widget.onTap != null) {
          setState(() {
            _scale = 1.0;
          });
          HapticFeedback.lightImpact();
          widget.onTap!();
        }
      },
      onTapCancel: () {
        setState(() {
          _scale = 1.0;
        });
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: widget.palette.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: (widget.isDanger ? widget.palette.danger : widget.palette.border).withOpacity(.95),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.palette.shadow.withOpacity(.10),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withOpacity(.12),
                ),
                child: Icon(
                  widget.icon,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title, // تم حذف البارامتر المسمّى الخطأ
                      style: TextStyle(
                        color: widget.palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle, // تم حذف البارامتر المسمّى الخطأ
                      style: TextStyle(
                        color: widget.palette.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDialogButton extends StatefulWidget {
  final String text;
  final bool isPrimary;
  final _SettingsPalette palette;
  final VoidCallback onTap;
  final Color? primaryColorOverride;
  final Color? secondaryColorOverride;

  const _SettingsDialogButton({
    required this.text,
    required this.isPrimary,
    required this.palette,
    required this.onTap,
    this.primaryColorOverride,
    this.secondaryColorOverride,
  });

  @override
  State<_SettingsDialogButton> createState() => _SettingsDialogButtonState();
}

class _SettingsDialogButtonState extends State<_SettingsDialogButton> {
  double _buttonScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final primary1 = widget.primaryColorOverride ?? widget.palette.gold;
    final primary2 = widget.secondaryColorOverride ?? widget.palette.gold2;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _buttonScale = 0.95;
        });
      },
      onTapUp: (_) {
        setState(() {
          _buttonScale = 1.0;
        });
        HapticFeedback.lightImpact();
        widget.onTap();
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
        child: SizedBox(
          height: 52,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: widget.isPrimary
                  ? LinearGradient(
                colors: [primary1, primary2],
              )
                  : null,
              color: widget.isPrimary ? null : widget.palette.bg,
              border: Border.all(
                color: widget.isPrimary
                    ? Colors.transparent
                    : widget.palette.gold.withOpacity(.18),
              ),
            ),
            child: Center(
              child: Text(
                widget.text,
                style: TextStyle(
                  color: widget.isPrimary
                      ? const Color(0xFF14171C)
                      : widget.palette.textSecondary,
                  fontSize: 15,
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