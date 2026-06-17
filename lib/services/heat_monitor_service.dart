import 'dart:async';
import 'package:flutter/foundation.dart';
import 'weather_service.dart';
import 'notification_service.dart';

/// يراقب درجة الحرارة كل 30 دقيقة ويُطلق تحذيراً عند الخطر (≥ 42°م).
class HeatMonitorService {
  HeatMonitorService._();
  static final HeatMonitorService instance = HeatMonitorService._();

  final WeatherService _ws = WeatherService();
  Timer? _timer;
  HeatLevel _lastLevel = HeatLevel.none;
  bool _isAr = true;

  void start({required double lat, required double lng, bool isAr = true}) {
    _isAr = isAr;
    _timer?.cancel();
    // فحص فوري عند البدء
    _check(lat, lng);
    _timer = Timer.periodic(const Duration(minutes: 30), (_) => _check(lat, lng));
  }

  void updateLocation(double lat, double lng) {
    _timer?.cancel();
    _check(lat, lng);
    _timer = Timer.periodic(const Duration(minutes: 30), (_) => _check(lat, lng));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _lastLevel = HeatLevel.none;
  }

  Future<void> _check(double lat, double lng) async {
    try {
      final advice = await _ws.currentAdvice(lat: lat, lng: lng);
      if (advice.level == HeatLevel.danger && _lastLevel != HeatLevel.danger) {
        final temp = advice.temperature?.toStringAsFixed(0) ?? '45+';
        await NotificationService.instance.showHeatWarning(
          body: _isAr
              ? 'درجة الحرارة $temp°م — توجّه لمكان مظلل واشرب ماء فوراً'
              : 'Temperature $temp°C — seek shade and drink water immediately',
          isAr: _isAr,
        );
      }
      _lastLevel = advice.level;
    } catch (e) {
      debugPrint('HeatMonitor: $e');
    }
  }
}
