import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../theme/dhakker_theme.dart';

/// لوحة الازدحام اللحظية للأدمن: تعرض عدد الحجّاج المتواجدين في كل منطقة الآن
/// (من حقل currentZone في وثائق المستخدمين) ملوّنة حسب الكثافة لإدارة الحشود.
///
/// الخريطة "حيّة": المناطق المزدحمة تنبض بتوهّج حراري، ومؤشر LIVE نابض،
/// وبطاقات القائمة تتوهّج حسب الكثافة.
class AdminCrowdScreen extends StatefulWidget {
  const AdminCrowdScreen({super.key});

  @override
  State<AdminCrowdScreen> createState() => _AdminCrowdScreenState();
}

class _AdminCrowdScreenState extends State<AdminCrowdScreen>
    with SingleTickerProviderStateMixin {
  // نافذة "التواجد الحيّ": يُحتسب الحاج متواجداً فقط لو حُدّث موقعه خلالها.
  // التطبيق يكتب currentZoneAt مع كل تغيّر نطاق، فهذا يصفّي مَن أغلق التطبيق.
  static const Duration _freshnessWindow = Duration(minutes: 5);

  Map<String, String> _zoneNames = {}; // zoneId -> الاسم المعروض
  bool _zonesLoaded = false;
  bool _showMap = false; // تبديل بين عرض القائمة والخريطة

  // نبضة مستمرة (0..1) تُغذّي كل التأثيرات الحيّة في الشاشة.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _loadZoneNames();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadZoneNames() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('zones').get();
      final map = <String, String>{};
      for (final d in snap.docs) {
        final data = d.data();
        final id = (data['zoneId'] ?? d.id).toString();
        final nameAr = (data['nameAr'] ?? '').toString();
        final nameEn = (data['nameEn'] ?? '').toString();
        map[id] = nameAr.isNotEmpty ? nameAr : (nameEn.isNotEmpty ? nameEn : id);
      }
      if (mounted) {
        setState(() {
          _zoneNames = map;
          _zonesLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _zonesLoaded = true);
    }
  }

  // لون الكثافة حسب عدد الحجّاج في المنطقة.
  Color _densityColor(int count) {
    if (count > 50) return const Color(0xFFE0463F); // مزدحم جداً
    if (count > 20) return const Color(0xFFE0A23C); // متوسط
    return const Color(0xFF38C793); // هادئ
  }

  String _densityLabel(int count) {
    if (count > 50) return 'مزدحم جداً';
    if (count > 20) return 'متوسط';
    return 'هادئ';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final textColor = isDark ? Colors.white : DhakkerColors.lightText;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: const Text('الازدحام اللحظي',
              style: TextStyle(color: DhakkerColors.gold, fontWeight: FontWeight.w900)),
          iconTheme: const IconThemeData(color: DhakkerColors.gold),
          actions: [
            IconButton(
              icon: Icon(_showMap ? Icons.view_list_rounded : Icons.map_rounded,
                  color: DhakkerColors.gold),
              tooltip: _showMap ? 'قائمة' : 'خريطة',
              onPressed: () => setState(() => _showMap = !_showMap),
            ),
          ],
        ),
        body: !_zonesLoaded
            ? const Center(child: CircularProgressIndicator(color: DhakkerColors.gold))
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(color: DhakkerColors.gold));
                  }

                  // نعدّ الحجّاج حسب المنطقة الحالية (نتجاهل الفارغ/غير المتواجد).
                  // مهم: نحسب فقط مَن ختمه الزمني حديث (آخر _freshnessWindow)، لأن
                  // currentZone يبقى محفوظاً لو سكّر الحاج التطبيق داخل النطاق —
                  // فبدون هذه التصفية تنتفخ الأعداد بحجّاج غادروا قبل ساعات.
                  final counts = <String, int>{};
                  int totalPresent = 0;
                  final now = DateTime.now();
                  for (final d in snapshot.data!.docs) {
                    final data = d.data();
                    final zone = (data['currentZone'] ?? '').toString();
                    if (zone.isEmpty) continue;

                    final at = data['currentZoneAt'];
                    // نستبعد التواجد القديم (أو بلا ختم زمني = غير موثوق).
                    if (at is! Timestamp) continue;
                    if (now.difference(at.toDate()) > _freshnessWindow) continue;

                    counts[zone] = (counts[zone] ?? 0) + 1;
                    totalPresent++;
                  }

                  final entries = counts.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  return Column(
                    children: [
                      _summary(card, textColor, totalPresent, entries.length),
                      Expanded(
                        child: _showMap
                            ? _HaramMap(
                                counts: counts,
                                isDark: isDark,
                                zoneNames: _zoneNames,
                                pulse: _pulse,
                              )
                            : entries.isEmpty
                                ? _emptyState()
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                                    itemCount: entries.length,
                                    itemBuilder: (_, i) {
                                      final zoneId = entries[i].key;
                                      final count = entries[i].value;
                                      final name = _zoneNames[zoneId] ?? zoneId;
                                      final color = _densityColor(count);
                                      return _CrowdCard(
                                        name: name,
                                        count: count,
                                        color: color,
                                        label: _densityLabel(count),
                                        card: card,
                                        textColor: textColor,
                                        pulse: _pulse,
                                        // أعلى ٣ مناطق فقط تنبض (تركيز الانتباه)
                                        rank: i,
                                      );
                                    },
                                  ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_2_outlined,
              size: 56, color: DhakkerColors.muted.withOpacity(.5)),
          const SizedBox(height: 12),
          const Text('لا يوجد حجّاج داخل النطاقات حالياً',
              style: TextStyle(color: DhakkerColors.muted, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _summary(Color card, Color textColor, int total, int zones) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DhakkerColors.gold.withOpacity(.18)),
      ),
      child: Row(
        children: [
          _stat('$total', 'حاجّ متواجد', textColor),
          Container(width: 1, height: 36, color: Colors.white12),
          _stat('$zones', 'منطقة نشطة', textColor),
          Container(width: 1, height: 36, color: Colors.white12),
          // مؤشر LIVE نابض
          Expanded(child: _liveBadge()),
        ],
      ),
    );
  }

  Widget _liveBadge() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) {
            final t = (math.sin(_pulse.value * 2 * math.pi) + 1) / 2; // 0..1
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0463F),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE0463F).withOpacity(.3 + t * .5),
                        blurRadius: 4 + t * 8,
                        spreadRadius: t * 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Text('LIVE',
                    style: TextStyle(
                        color: Color(0xFFE0463F),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
              ],
            );
          },
        ),
        const SizedBox(height: 2),
        const Text('مباشر الآن',
            style: TextStyle(color: DhakkerColors.muted, fontSize: 11.5)),
      ],
    );
  }

  Widget _stat(String value, String label, Color textColor) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: DhakkerColors.gold, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: DhakkerColors.muted, fontSize: 12.5)),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// بطاقة منطقة في القائمة — تنبض لو كانت من أكثر المناطق ازدحاماً
