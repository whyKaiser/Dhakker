import 'dart:async';
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

  static const AndroidNotificationDetails _waterChannel =
      AndroidNotificationDetails(
    'water_reminder',
    'تذكير شرب الماء',
    channelDescription: 'تذكير دوري بشرب الماء أثناء الطواف أو السعي',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Timer? _waterTimer;

  /// يبدأ تذكيراً دورياً لشرب الماء كل [interval] (افتراضياً 30 دقيقة).
  /// آمن للاستدعاء مرات — يلغي المؤقت القديم تلقائياً.
  void startWaterReminder({
    Duration interval = const Duration(minutes: 30),
    bool isAr = true,
  }) {
    stopWaterReminder();
    _waterTimer = Timer.periodic(interval, (_) async {
      if (!_initialized) await init();
      try {
        await _plugin.show(
          _idCounter++,
          isAr ? '💧 اشرب الماء' : '💧 Drink Water',
          isAr
              ? 'مضت نصف ساعة — تناول الماء الآن للوقاية من الإجهاد الحراري'
              : 'It\'s been 30 minutes — drink water now to stay safe',
          const NotificationDetails(android: _waterChannel),
        );
      } catch (e) {
        debugPrint('تعذّر إشعار الماء: $e');
      }
    });
  }

  /// يوقف تذكير الماء.
  void stopWaterReminder() {
    _waterTimer?.cancel();
    _waterTimer = null;
  }

  // ─── تذكير الأدوية ────────────────────────────────────────────────────────

  static const AndroidNotificationDetails _medChannel =
      AndroidNotificationDetails(
    'medication_reminder',
    'تذكير الأدوية',
    channelDescription: 'تذكير يومي بمواعيد تناول الأدوية',
    importance: Importance.high,
    priority: Priority.high,
  );

  Timer? _medTimer;

  /// يبدأ مؤقتاً يتحقق كل دقيقة ويطلق إشعار الدواء عند المطابقة.
  /// [reminders] = قائمة من {'hour': int, 'minute': int, 'label': String}.
  void startMedicationCheck(List<Map<String, dynamic>> reminders, {bool isAr = true}) {
    _medTimer?.cancel();
    if (reminders.isEmpty) return;
    final fired = <String>{};
    _medTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!_initialized) await init();
      final now = DateTime.now();
      for (final r in reminders) {
        final h = r['hour'] as int;
        final m = r['minute'] as int;
        final label = (r['label'] as String?) ?? '';
        final key = '$h:$m';
        if (now.hour == h && now.minute == m && !fired.contains(key)) {
          fired.add(key);
          try {
            await _plugin.show(
              _idCounter++,
              isAr ? '💊 وقت الدواء' : '💊 Medication Time',
              label.isNotEmpty ? label : (isAr ? 'حان موعد تناول دوائك' : 'Time to take your medication'),
              const NotificationDetails(android: _medChannel),
            );
          } catch (e) {
            debugPrint('تعذّر إشعار الدواء: $e');
          }
        }
        // نمسح المفاتيح المُطلَقة عند تغيّر الدقيقة.
        if (now.minute != m) fired.remove(key);
      }
    });
  }

  void stopMedicationCheck() {
    _medTimer?.cancel();
    _medTimer = null;
  }

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

  // ─── تحذير الحرارة ──────────────────────────────────────────────────────────

  static const AndroidNotificationDetails _heatChannel =
      AndroidNotificationDetails(
    'heat_warning',
    'تحذير ضربة الشمس',
    channelDescription: 'تحذير فوري عند ارتفاع الحرارة لمستوى خطير',
    importance: Importance.max,
    priority: Priority.max,
  );

  Future<void> showHeatWarning({required String body, bool isAr = true}) async {
    if (!_initialized) await init();
    try {
      await _plugin.show(
        _idCounter++,
        isAr ? '🔥 تحذير ضربة شمس!' : '🔥 Heatstroke Warning!',
        body,
        const NotificationDetails(android: _heatChannel),
      );
    } catch (e) {
      debugPrint('تعذّر إشعار الحرارة: $e');
    }
  }

  // ─── تذكير الصلاة ───────────────────────────────────────────────────────────

  static const AndroidNotificationDetails _prayerChannel =
      AndroidNotificationDetails(
    'prayer_reminder',
    'تذكير الصلاة',
    channelDescription: 'تنبيه عند دخول وقت كل صلاة',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> showPrayerReminder({required String name, bool isAr = true}) async {
    if (!_initialized) await init();
    try {
      await _plugin.show(
        _idCounter++,
        isAr ? '🕌 حان وقت $name' : '🕌 Prayer Time: $name',
        isAr ? 'حان وقت صلاة $name — الله أكبر' : 'Time for $name prayer',
        const NotificationDetails(android: _prayerChannel),
      );
    } catch (e) {
      debugPrint('تعذّر إشعار الصلاة: $e');
    }
  }

  // ─── تذكيرات جدول الحج ──────────────────────────────────────────────────────

  static const AndroidNotificationDetails _scheduleChannel =
      AndroidNotificationDetails(
    'hajj_schedule',
    'جدول مناسك الحج',
    channelDescription: 'تذكير بمواعيد مناسك الحج يوماً بيوم',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> showHajjReminder({required String title, required String body}) async {
    if (!_initialized) await init();
    try {
      await _plugin.show(
        _idCounter++,
        '📿 $title',
        body,
        const NotificationDetails(android: _scheduleChannel),
      );
    } catch (e) {
      debugPrint('تعذّر إشعار الجدول: $e');
    }
  }

  // ─── إشعار جماعي من الأدمن ──────────────────────────────────────────────────

  static const AndroidNotificationDetails _broadcastChannel =
      AndroidNotificationDetails(
    'admin_broadcast',
    'رسائل الإدارة',
    channelDescription: 'إشعارات جماعية من إدارة الحج',
    importance: Importance.max,
    priority: Priority.max,
  );

  Future<void> showBroadcast({required String title, required String body}) async {
    if (!_initialized) await init();
    try {
      await _plugin.show(
        _idCounter++,
        title,
        body,
        const NotificationDetails(android: _broadcastChannel),
      );
    } catch (e) {
      debugPrint('تعذّر إشعار البث: $e');
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
