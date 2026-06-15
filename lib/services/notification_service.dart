import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// خدمة إشعارات محلية بسيطة — تُستخدم حالياً لتنبيه الحاج عند دخول منطقة جديدة
/// أثناء استخدام التطبيق (حتى لو كان على تبويب آخر). إشعار فوري لا مجدول، فلا
/// يحتاج إعدادات منطقة زمنية أو مستقبِلات (receivers) معقّدة.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _idCounter = 1000;

  static const AndroidNotificationDetails _zoneChannel =
      AndroidNotificationDetails(
    'zone_entry',
    'تنبيهات المناطق',
    channelDescription: 'تنبيه عند دخول منطقة من مناطق المناسك',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// تهيئة الإضافة وطلب إذن الإشعارات (أندرويد 13+). آمنة للاستدعاء مرة واحدة.
  Future<void> init() async {
    if (_initialized) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _plugin.initialize(initSettings);

      // إذن الإشعارات مطلوب من أندرويد 13 (API 33) فما فوق.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _initialized = true;
    } catch (e) {
      debugPrint('تعذّر تهيئة الإشعارات: $e');
    }
  }

  /// يعرض إشعار دخول منطقة. آمن: عند عدم التهيئة أو رفض الإذن لا يتعطّل شيء.
  Future<void> showZoneEntry({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    try {
      await _plugin.show(
        _idCounter++,
        title,
        body,
        const NotificationDetails(android: _zoneChannel),
      );
    } catch (e) {
      debugPrint('تعذّر عرض إشعار المنطقة: $e');
    }
  }
}