// ───────────────────────────────────────────────────────────────
class _CrowdCard extends StatelessWidget {
  final String name;
  final int count;
  final Color color;
  final String label;
  final Color card;
  final Color textColor;
  final Animation<double> pulse;
  final int rank;

  const _CrowdCard({
    required this.name,
    required this.count,
    required this.color,
    required this.label,
    required this.card,
    required this.textColor,
    required this.pulse,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    // تنبض البطاقات المزدحمة (>20) فقط، وأقوى نبضة للأكثر ازدحاماً.
    final pulses = count > 20;

    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final t = pulses ? (math.sin(pulse.value * 2 * math.pi) + 1) / 2 : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(.45 + t * .4),
              width: 1.2 + t * 0.8,
            ),
            boxShadow: pulses
                ? [
                    BoxShadow(
                      color: color.withOpacity(.12 + t * .22),
                      blurRadius: 12 + t * 14,
                      spreadRadius: t * 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // نقطة الكثافة مع هالة نابضة
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (pulses)
                      Container(
                        width: 10 + t * 8,
                        height: 10 + t * 8,
                        decoration: BoxDecoration(
                          color: color.withOpacity((1 - t) * .5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            color: textColor, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(label,
                        style: TextStyle(
                            color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$count',
                    style: TextStyle(
                        color: color, fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────
// خريطة تخطيطية حيّة للمسجد الحرام مع توهّج حراري نابض لكل منطقة
// ───────────────────────────────────────────────────────────────
class _HaramMap extends StatelessWidget {
  final Map<String, int> counts;
  final bool isDark;
  final Map<String, String> zoneNames;
  final Animation<double> pulse;

  const _HaramMap({
    required this.counts,
    required this.isDark,
    required this.zoneNames,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AnimatedBuilder(
                animation: pulse,
                builder: (_, __) {
                  return CustomPaint(
                    painter: _HaramPainter(
                      counts: counts,
                      isDark: isDark,
                      phase: pulse.value,
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          // مفتاح الألوان
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend('هادئ', const Color(0xFF38C793)),
              const SizedBox(width: 16),
              _legend('متوسط', const Color(0xFFE0A23C)),
              const SizedBox(width: 16),
              _legend('مزدحم جداً', const Color(0xFFE0463F)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54, fontSize: 11)),
      ],
    );
  }
}

class _HaramPainter extends CustomPainter {
  final Map<String, int> counts;
  final bool isDark;
  final double phase; // 0..1 لدورة النبض

  const _HaramPainter({
    required this.counts,
    required this.isDark,
    required this.phase,
  });

  // قيمة نبض ناعمة 0..1
  double get _t => (math.sin(phase * 2 * math.pi) + 1) / 2;

  Color _zoneBaseColor(int c) {
    if (c == 0) return (isDark ? Colors.white : Colors.black).withOpacity(.06);
    if (c > 50) return const Color(0xFFE0463F);
    if (c > 20) return const Color(0xFFE0A23C);
    return const Color(0xFF38C793);
  }

  // كم تنبض المنطقة حسب كثافتها (المزدحمة أكثر نبضاً).
  double _intensity(int c) {
    if (c > 50) return 1.0;
    if (c > 20) return 0.6;
    if (c > 0) return 0.25;
    return 0.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final t = _t;

    // خلفية متدرّجة ناعمة
    final bgRect = Rect.fromLTWH(0, 0, w, h);
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [const Color(0xFF14161B), const Color(0xFF0C0D11)]
            : [const Color(0xFFF2F1EC), const Color(0xFFE9E8E1)],
      ).createShader(bgRect);
    canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(20)), bgPaint);

    // شبكة خفيفة (إحساس "رادار")
    final grid = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(.035)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = step; x < w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }
    for (double y = step; y < h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    // حدود المسجد الخارجية
    final outerPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * .06, h * .06, w * .88, h * .88),
          const Radius.circular(16)),
      outerPaint,
    );

    // دالة رسم منطقة مع توهّج حراري + نبض
    void drawZone(
      String id,
      Rect rect, {
      bool circle = false,
      String? label,
      double fontSize = 10,
    }) {
      final count = counts[id] ?? 0;
      final base = _zoneBaseColor(count);
      final intensity = _intensity(count);

      // 1) هالة توهّج حراري خلف المنطقة المزدحمة
      if (intensity > 0) {
        final glowR = (circle ? rect.width / 2 : rect.longestSide / 2) *
            (1.6 + t * 0.6 * intensity);
        final glow = Paint()
          ..shader = RadialGradient(
            colors: [
              base.withOpacity((.35 + t * .25) * intensity),
              base.withOpacity(0),
            ],
          ).createShader(Rect.fromCircle(center: rect.center, radius: glowR))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(rect.center, glowR, glow);
      }

      // 2) جسم المنطقة
      final fill = Paint()..color = base;
      final stroke = Paint()
        ..color = (isDark ? Colors.white : Colors.black)
            .withOpacity(.22 + intensity * t * .4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 + intensity * t * 1.5;

      if (circle) {
        canvas.drawCircle(rect.center, rect.width / 2, fill);
        canvas.drawCircle(rect.center, rect.width / 2, stroke);
      } else {
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(7));
        canvas.drawRRect(rr, fill);
        canvas.drawRRect(rr, stroke);
      }

      // 3) النص (العدد أو الاسم)
      final displayLabel = count > 0 ? '$count' : (label ?? '');
      if (displayLabel.isEmpty) return;
      final tp = TextPainter(
        text: TextSpan(
          text: displayLabel,
          style: TextStyle(
            color: count > 0
                ? Colors.white
                : (isDark ? Colors.white54 : Colors.black38),
            fontSize: count > 0 ? fontSize + 2 : fontSize,
            fontWeight: FontWeight.w900,
            shadows: count > 0
                ? const [Shadow(color: Colors.black54, blurRadius: 3)]
                : null,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
    }

    // --- صحن الطواف (حلقة حول الكعبة) مع موجة دوّارة ---
    final matafR = math.min(w, h) * .18;
    final matafCount = counts['Z_MATAF'] ?? 0;
    final matafColor = _zoneBaseColor(matafCount);
    final matafIntensity = _intensity(matafCount);

    // توهّج الطواف
    if (matafIntensity > 0) {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            matafColor.withOpacity((.3 + t * .25) * matafIntensity),
            matafColor.withOpacity(0),
          ],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: matafR * 1.8))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(cx, cy), matafR * 1.8, glow);
    }

    canvas.drawCircle(Offset(cx, cy), matafR, Paint()..color = matafColor);
    canvas.drawCircle(
        Offset(cx, cy),
        matafR,
        Paint()
          ..color = (isDark ? Colors.white : Colors.black).withOpacity(.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    // موجة طواف دوّارة (قوس متحرّك يلتفّ حول الكعبة عكس عقارب الساعة)
    if (matafCount > 0) {
      final sweep = Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          colors: [
            Colors.white.withOpacity(0),
            Colors.white.withOpacity(.0),
            Colors.white.withOpacity(.45),
            Colors.white.withOpacity(0),
          ],
          stops: const [0.0, 0.6, 0.85, 1.0],
          transform: GradientRotation(-phase * 2 * math.pi),
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: matafR))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawCircle(Offset(cx, cy), matafR * .82, sweep);
    }

    // عدد الطواف أعلى الحلقة
    if (matafCount > 0) {
      final tp = TextPainter(
        text: TextSpan(
            text: '$matafCount',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.black54, blurRadius: 3)])),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - matafR + 8));
    }

    // --- الكعبة (مركز) ---
    final kaabaSize = math.min(w, h) * .10;
    final kaabaPaint = Paint()
      ..color = isDark ? const Color(0xFF1A1A2E) : const Color(0xFF2C2C3E);
    final kaabaRect =
        Rect.fromCenter(center: Offset(cx, cy), width: kaabaSize, height: kaabaSize);
    canvas.drawRRect(
        RRect.fromRectAndRadius(kaabaRect, const Radius.circular(4)), kaabaPaint);
    // حدّ ذهبي للكعبة
    canvas.drawRRect(
        RRect.fromRectAndRadius(kaabaRect, const Radius.circular(4)),
        Paint()
          ..color = DhakkerColors.gold.withOpacity(.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    final kaabaLabel = TextPainter(
      text: const TextSpan(text: '🕋', style: TextStyle(fontSize: 16)),
      textDirection: TextDirection.ltr,
    )..layout();
    kaabaLabel.paint(
        canvas, Offset(cx - kaabaLabel.width / 2, cy - kaabaLabel.height / 2));

    // --- مقام إبراهيم ---
    drawZone(
        'Z_MAQAM',
        Rect.fromCenter(
            center: Offset(cx + matafR * .55, cy - matafR * .35),
            width: 24,
            height: 24),
        circle: true,
        label: 'م',
        fontSize: 8);

    // --- المسعى ---
    final masaaLeft = w * .08;
    drawZone('Z_MASAA', Rect.fromLTWH(masaaLeft, h * .25, w * .13, h * .50),
        label: 'المسعى', fontSize: 9);

    // --- الصفا ---
    drawZone('Z_SAFA', Rect.fromLTWH(masaaLeft + w * .01, h * .72, w * .11, h * .10),
        label: 'الصفا', fontSize: 8);

    // --- المروة ---
    drawZone('Z_MARWAH', Rect.fromLTWH(masaaLeft + w * .01, h * .18, w * .11, h * .10),
        label: 'المروة', fontSize: 8);

    // --- بئر زمزم ---
    drawZone(
        'Z_ZAMZAM',
        Rect.fromCenter(
            center: Offset(cx + matafR * .4, cy + matafR * .6),
            width: 22,
            height: 22),
        circle: true,
        label: 'ز',
        fontSize: 8);

    // --- الأبواب ---
    drawZone('Z_GATE_1', Rect.fromLTWH(w * .79, h * .3, w * .13, h * .15),
        label: 'باب', fontSize: 8);
    drawZone('Z_GATE_2', Rect.fromLTWH(w * .79, h * .55, w * .13, h * .15),
        label: 'باب', fontSize: 8);
  }

  @override
  bool shouldRepaint(_HaramPainter old) =>
      old.counts != counts || old.isDark != isDark || old.phase != phase;
}
