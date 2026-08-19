import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

/// يحسب أوقات الصلاة محلياً (بدون إنترنت) عبر مكتبة adhan، ويُطلق إشعاراً
/// عند دخول كل وقت. يعمل حتى في وضع offline الكامل.
class PrayerReminderService {
  PrayerReminderService._();
  static final PrayerReminderService instance = PrayerReminderService._();

  Timer? _timer;
  double _lat = 21.3891;
  double _lng = 39.8579;
  bool _isAr = true;
  final Set<String> _firedToday = {};

  static const _namesAr = {
    Prayer.fajr:    'الفجر',
    Prayer.sunrise: 'الشروق',
    Prayer.dhuhr:   'الظهر',
    Prayer.asr:     'العصر',
    Prayer.maghrib: 'المغرب',
    Prayer.isha:    'العشاء',
  };

  static const _namesEn = {
    Prayer.fajr:    'Fajr',
    Prayer.sunrise: 'Sunrise',
    Prayer.dhuhr:   'Dhuhr',
    Prayer.asr:     'Asr',
    Prayer.maghrib: 'Maghrib',
    Prayer.isha:    'Isha',
  };

  void start({required double lat, required double lng, bool isAr = true}) {
    _lat = lat;
    _lng = lng;
    _isAr = isAr;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _firedToday.clear();
  }

  void _check() {
    try {
      final now = DateTime.now();
      final coords = Coordinates(_lat, _lng);
      final params = CalculationMethod.umm_al_qura.getParameters();
      final times = PrayerTimes(coords, DateComponents.from(now), params);

      // إعادة تعيين الإطلاقات عند منتصف الليل
      final todayKey = '${now.year}-${now.month}-${now.day}';
      if (!_firedToday.contains('__$todayKey')) {
        _firedToday.removeWhere((k) => !k.startsWith('__'));
        _firedToday.add('__$todayKey');
      }

      for (final prayer in _namesAr.keys) {
        final t = times.timeForPrayer(prayer);
        if (t == null) continue;
        if (t.hour == now.hour && t.minute == now.minute) {
          final key = '$todayKey-$prayer';
          if (_firedToday.contains(key)) continue;
          _firedToday.add(key);
          final name = _isAr ? (_namesAr[prayer] ?? '') : (_namesEn[prayer] ?? '');
          NotificationService.instance.showPrayerReminder(name: name, isAr: _isAr);
        }
      }
    } catch (e) {
      debugPrint('PrayerReminder: $e');
    }
  }

  /// يعيد وقت الصلاة القادمة واسمها (للعرض في الواجهة).
  Map<String, dynamic>? nextPrayer({double? lat, double? lng, bool isAr = true}) {
    try {
      final coords = Coordinates(lat ?? _lat, lng ?? _lng);
      final params = CalculationMethod.umm_al_qura.getParameters();
      final times = PrayerTimes(coords, DateComponents.from(DateTime.now()), params);
      final next = times.nextPrayer();
      if (next == Prayer.none) return null;
      final t = times.timeForPrayer(next);
      if (t == null) return null;
      return {
        'name': isAr ? _namesAr[next] : _namesEn[next],
        'time': t,
      };
    } catch (_) {
      return null;
    }
  }
}
