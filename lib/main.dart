import 'package:dhakker/shared/network/local/cash_helper.dart';
import 'package:dhakker/shared/network/local/uid.dart';
import 'package:dhakker/theme_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhakker/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// استيراد الملف الجديد الذي قمنا بتوليده
import 'firebase_options.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'Screens/auth/Splash_Screen.dart';
import 'Screens/auth/onboarding_screen.dart';
import 'admin_bloc/admin_cubit.dart';
import 'bloc/cubit.dart';
import 'generated/l10n.dart';
import 'locale_controller.dart';

import 'theme/dhakker_theme.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة الفايربيس لكل المنصات.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // تفعيل التخزين المحلي لـ Firestore: بعد أول تحميل بنت، تُحفظ المناطق
    // والأدعية محلياً وتعمل بدون إنترنت — مهم لأن شبكة مكة تتعطّل أيام الذروة.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    debugPrint("خطأ في تهيئة الفايربيس: $e");
  }

  try {
    await CashHelper.initPreference();
  } catch (e) {
    debugPrint("خطأ في تهيئة التخزين المحلي: $e");
  }

  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint("خطأ في تهيئة الإشعارات: $e");
  }

  final savedDarkMode = CashHelper.getCash(key: 'dark_mode_enabled');
  ThemeController.setTheme(savedDarkMode is bool ? savedDarkMode : true);

  Widget widget;
  var userTypeIndex = CashHelper.getCash(key: 'userTypeIndex');

  tempId = CashHelper.getCash(key: 'uid');

  if (tempId != null) {
    userID = tempId!;
  }

  final onboardingDone = CashHelper.getCash(key: 'onboarding_done');
  if (userTypeIndex != null) {
    widget = SplashScreen(userTypeIndex);
  } else if (onboardingDone != true) {
    widget = const OnboardingScreen();
  } else {
    widget = const SplashScreen(0);
  }

  runApp(MyApp(widget));
}

class MyApp extends StatefulWidget {
  final Widget screen; // إضافة final للتحسين
  const MyApp(this.screen, {super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// سلوك تمرير عام بإحساس iOS: ارتداد ناعم، بلا توهّج أندرويد، ويدعم
/// السحب باللمس والماوس واللوحة لتجربة سلسة حيّة في كل الشاشات.
class _SmoothScrollBehavior extends MaterialScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child; // إزالة توهّج الحافة الأندرويدي
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<ThemeMode> _themeMode = ValueNotifier(ThemeMode.dark);

  @override
  void dispose() {
    _themeMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: LocaleController.locale,
      builder: (context, loc, _) {
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => AppCubit()),
            BlocProvider(create: (_) => AdminCubit()),
          ],
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, _) {
              return MaterialApp(
                title: 'Dhakker',
                debugShowCheckedModeBanner: false,
                // تمرير ناعم بإحساس iOS على كل الشاشات (ارتداد + بلا توهّج أندرويد).
                scrollBehavior: const _SmoothScrollBehavior(),
                theme: dhakkerLightTheme(),
                darkTheme: dhakkerDarkTheme(),
                themeMode: mode,
                locale: loc,
                supportedLocales: S.delegate.supportedLocales,
                localizationsDelegates: const [
                  S.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: widget.screen,
              );
            },
          ),
        );
      },
    );
  }
}