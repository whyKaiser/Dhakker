import 'dart:math' as math;
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen>
    with SingleTickerProviderStateMixin {
  double? _qiblaDirection; // زاوية القبلة من الشمال (ثابتة)
  double _deviceHeading = 0; // اتجاه الجهاز الحالي
  bool _loading = true;
  String? _error;

  late AnimationController _needleController;
  late Animation<double> _needleAnim;
  double _prevNeedle = 0;

  @override
  void initState() {
    super.initState();
    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _needleAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _needleController, curve: Curves.easeOut),
    );
    _init();
  }

  Future<void> _init() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final coords = Coordinates(pos.latitude, pos.longitude);
      final qibla = Qibla(coords);
      setState(() {
        _qiblaDirection = qibla.direction;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'تعذّر تحديد الموقع. تأكد من تفعيل خدمة الموقع.';
        _loading = false;
      });
    }

    FlutterCompass.events?.listen((event) {
      if (!mounted) return;
      final h = event.heading ?? 0;
      setState(() => _deviceHeading = h);

      if (_qiblaDirection != null) {
        final target = (_qiblaDirection! - h) * (math.pi / 180);
        _needleAnim = Tween<double>(begin: _prevNeedle, end: target).animate(
          CurvedAnimation(parent: _needleController, curve: Curves.easeOut),
        );
        _prevNeedle = target;
        _needleController
          ..reset()
          ..forward();
      }
    });
  }

  @override
  void dispose() {
    _needleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0D10) : const Color(0xFFF5F0E8);
    const gold = Color(0xFFD4AF37);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary =
        isDark ? Colors.white60 : const Color(0xFF6B6B8A);
    final cardBg = isDark ? const Color(0xFF141720) : Colors.white;
    final isAr =
        Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: gold, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isAr ? 'اتجاه القبلة' : 'Qibla Direction',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFamily: 'AlamirBold',
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: gold))
          : _error != null
              ? _ErrorView(message: _error!, color: gold, textColor: textSecondary)
              : _CompassView(
                  needleAnim: _needleAnim,
                  qiblaDirection: _qiblaDirection!,
                  deviceHeading: _deviceHeading,
                  gold: gold,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  cardBg: cardBg,
                  isDark: isDark,
                  isAr: isAr,
                ),
    );
  }
}

// ─── واجهة البوصلة ────────────────────────────────────────────────────────────
class _CompassView extends StatelessWidget {
  final Animation<double> needleAnim;
  final double qiblaDirection;
  final double deviceHeading;
  final Color gold;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardBg;
  final bool isDark;
  final bool isAr;

