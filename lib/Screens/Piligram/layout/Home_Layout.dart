import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_islamic_icons/flutter_islamic_icons.dart';
import 'package:geolocator/geolocator.dart';

import '../../../bloc/cubit.dart';
import '../../../bloc/states.dart';
import '../../../generated/l10n.dart';
import '../../../locale_controller.dart';
import '../../../shared/network/local/cash_helper.dart';

class AppHomeLayout extends StatefulWidget {
  const AppHomeLayout({super.key});

  @override
  State<AppHomeLayout> createState() => _AppHomeLayoutState();
}

class _AppHomeLayoutState extends State<AppHomeLayout> with WidgetsBindingObserver {
  bool _autoLocationEnabled = true;
  bool _locationServiceEnabled = false;
  bool _hasPermission = false;
  bool _isLoadingGps = true;

  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;

  bool get _isGpsReady => kIsWeb ? true : (_autoLocationEnabled && _locationServiceEnabled && _hasPermission);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (kIsWeb) {
      _isLoadingGps = false;
      _locationServiceEnabled = true;
      _hasPermission = true;
    } else {
      _loadLocationState();
      _listenToServiceChanges();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!kIsWeb) {
        await _tryAutoStartLocationFlow();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      _loadLocationState();
    }
  }

  Future<void> _tryAutoStartLocationFlow() async {
    if (kIsWeb) return;

    final cachedAuto = CashHelper.getCash(key: 'auto_location_enabled');
    final shouldAutoStart = cachedAuto is bool ? cachedAuto : true;

    if (!shouldAutoStart) {
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();

    final hasPermission =
        permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse;

    if (serviceEnabled && hasPermission) {
      if (!mounted) return;
      setState(() {
        _autoLocationEnabled = true;
        _locationServiceEnabled = true;
        _hasPermission = true;
        _isLoadingGps = false;
      });
      return;
    }

    if (!mounted) return;
    await _startPermissionFlow();
  }

  Future<void> _loadLocationState() async {
    if (kIsWeb) return;

    final cachedAuto = CashHelper.getCash(key: 'auto_location_enabled');
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();

    if (!mounted) return;

    setState(() {
      _autoLocationEnabled = cachedAuto is bool ? cachedAuto : true;
      _locationServiceEnabled = serviceEnabled;
      _hasPermission =
          permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse;
      _isLoadingGps = false;
    });
  }

  void _listenToServiceChanges() {
    if (kIsWeb) return;

    _serviceStatusSubscription =
        Geolocator.getServiceStatusStream().listen((status) async {
          final serviceEnabled = status == ServiceStatus.enabled;
          final permission = await Geolocator.checkPermission();

          if (!mounted) return;

          setState(() {
            _locationServiceEnabled = serviceEnabled;
            _hasPermission =
                permission == LocationPermission.always ||
                    permission == LocationPermission.whileInUse;
          });
        });
  }

  Future<void> _onGpsTap() async {
    if (kIsWeb) return;

    HapticFeedback.lightImpact();

    if (_isLoadingGps) return;

    if (_isGpsReady) {
      await _showDisableLocationDialog();
      return;
    }

    await _startPermissionFlow();
  }

  Future<void> _startPermissionFlow() async {
    if (kIsWeb) return;
    final s = S.of(context);

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      final openSettings = await _showActionDialog(
        title: s.gpsEnableTitle,
        message: s.gpsEnableMessage,
        confirmText: s.gpsEnableAction,
        cancelText: s.commonCancel,
        isDestructive: false,
      );

      if (openSettings == true) {
        await Geolocator.openLocationSettings();
      }

      await _loadLocationState();
      return;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      if (!mounted) return;
      final allow = await _showActionDialog(
        title: s.gpsPermissionTitle,
        message: s.gpsPermissionMessage,
        confirmText: s.gpsPermissionAction,
        cancelText: s.commonCancel,
        isDestructive: false,
      );

      if (allow != true) {
        return;
      }

      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        await _showInfoDialog(
          title: s.gpsPermissionDeniedTitle,
          message: s.gpsPermissionDeniedMessage,
        );
        await _loadLocationState();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      final openAppSettings = await _showActionDialog(
        title: s.gpsPermissionDeniedForeverTitle,
        message: s.gpsPermissionDeniedForeverMessage,
        confirmText: s.gpsOpenAppSettings,
        cancelText: s.commonCancel,
        isDestructive: false,
      );

      if (openAppSettings == true) {
        await Geolocator.openAppSettings();
      }

      await _loadLocationState();
      return;
    }

    await CashHelper.saveCash(key: 'auto_location_enabled', value: true);

    if (!mounted) return;

    setState(() {
      _autoLocationEnabled = true;
    });

    await _loadLocationState();

    if (!mounted) return;

    await _showInfoDialog(
      title: s.gpsReadyTitle,
      message: s.gpsReadyMessage,
    );
  }

  Future<void> _showDisableLocationDialog() async {
    final s = S.of(context);

    final confirmed = await _showActionDialog(
      title: s.gpsDisableTitle,
      message: s.gpsDisableMessage,
      confirmText: s.gpsDisableAction,
      cancelText: s.commonCancel,
      isDestructive: true,
    );

    if (confirmed == true) {
      await CashHelper.saveCash(key: 'auto_location_enabled', value: false);

      if (!mounted) return;

      setState(() {
        _autoLocationEnabled = false;
      });
    }
  }

  Future<bool?> _showActionDialog({
    required String title,
    required String message,
    required String confirmText,
    required String cancelText,
    required bool isDestructive,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _HomeLayoutPalette.fromBrightness(isDark);

    final accent = isDestructive ? palette.danger : palette.gold;
    final accent2 = isDestructive ? const Color(0xFFCC4B47) : palette.gold2;

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
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
                color: accent.withOpacity(.28),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow.withOpacity(.18),
                  blurRadius: 28,
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
                        accent.withOpacity(.22),
                        accent2.withOpacity(.10),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: accent.withOpacity(.35),
                      width: 1.4,
                    ),
                  ),
                  child: Icon(
                    isDestructive ? Icons.location_off_rounded : Icons.location_on_rounded,
                    color: accent,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'AlamirBold',
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _DialogSecondaryButton(
                        text: cancelText,
                        palette: palette,
                        onTap: () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogPrimaryButton(
                        text: confirmText,
                        color1: accent,
                        color2: accent2,
                        onTap: () => Navigator.pop(context, true),
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

  Future<void> _showInfoDialog({
    required String title,
    required String message,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _HomeLayoutPalette.fromBrightness(isDark);

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
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
                color: palette.gold.withOpacity(.24),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow.withOpacity(.18),
                  blurRadius: 28,
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
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: palette.gold.withOpacity(.35),
                      width: 1.4,
                    ),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: palette.gold,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'AlamirBold',
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: _DialogPrimaryButton(
                    text: S.of(context).commonDone,
                    color1: palette.gold,
                    color2: palette.gold2,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _HomeLayoutPalette.fromBrightness(isDark);

    return BlocConsumer<AppCubit, AppState>(
      listener: (context, state) {},
      builder: (context, state) {
        final cubit = AppCubit.get(context);

        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: palette.bg,
            extendBody: false,
            appBar: _HomeTopBar(
              palette: palette,
              onLanguageTap: LocaleController.toggle,
              onGpsTap: _onGpsTap,
              isGpsReady: _isGpsReady,
              isLoading: _isLoadingGps,
            ),
            body: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -0.10),
                        radius: 0.95,
                        colors: [
                          palette.gold.withOpacity(.10),
                          palette.bg.withOpacity(.0),
                          palette.bg,
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
            bottomNavigationBar: _FixedBottomNav(
              palette: palette,
              currentIndex: cubit.currentScreen,
              onTap: cubit.changeScreen,
            ),
          ),
        );
      },
    );
  }
}

// الكود الباقي (Palette و TopBar و BottomNav والـ Buttons) يبقى كما هو من كودك الأصلي..
// تأكد من نسخهم بالكامل أسفل الكود أعلاه

class _HomeLayoutPalette {
  final Color bg;
  final Color card;
  final Color gold;
  final Color gold2;
  final Color muted;
  final Color textPrimary;
  final Color textSecondary;
  final Color navBg;
  final Color shadow;
  final Color danger;

  const _HomeLayoutPalette({
    required this.bg,
    required this.card,
    required this.gold,
    required this.gold2,
    required this.muted,
    required this.textPrimary,
    required this.textSecondary,
    required this.navBg,
    required this.shadow,
    required this.danger,
  });

  factory _HomeLayoutPalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _HomeLayoutPalette(
        bg: Color(0xFF0B0D10),
        card: Color(0xFF303030),
        gold: Color(0xFFD4AF37),
        gold2: Color(0xFFB98B2E),
        muted: Color(0xFF9AA4B2),
        textPrimary: Colors.white,
        textSecondary: Color(0xFFCBD5E1),
        navBg: Color(0xFF303030),
        shadow: Colors.black,
        danger: Color(0xFFE46D6A),
      );
    }

    return const _HomeLayoutPalette(
      bg: Color(0xFFF7F7F8),
      card: Colors.white,
      gold: Color(0xFFD4AF37),
      gold2: Color(0xFFB98B2E),
      muted: Color(0xFF667085),
      textPrimary: Color(0xFF121316),
      textSecondary: Color(0xFF475467),
      navBg: Colors.white,
      shadow: Color(0x22000000),
      danger: Color(0xFFE46D6A),
    );
  }
}

