import 'package:adhan/adhan.dart';

/// معلومات صلاة واحدة (الاسم بالعربية والإنجليزية ووقتها).
class PrayerInfo {
  final String nameAr;
  final String nameEn;
  final DateTime time;
  const PrayerInfo(this.nameAr, this.nameEn, this.time);
}

/// نتيجة حساب مواقيت اليوم: قائمة الصلوات + الصلاة القادمة + الوقت المتبقّي لها.
class PrayerTimesResult {
  final List<PrayerInfo> all;
  final PrayerInfo next;
  final Duration untilNext;
  const PrayerTimesResult({
    required this.all,
    required this.next,
    required this.untilNext,
  });
}

/// يحسب مواقيت الصلاة محلياً (بدون إنترنت) باستخدام تقويم أم القرى الرسمي
/// للسعودية. الحساب رياضي بحت من إحداثيات الموقع، فيعمل offline بالكامل.
class PrayerTimesService {
  // إحداثيات مكة الافتراضية عند تعذّر معرفة موقع الحاج (مواقيت الصلاة لا
  // تحتاج دقة عالية — فرق الدقائق ضمن المدينة مقبول).
  static const double _meccaLat = 21.4225;
  static const double _meccaLng = 39.8262;

  CalculationParameters _params() {
    final params = CalculationMethod.umm_al_qura.getParameters();
    params.madhab = Madhab.shafi; // المذهب السائد في الحرمين لحساب العصر
    return params;
  }

  String _arName(Prayer p) {
    switch (p) {
      case Prayer.fajr:
        return 'الفجر';
      case Prayer.sunrise:
        return 'الشروق';
      case Prayer.dhuhr:
        return 'الظهر';
      case Prayer.asr:
        return 'العصر';
      case Prayer.maghrib:
        return 'المغرب';
      case Prayer.isha:
        return 'العشاء';
      case Prayer.none:
        return 'الفجر';
    }
  }

  String _enName(Prayer p) {
    switch (p) {
      case Prayer.fajr:
        return 'Fajr';
      case Prayer.sunrise:
        return 'Sunrise';
      case Prayer.dhuhr:
        return 'Dhuhr';
      case Prayer.asr:
        return 'Asr';
      case Prayer.maghrib:
        return 'Maghrib';
      case Prayer.isha:
        return 'Isha';
      case Prayer.none:
        return 'Fajr';
    }
  }

  /// يحسب مواقيت اليوم والصلاة القادمة. عند عدم تمرير الموقع يستخدم مكة.
  PrayerTimesResult compute({double? lat, double? lng, DateTime? now}) {
    final coords = Coordinates(lat ?? _meccaLat, lng ?? _meccaLng);
    final params = _params();
    final current = now ?? DateTime.now();
    final today = PrayerTimes.today(coords, params);

    // الصلوات الخمس + الشروق بالترتيب لعرضها في الشريط.
    final list = <PrayerInfo>[
      PrayerInfo('الفجر', 'Fajr', today.fajr),
      PrayerInfo('الشروق', 'Sunrise', today.sunrise),
      PrayerInfo('الظهر', 'Dhuhr', today.dhuhr),
      PrayerInfo('العصر', 'Asr', today.asr),
      PrayerInfo('المغرب', 'Maghrib', today.maghrib),
      PrayerInfo('العشاء', 'Isha', today.isha),
    ];

    // الصلاة القادمة: لو انتهت صلوات اليوم (بعد العشاء) فالقادمة فجر الغد.
    final nextEnum = today.nextPrayer();
    PrayerInfo next;
    if (nextEnum == Prayer.none) {
      final tomorrow = PrayerTimes(
        coords,
        DateComponents.from(current.add(const Duration(days: 1))),
        params,
      );
      next = PrayerInfo('الفجر', 'Fajr', tomorrow.fajr);
    } else {
      final t = today.timeForPrayer(nextEnum) ?? today.fajr;
      next = PrayerInfo(_arName(nextEnum), _enName(nextEnum), t);
    }

    return PrayerTimesResult(
      all: list,
      next: next,
      untilNext: next.time.difference(current),
    );
  }
}