  const _CompassView({
    required this.needleAnim,
    required this.qiblaDirection,
    required this.deviceHeading,
    required this.gold,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardBg,
    required this.isDark,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final needleDeg = qiblaDirection - deviceHeading;
    final isAligned = (needleDeg.abs() % 360) < 8 ||
        ((needleDeg.abs() % 360) > 352);
    final statusColor = isAligned ? const Color(0xFF38C793) : gold;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // ─── دائرة البوصلة ───────────────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: needleAnim,
              builder: (_, __) {
                return SizedBox(
                  width: 280,
                  height: 280,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // الدائرة الخارجية
                      Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cardBg,
                          border: Border.all(
                            color: gold.withOpacity(.35),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: gold.withOpacity(.12),
                              blurRadius: 40,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      // علامات الاتجاهات
                      ..._compassLabels(gold, textSecondary),
                      // دائرة داخلية
                      Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: gold.withOpacity(.15),
                            width: 1,
                          ),
                        ),
                      ),
                      // الإبرة
                      Transform.rotate(
                        angle: needleAnim.value,
                        child: CustomPaint(
                          size: const Size(16, 170),
                          painter: _NeedlePainter(gold: gold, isDark: isDark),
                        ),
                      ),
                      // نقطة المركز
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: gold,
                          boxShadow: [
                            BoxShadow(
                              color: gold.withOpacity(.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      // أيقونة الكعبة فوق الإبرة
                      Transform.rotate(
                        angle: needleAnim.value,
                        child: Transform.translate(
                          offset: const Offset(0, -75),
                          child: const Text('🕋', style: TextStyle(fontSize: 26)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          // ─── بطاقة المعلومات ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(.3)),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(.08),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              children: [
                // الحالة
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isAligned
                          ? (isAr ? 'أنت تواجه القبلة' : 'Facing the Qibla')
                          : (isAr ? 'وجّه الجهاز نحو السهم' : 'Point device toward arrow'),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'AlamirBold',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: gold.withOpacity(.12)),
                const SizedBox(height: 14),
                // الزوايا
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _InfoChip(
                      label: isAr ? 'اتجاه القبلة' : 'Qibla Bearing',
                      value: '${qiblaDirection.toStringAsFixed(1)}°',
                      gold: gold,
                      textSecondary: textSecondary,
                      textPrimary: textPrimary,
                    ),
                    Container(width: 1, height: 36, color: gold.withOpacity(.15)),
                    _InfoChip(
                      label: isAr ? 'اتجاهك الحالي' : 'Your Heading',
                      value: '${deviceHeading.toStringAsFixed(0)}°',
                      gold: gold,
                      textSecondary: textSecondary,
                      textPrimary: textPrimary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // تنبيه التداخل المغناطيسي
          Text(
            isAr
                ? 'ابتعد عن الأجهزة الكهربائية للحصول على قراءة دقيقة'
                : 'Keep away from electronics for accurate reading',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _compassLabels(Color gold, Color textSecondary) {
    const labels = [
      (0.0, 'ش'),
      (90.0, 'شرق'),
      (180.0, 'جن'),
      (270.0, 'غرب'),
    ];
    return labels.map((l) {
      final angle = l.$1 * math.pi / 180;
      const r = 125.0;
      final x = r * math.sin(angle);
      final y = -r * math.cos(angle);
      return Transform.translate(
        offset: Offset(x, y),
        child: Text(
          l.$2,
          style: TextStyle(
            color: l.$1 == 0 ? gold : textSecondary,
            fontSize: l.$1 == 0 ? 13 : 11,
            fontWeight: l.$1 == 0 ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      );
    }).toList();
  }
}

// ─── رسّام الإبرة ──────────────────────────────────────────────────────────────
class _NeedlePainter extends CustomPainter {
  final Color gold;
  final bool isDark;
  const _NeedlePainter({required this.gold, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // النصف العلوي (يشير للقبلة) — ذهبي
    final topPath = Path()
      ..moveTo(cx, cy - 75)
      ..lineTo(cx - 6, cy)
      ..lineTo(cx + 6, cy)
      ..close();
    canvas.drawPath(
      topPath,
      Paint()
        ..color = gold
        ..style = PaintingStyle.fill,
    );

    // النصف السفلي — رمادي داكن
    final bottomPath = Path()
      ..moveTo(cx, cy + 75)
      ..lineTo(cx - 6, cy)
      ..lineTo(cx + 6, cy)
      ..close();
    canvas.drawPath(
      bottomPath,
      Paint()
        ..color = (isDark ? Colors.white24 : Colors.black26)
        ..style = PaintingStyle.fill,
    );

    // خط أبيض خفيف على الإبرة الذهبية
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx, cy - 75),
      Paint()
        ..color = Colors.white.withOpacity(.25)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_NeedlePainter old) =>
      old.gold != gold || old.isDark != isDark;
}

// ─── ويدجت المعلومة ────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color gold;
  final Color textSecondary;
  final Color textPrimary;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.gold,
    required this.textSecondary,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: gold,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'AlamirBold',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── واجهة الخطأ ──────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final Color color;
  final Color textColor;

  const _ErrorView({
    required this.message,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded, color: color, size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontSize: 15, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