class _HomeTopBar extends StatelessWidget implements PreferredSizeWidget {
  final _HomeLayoutPalette palette;
  final VoidCallback onLanguageTap;
  final VoidCallback onGpsTap;
  final bool isGpsReady;
  final bool isLoading;

  const _HomeTopBar({
    required this.palette,
    required this.onLanguageTap,
    required this.onGpsTap,
    required this.isGpsReady,
    required this.isLoading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';
    final s = S.of(context);

    return AppBar(
      backgroundColor: palette.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 76,
      automaticallyImplyLeading: false,
      title: Text(
        s.appTitle,
        style: TextStyle(
          color: palette.gold,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: Row(
            children: [
              _GpsStatusButton(
                palette: palette,
                isActive: isGpsReady,
                isLoading: isLoading,
                onTap: onGpsTap,
              ),
              const SizedBox(width: 8),
              _LangPill(
                palette: palette,
                label: isAr ? s.langEnglish : s.langArabic,
                onTap: onLanguageTap,
              ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: palette.gold2.withOpacity(.08),
        ),
      ),
    );
  }
}

class _GpsStatusButton extends StatelessWidget {
  final _HomeLayoutPalette palette;
  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;

  const _GpsStatusButton({
    required this.palette,
    required this.isActive,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF38C793);
    final inactiveColor = palette.danger;
    final ringColor = isActive ? activeColor : inactiveColor;
    final fillColor = ringColor.withOpacity(.14);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fillColor,
            border: Border.all(
              color: ringColor.withOpacity(.95),
              width: 2.2,
            ),
            boxShadow: [
              BoxShadow(
                color: ringColor.withOpacity(.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(ringColor),
              ),
            )
                : Icon(
              isActive ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
              size: 24,
              color: ringColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  final _HomeLayoutPalette palette;
  final String label;
  final VoidCallback onTap;

  const _LangPill({
    required this.palette,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: palette.bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: palette.gold.withOpacity(.65),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.gold.withOpacity(.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: palette.gold,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _FixedBottomNav extends StatelessWidget {
  final _HomeLayoutPalette palette;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FixedBottomNav({
    required this.palette,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.navBg,
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withOpacity(.12),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: palette.gold.withOpacity(.10),
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        height: 88,
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: palette.navBg,
          elevation: 0,
          iconSize: 26,
          selectedItemColor: palette.gold,
          unselectedItemColor: palette.muted,
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
                child: Icon(Icons.home_rounded),
              ),
              label: s.navHome,
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(Icons.map_rounded),
              ),
              label: s.navMap,
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(Icons.menu_book_rounded),
              ),
              label: s.navDuas,
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(FlutterIslamicIcons.solidTasbih3),
              ),
              label: s.navTasbih,
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(Icons.settings_rounded),
              ),
              label: s.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogPrimaryButton extends StatelessWidget {
  final String text;
  final Color color1;
  final Color color2;
  final VoidCallback onTap;

  const _DialogPrimaryButton({
    required this.text,
    required this.color1,
    required this.color2,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color1, color2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color1.withOpacity(.18),
              blurRadius: 20,
              offset: const Offset(0, 10),
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
                  color: Color(0xFF14171C),
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

class _DialogSecondaryButton extends StatelessWidget {
  final String text;
  final _HomeLayoutPalette palette;
  final VoidCallback onTap;

  const _DialogSecondaryButton({
    required this.text,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Material(
        color: palette.bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: palette.gold.withOpacity(.18),
                width: 1.1,
              ),
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}