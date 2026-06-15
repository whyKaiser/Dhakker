import 'dart:convert';
import 'dart:io';

/// مستوى تحذير الحرارة.
enum HeatLevel { none, caution, danger }

/// نصيحة حرارة جاهزة للعرض: المستوى + الحرارة (إن توفّرت) + هل اعتمدنا على
/// تقدير الوقت لعدم توفّر إنترنت.
class HeatAdvice {
  final HeatLevel level;
  final double? temperature; // °م، أو null لو من تقدير الوقت (بدون نت)
  final bool fromTimeHeuristic;
  const HeatAdvice({
    required this.level,
    this.temperature,
    this.fromTimeHeuristic = false,
  });
}

/// يجلب درجة الحرارة الحالية من Open-Meteo (مجانية، بلا مفتاح ولا حد استخدام)
/// حسب موقع الحاج، ويشتق منها مستوى تحذير ضربة الشمس. عند انقطاع الإنترنت
/// يرجع لتقدير حسب ساعات النهار (الحج دائماً في الصيف الحار).
class WeatherService {
  static const String _base = 'https://api.open-meteo.com/v1/forecast';

  /// يرجع الحرارة الحالية (°م) أو null عند الفشل/عدم الاتصال.
  Future<double?> currentTemperature({
    required double lat,
    required double lng,
  }) async {
    final url = '$_base?latitude=$lat&longitude=$lng&current=temperature_2m';
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      if (resp.statusCode != 200) return null;
      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>?;
      final temp = current?['temperature_2m'];
      return temp is num ? temp.toDouble() : null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// يشتق مستوى التحذير من الحرارة الحقيقية، أو من ساعات النهار عند تعذّرها.
  Future<HeatAdvice> currentAdvice({
    required double lat,
    required double lng,
    DateTime? now,
  }) async {
    final temp = await currentTemperature(lat: lat, lng: lng);
    if (temp != null) {
      return HeatAdvice(level: _levelForTemp(temp), temperature: temp);
    }
    // بدون نت: تقدير احترازي حسب الوقت (ذروة الحر ١١ص–٤ع).
    final h = (now ?? DateTime.now()).hour;
    final level = (h >= 11 && h < 16) ? HeatLevel.caution : HeatLevel.none;
    return HeatAdvice(level: level, fromTimeHeuristic: true);
  }

  HeatLevel _levelForTemp(double t) {
    if (t >= 45) return HeatLevel.danger;
    if (t >= 40) return HeatLevel.caution;
    return HeatLevel.none;
  }
}
