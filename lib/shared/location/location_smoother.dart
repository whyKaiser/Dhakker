import 'dart:math';

/// فلتر كالمان خفيف لإحداثيات GPS (lat/lng) لتقليل اهتزاز القراءات (jitter).
///
/// مبني على نموذج "GPS Kalman" المعروف والمستخدم على نطاق واسع:
/// - ضوضاء عملية ثابتة لكل ثانية ([qMetresPerSecond]) تمثّل سرعة تحرّك المستخدم
///   المتوقعة (مشي بطيء داخل الحرم ≈ 1-3 م/ث).
/// - ضوضاء القياس مشتقة من دقة كل قراءة (accuracy) القادمة من الجهاز.
///
/// الفلتر يحافظ على تقدير ناعم للموقع ويقلّل القفزات العشوائية، فيصير
/// كشف المنطقة وعدّ الأشواط أثبت. لا يصنع دقة من العدم داخل المباني المغلقة.
class KalmanLatLong {
  /// ضوضاء العملية: كم متر/ثانية يُتوقع أن يتحرك المستخدم. الأعلى = استجابة
  /// أسرع وتنعيم أقل، الأقل = تنعيم أقوى وتأخّر أكبر.
  final double qMetresPerSecond;

  // أدنى دقة نتعامل معها (متر) لتفادي القسمة على صفر.
  static const double _minAccuracy = 1.0;

  double? _lat;
  double? _lng;
  double _variance = -1; // P بالمتر² ، -1 = غير مهيّأ بعد
  int _timeStampMs = 0;

  KalmanLatLong({this.qMetresPerSecond = 3});

  bool get isInitialized => _variance >= 0;
  double? get lat => _lat;
  double? get lng => _lng;

  /// الدقة المُقدَّرة بعد التنعيم (متر).
  double get accuracy => sqrt(_variance < 0 ? 0 : _variance);

  /// إعادة الفلتر لحالته الابتدائية (تُستدعى عند بدء تتبّع جديد).
  void reset() {
    _variance = -1;
    _lat = null;
    _lng = null;
    _timeStampMs = 0;
  }

  /// إدخال قراءة جديدة. بعد الاستدعاء تُقرأ النتيجة من [lat] و[lng].
  void process(double lat, double lng, double accuracy, int timeStampMs) {
    if (accuracy < _minAccuracy) accuracy = _minAccuracy;

    if (_variance < 0) {
      // أول قراءة: نهيّئ الحالة مباشرة.
      _timeStampMs = timeStampMs;
      _lat = lat;
      _lng = lng;
      _variance = accuracy * accuracy;
      return;
    }

    // كلما مرّ وقت منذ آخر قراءة، يزيد عدم اليقين (خطوة التنبؤ).
    final dtMs = timeStampMs - _timeStampMs;
    if (dtMs > 0) {
      _variance += dtMs * qMetresPerSecond * qMetresPerSecond / 1000.0;
      _timeStampMs = timeStampMs;
    }

    // كسب كالمان K بين 0 و1: كم نثق بالقراءة الجديدة مقابل التقدير الحالي.
    final k = _variance / (_variance + accuracy * accuracy);
    _lat = _lat! + k * (lat - _lat!);
    _lng = _lng! + k * (lng - _lng!);
    _variance = (1 - k) * _variance;
  }
}
