import 'package:dhakker/shared/network/local/cash_helper.dart';
import 'package:dhakker/shared/network/local/uid.dart';
import 'package:dhakker/theme_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// استيراد مكتبة الإشعارات الجديدة
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'Screens/auth/Login_Screen.dart';
import 'Screens/auth/Splash_Screen.dart';
import 'admin_bloc/admin_cubit.dart';
import 'bloc/cubit.dart';
import 'generated/l10n.dart';
import 'locale_controller.dart';
import 'theme/dhakker_theme.dart';

// تعريف محرك الإشعارات بشكل عالمي لسهولة الوصول إليه
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة الفايربيس [cite: 111, 480]
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. تهيئة الإشعارات المحلية (الميزة الجديدة)
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // 3. تهيئة التخزين المحلي والإعدادات
  await CashHelper.initPreference();
  final savedDarkMode = CashHelper.getCash(key: 'dark_mode_enabled');
  ThemeController.setTheme(savedDarkMode is bool ? savedDarkMode : true);

  Widget widget;
  var userTypeIndex = CashHelper.getCash(key: 'userTypeIndex');
  tempId = CashHelper.getCash(key: 'uid');

  if (tempId != null) {
    userID = tempId!;
  }

  if (userTypeIndex != null) {
    widget = SplashScreen(userTypeIndex);
  } else {
    widget = SplashScreen(0);
  }

  runApp(MyApp(widget));
}

class MyApp extends StatefulWidget {
  final Widget screen;
  MyApp(this.screen);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: LocaleController.locale,
      builder: (context, loc, _) {
        return MultiBlocProvider(
          providers: [
            // تهيئة الـ Cubits لإدارة حالة التطبيق [cite: 167, 482]
            BlocProvider(create: (_) => AppCubit()),
            BlocProvider(create: (_) => AdminCubit()),
          ],
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, _) {
              return MaterialApp(
                title: 'Dhakker',
                debugShowCheckedModeBanner: false,
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