import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../bloc/cubit.dart';
import '../../../bloc/states.dart';
import '../../../generated/l10n.dart';
import '../../../locale_controller.dart';
import '../../../shared/network/local/cash_helper.dart';
import '../Qibla/qibla_screen.dart';

class AppHomeLayout extends StatefulWidget {
  const AppHomeLayout({super.key});

  @override
  State<AppHomeLayout> createState() => _AppHomeLayoutState();
}

class _AppHomeLayoutState extends State<AppHomeLayout> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _autoLocationEnabled = true;
  bool _locationServiceEnabled = false;
  bool _hasPermission = false;
  bool _isLoadingGps = true;

  // مؤشر انقطاع الإنترنت: يظهر بانر بسيط أعلى الشاشة، ويبقى باقي التطبيق
  // يعمل من ذاكرة Firestore المحلية (المناطق والأدعية). نكشف الاتصال بفحص DNS
  // خفيف دورياً عبر dart:io — بلا أي حزمة native ولا ترقية SDK.
  bool _offline = false;
  Timer? _connTimer;

  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;

  // لربط حركة التبويبات بالـ PageView الناعم
  late PageController _pageController;

  bool get _isGpsReady => kIsWeb ? true : (_autoLocationEnabled && _locationServiceEnabled && _hasPermission);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // تهيئة الـ PageController بدون وجود وثبة مفاجئة
    _pageController = PageController(initialPage: AppCubit.get(context).currentScreen);

    if (kIsWeb) {
      _isLoadingGps = false;
      _locationServiceEnabled = true;
      _hasPermission = true;
    } else {
      _loadLocationState();
      _listenToServiceChanges();
      _initConnectivity();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!kIsWeb) {
        await _tryAutoStartLocationFlow();
        // تشغيل خط عدّ الأشواط المستقل حتى يحتسب في كل التبويبات وليس الخريطة فقط.
        if (mounted) {
          await AppCubit.get(context).startRoundTracking();
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceStatusSubscription?.cancel();
    _connTimer?.cancel();
    AppCubit.get(context).stopRoundTracking();
    _pageController.dispose();
    super.dispose();
  }

  // يفحص الاتصال أول مرة ثم كل ٣٠ ثانية (فحص خفيف لا يرهق البطارية).
  void _initConnectivity() {
    _checkConnectivity();
    _connTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkConnectivity(),
    );
  }

  // فحص اتصال خفيف عبر DNS لخادم Firestore — أدقّ من مجرد وجود واي فاي
  // لأنه يؤكّد وصولاً فعلياً للإنترنت. عند الفشل/المهلة نعتبره غير متصل.
  Future<void> _checkConnectivity() async {
    bool offline;
    try {
      final result = await InternetAddress.lookup('firestore.googleapis.com')
          .timeout(const Duration(seconds: 4));
      offline = result.isEmpty || result.first.rawAddress.isEmpty;
    } catch (_) {
      offline = true;
    }
    if (mounted && offline != _offline) {
      setState(() => _offline = offline);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      _loadLocationState();
      _checkConnectivity();
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

  // زر الطوارئ السريع في الشريط العلوي: تأكيد قصير ثم إرسال الموقع.
  Future<void> _onSosTap() async {
    final s = S.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    HapticFeedback.heavyImpact();

    final confirmed = await _showActionDialog(
      title: isAr ? "نداء استغاثة (SOS)" : "Emergency (SOS)",
      message: isAr
          ? "سيتم إرسال موقعك الحالي لطلب المساعدة. هل أنت متأكد؟"
          : "Your current location will be sent to request help. Are you sure?",
      confirmText: isAr ? "إرسال" : "Send",
      cancelText: s.commonCancel,
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      AppCubit.get(context).sendWhatsAppSOS();
    }
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

    return BlocConsumer<AppCubit, AppStates>(
      // لا نعيد بناء الواجهة (ولا نتفاعل) مع تحديثات اتجاه البوصلة عالية التردد —
      // فهي لا تخص هذه الطبقة، وكانت تسبّب إعادة بناء مستمرة تعطّل اللمس.
      buildWhen: (prev, curr) => curr is! AppQiblaDirectionUpdateState,
      listenWhen: (prev, curr) => curr is! AppQiblaDirectionUpdateState,
      listener: (context, state) {
        if (AppCubit.get(context).currentScreen != _pageController.page?.round()) {
          _pageController.jumpToPage(AppCubit.get(context).currentScreen);
        }

        // رسالة تأكيد بعد محاولة إرسال نداء الطوارئ.
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        if (state is AppSOSSuccessState) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            content: Text(isAr ? "تم إرسال نداء الاستغاثة" : "Emergency request sent"),
          ));
        } else if (state is AppSOSErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: const Color(0xFFCC4B47),
            content: Text(isAr ? "تعذّر إرسال نداء الاستغاثة" : "Could not send emergency request"),
          ));
        }
      },
      builder: (context, state) {
        final cubit = AppCubit.get(context);

        // غمر الكود داخل كلاس Material لمنع وحل أخطاء الخطوط الصفراء تماماً من شاشات الجوال
        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: Material(
            color: palette.bg,
            child: Scaffold(
              backgroundColor: palette.bg,
              extendBody: false,
              appBar: _HomeTopBar(
                palette: palette,
                onLanguageTap: LocaleController.toggle,
                onGpsTap: _onGpsTap,
                onSosTap: _onSosTap,
                isGpsReady: _isGpsReady,
                isLoading: _isLoadingGps,
              ),
              body: Column(
                children: [
                  if (_offline) _OfflineBanner(palette: palette, isAr: isAr),
                  Expanded(
                    child: Stack(
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
                        PageView.builder(
                          controller: _pageController,
                          physics: const BouncingScrollPhysics(),
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
                  ),
                ],
              ),
              bottomNavigationBar: _FixedBottomNav(
                palette: palette,
                currentIndex: cubit.currentScreen,
                onTap: (index) {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOutCubic,
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

/// بانر رفيع يظهر أعلى الشاشة عند انقطاع الإنترنت — يطمئن الحاج أن التطبيق
/// ما زال يعمل من البيانات المحفوظة محلياً (المناطق والأدعية والمواقيت).
class _OfflineBanner extends StatelessWidget {
  final _HomeLayoutPalette palette;
  final bool isAr;

  const _OfflineBanner({required this.palette, required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF8A6D1A),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              isAr
                  ? 'غير متصل — التطبيق يعمل من البيانات المحفوظة'
                  : 'Offline — running from saved data',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
  final VoidCallback onSosTap;
  final bool isGpsReady;
  final bool isLoading;

  const _HomeTopBar({
    required this.palette,
    required this.onLanguageTap,
    required this.onGpsTap,
    required this.onSosTap,
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
              _SosButton(palette: palette, onTap: onSosTap),
              const SizedBox(width: 6),
              _QiblaIconButton(palette: palette),
              const SizedBox(width: 6),
              _GpsStatusButton(
                palette: palette,
                isActive: isGpsReady,
                isLoading: isLoading,
                onTap: onGpsTap,
              ),
              const SizedBox(width: 6),
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

// زر الطوارئ السريع (SOS) في الشريط العلوي — دائرة حمراء بارزة لكن أنيقة.
class _ThemeToggleButton extends StatefulWidget {
  final _HomeLayoutPalette palette;
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeToggleButton({required this.palette, required this.isDark, required this.onTap});

  @override
  State<_ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<_ThemeToggleButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.88),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.palette.gold.withOpacity(.12),
            border: Border.all(color: widget.palette.gold.withOpacity(.4), width: 1.3),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                widget.isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                key: ValueKey(widget.isDark),
                color: widget.palette.gold,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SosButton extends StatefulWidget {
  final _HomeLayoutPalette palette;
  final VoidCallback onTap;

  const _SosButton({required this.palette, required this.onTap});

  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE0463F);
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.94),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: red.withOpacity(.14),
            border: Border.all(color: red.withOpacity(.95), width: 2.0),
            boxShadow: [
              BoxShadow(
                color: red.withOpacity(.20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              "SOS",
              style: TextStyle(
                color: red,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// تلغيم زر الـ GPS بالتأثير المطاطي المرن والاهتزاز
class _GpsStatusButton extends StatefulWidget {
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
  State<_GpsStatusButton> createState() => _GpsStatusButtonState();
}

class _GpsStatusButtonState extends State<_GpsStatusButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF38C793);
    final inactiveColor = widget.palette.danger;
    final ringColor = widget.isActive ? activeColor : inactiveColor;
    final fillColor = ringColor.withOpacity(.14);

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.94),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fillColor,
            border: Border.all(
              color: ringColor.withOpacity(.95),
              width: 2.0,
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
            child: widget.isLoading
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(ringColor),
              ),
            )
                : Icon(
              widget.isActive ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
              size: 24,
              color: ringColor,
            ),
          ),
        ),
      ),
    );
  }
}

// تلغيم زر اختيار اللغة بالتأثير المطاطي المرن والاهتزاز
class _LangPill extends StatefulWidget {
  final _HomeLayoutPalette palette;
  final String label;
  final VoidCallback onTap;

  const _LangPill({
    required this.palette,
    required this.label,
    required this.onTap,
  });

  @override
  State<_LangPill> createState() => _LangPillState();
}

class _LangPillState extends State<_LangPill> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.94),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: widget.palette.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.palette.gold.withOpacity(.65),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.palette.gold.withOpacity(.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.palette.gold,
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

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
              label: isAr ? 'الدليل' : 'Guide',
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(Icons.auto_awesome_rounded),
              ),
              label: isAr ? 'المساعد' : 'Assistant',
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

// تلغيم زر الحوار الأساسي بالتأثير المطاطي
class _DialogPrimaryButton extends StatefulWidget {
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
  State<_DialogPrimaryButton> createState() => _DialogPrimaryButtonState();
}

class _DialogPrimaryButtonState extends State<_DialogPrimaryButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [widget.color1, widget.color2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color1.withOpacity(.18),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.text,
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

// تلغيم زر الحوار الثانوي بالتأثير المطاطي
class _DialogSecondaryButton extends StatefulWidget {
  final String text;
  final _HomeLayoutPalette palette;
  final VoidCallback onTap;

  const _DialogSecondaryButton({
    required this.text,
    required this.palette,
    required this.onTap,
  });

  @override
  State<_DialogSecondaryButton> createState() => _DialogSecondaryButtonState();
}

// زر البوصلة في الشريط العلوي
class _QiblaIconButton extends StatelessWidget {
  final dynamic palette;
  const _QiblaIconButton({required this.palette});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QiblaScreen()),
      ),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.card,
          border: Border.all(color: palette.gold.withOpacity(.35)),
        ),
        child: const Center(
          child: Text('🧭', style: TextStyle(fontSize: 17)),
        ),
      ),
    );
  }
}

class _DialogSecondaryButtonState extends State<_DialogSecondaryButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          height: 54,
          child: Container(
            decoration: BoxDecoration(
              color: widget.palette.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.palette.gold.withOpacity(.18),
                width: 1.1,
              ),
            ),
            child: Center(
              child: Text(
                widget.text,
                style: TextStyle(
                  color: widget.palette.textSecondary,
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