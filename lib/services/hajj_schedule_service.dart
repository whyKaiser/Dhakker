import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

/// خدمة جدول مناسك الحج — تُطلق تذكيرات حسب اليوم الهجري من ذي الحجة
/// (من اليوم 8 حتى 13). يُخزَّن تاريخ "يوم 8" من الإعدادات ويُحسب اليوم الحالي منه.
class HajjScheduleService {
  HajjScheduleService._();
  static final HajjScheduleService instance = HajjScheduleService._();

  static const String _prefKey = 'hajj_day8_date';

  Timer? _timer;
  DateTime? _day8Date;
  final Set<String> _firedToday = {};

  // جدول المناسك: {رقم اليوم: [(ساعة, دقيقة, عنوان, تفاصيل)]}
  static const Map<int, List<_Reminder>> _schedule = {
    8: [
      _Reminder(
          6, 0, 'يوم التروية', 'اليوم الثامن — استعدّ للإحرام والتوجه إلى منى'),
      _Reminder(10, 0, 'المبيت في منى', 'السنة البيتوتة في منى هذه الليلة'),
    ],
    9: [
      _Reminder(
          6, 0, 'يوم عرفة', '🌄 ركن الحج الأعظم — توجّه لعرفات قبل الظهر'),
      _Reminder(
          12, 0, 'وقفة عرفة', '🤲 الآن في أشرف موقف — أكثر من الدعاء والذكر'),
      _Reminder(
          17, 30, 'الدفع من عرفة', '🚶 بعد غروب الشمس ادفع باتجاه مزدلفة'),
    ],
    10: [
      _Reminder(5, 0, 'يوم النحر', '🗓 رمي جمرة العقبة بعد الفجر'),
      _Reminder(
          8, 0, 'طواف الإفاضة', '🕋 ركن الحج — اتجه للمسجد الحرام للطواف'),
      _Reminder(14, 0, 'السعي', '🏃 اسعَ بين الصفا والمروة بعد طواف الإفاضة'),
    ],
    11: [
      _Reminder(12, 30, 'رمي الجمرات',
          '🪨 بعد الزوال — الصغرى ثم الوسطى ثم الكبرى (العقبة)'),
    ],
    12: [
      _Reminder(12, 30, 'رمي الجمرات',
          '🪨 آخر أيام التشريق الإلزامية — الصغرى ثم الوسطى ثم الكبرى'),
    ],
    13: [
      _Reminder(7, 0, 'طواف الوداع',
          '🕋 آخر عهدك بالكعبة — لا تنسَ طواف الوداع قبل السفر'),
    ],
  };

  /// يحفظ تاريخ اليوم الثامن من ذي الحجة.
  Future<void> saveDay8Date(DateTime date) async {
    _day8Date = DateTime(date.year, date.month, date.day);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _day8Date!.toIso8601String());
  }

  /// يُحمّل التاريخ المحفوظ.
  Future<DateTime?> loadDay8Date() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_prefKey);
    if (s == null) return null;
    try {
      _day8Date = DateTime.parse(s);
      return _day8Date;
    } catch (_) {
      return null;
    }
  }

  /// يبدأ مؤقتاً يتحقق كل دقيقة ويُطلق تذكيرات المناسك.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
    _check();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _check() {
    if (_day8Date == null) return;
    try {
      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month}-${now.day}';
      final hajjDay = now.difference(_day8Date!).inDays + 8;

      final reminders = _schedule[hajjDay];
      if (reminders == null) return;

      for (final r in reminders) {
        if (r.hour == now.hour && r.minute == now.minute) {
          final key = '$todayKey-${r.title}';
          if (_firedToday.contains(key)) continue;
          _firedToday.add(key);
          NotificationService.instance.showHajjReminder(
            title: r.title,
            body: r.body,
          );
        }
      }
    } catch (e) {
      debugPrint('HajjSchedule: $e');
    }
  }

  /// اليوم الحالي من الحج (8-13)، أو null لو لم يُضبط التاريخ أو خارج الأيام.
  int? currentHajjDay() {
    if (_day8Date == null) return null;
    final day = DateTime.now().difference(_day8Date!).inDays + 8;
    return (day >= 8 && day <= 13) ? day : null;
  }
}

class _Reminder {
  final int hour;
  final int minute;
  final String title;
  final String body;
  const _Reminder(this.hour, this.minute, this.title, this.body);
}
