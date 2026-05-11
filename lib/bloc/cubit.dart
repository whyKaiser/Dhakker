import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../Screens/Piligram/Home/Home_Screen.dart';
import '../Screens/Piligram/Map/Map_Screen.dart';
import '../Screens/Piligram/Duas/Duas_Screen.dart';
import '../Screens/Piligram/Settings/Settings_Screen.dart';
import '../Screens/Piligram/Tasbih/Tasbih_Screen.dart';
import 'states.dart';
import '../main.dart';

class AppCubit extends Cubit<AppState> {
  AppCubit() : super(AppInitState());

  static AppCubit get(BuildContext context) => BlocProvider.of(context);

  int currentScreen = 0;
  int lapCount = 0;
  DateTime? lastLapTime;

  final List<Widget> screens = [
    const HomeScreen(),
    const MapScreen(),
    const DuasScreen(),
    const TasbihScreen(),
    const SettingsScreen(),
  ];

  void changeScreen(int index) {
    currentScreen = index;
    emit(AppChangeScreenState());
  }

  // دالة الـ SOS لإرسال الموقع عبر الواتساب
  Future<void> sendSOS() async {
    try {
      // الحصول على الموقع الحالي بطريقة حديثة
      Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      );

      String mapUrl = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      String message = "نداء استغاثة من تطبيق (ذاكر):\nأحتاج لمساعدة فورية، موقعي الحالي:\n$mapUrl";

      var whatsappUrl = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(message)}");

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        var smsUrl = Uri.parse("sms:?body=${Uri.encodeComponent(message)}");
        await launchUrl(smsUrl);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "تأكد من تفعيل صلاحيات الموقع");
    }
  }

  Future<void> sendSmartNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'dhakker_channel', 'Dhakker Notifications', importance: Importance.max, priority: Priority.high,
    );
    await flutterLocalNotificationsPlugin.show(0, title, body, const NotificationDetails(android: androidDetails));
  }

  void checkLapCounter(String zoneName, String duaText) {
    if (zoneName.contains("حجر") || zoneName.toLowerCase().contains("hajar")) {
      DateTime now = DateTime.now();
      if (lastLapTime == null || now.difference(lastLapTime!).inMinutes >= 4) {
        lapCount++;
        lastLapTime = now;
        sendSmartNotification("تقبل الله! الشوط رقم $lapCount", "استمر في الطواف والدعاء.");
        Fluttertoast.showToast(msg: "تم تسجيل الشوط رقم $lapCount", backgroundColor: Colors.amber);
        emit(AppChangeScreenState());
      }
    } else {
      sendSmartNotification("منطقة $zoneName", "الدعاء: $duaText");
    }
  }

  void resetLaps() {
    lapCount = 0;
    lastLapTime = null;
    emit(AppChangeScreenState());
  }
}