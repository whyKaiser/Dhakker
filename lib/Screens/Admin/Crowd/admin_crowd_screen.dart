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
      duration: const Duration(milliseconds: 6000),
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
        map[id] =
            nameAr.isNotEmpty ? nameAr : (nameEn.isNotEmpty ? nameEn : id);
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
              style: TextStyle(
                  color: DhakkerColors.gold, fontWeight: FontWeight.w900)),
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
            ? const Center(
                child: CircularProgressIndicator(color: DhakkerColors.gold))
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: DhakkerColors.gold));
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
                    if (now.difference(at.toDate()) > _freshnessWindow) {
                      continue;
                    }

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
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 4, 16, 18),
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
              style: TextStyle(
                  color: DhakkerColors.muted, fontWeight: FontWeight.w700)),
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
                  color: DhakkerColors.gold,
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(color: DhakkerColors.muted, fontSize: 12.5)),
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
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
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
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(label,
                        style: TextStyle(
                            color: color,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$count',
                    style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────
// خريطة 3D تفاعلية — تدوير + تكبير + نقر على المناطق
// ───────────────────────────────────────────────────────────────
class _HaramMap extends StatefulWidget {
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
  State<_HaramMap> createState() => _HaramMapState();
}

class _HaramMapState extends State<_HaramMap> {
  double _azimuth = math.pi * 0.25; // زاوية الدوران الأفقي
  double _elevation = math.pi * 0.30; // زاوية الميل العمودي
  double _scale = 1.0;

  double _baseAzimuth = 0;
  double _baseElevation = 0;
  double _baseScale = 1;
  Offset _baseFocal = Offset.zero;

  String? _selectedId;

  // hit-zones تُكتب من الـ painter أثناء الرسم
  final List<_ZoneHit> _hitZones = [];

  void _onScaleStart(ScaleStartDetails d) {
    _baseAzimuth = _azimuth;
    _baseElevation = _elevation;
    _baseScale = _scale;
    _baseFocal = d.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      _scale = (_baseScale * d.scale).clamp(0.4, 4.0);
      final dx = d.focalPoint.dx - _baseFocal.dx;
      final dy = d.focalPoint.dy - _baseFocal.dy;
      _azimuth = _baseAzimuth - dx * 0.007 / _scale;
      _elevation = (_baseElevation + dy * 0.005 / _scale)
          .clamp(0.08, math.pi / 2 - 0.08);
    });
  }

  void _onTapUp(TapUpDetails d) {
    final tap = d.localPosition;
    for (final z in _hitZones.reversed) {
      if (_pointInPoly(tap, z.topPoly)) {
        setState(() => _selectedId = _selectedId == z.id ? null : z.id);
        return;
      }
    }
    setState(() => _selectedId = null);
  }

  bool _pointInPoly(Offset p, List<Offset> poly) {
    bool inside = false;
    final n = poly.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final xi = poly[i].dx, yi = poly[i].dy;
      final xj = poly[j].dx, yj = poly[j].dy;
      if (((yi > p.dy) != (yj > p.dy)) &&
          (p.dx < (xj - xi) * (p.dy - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  Color _densityColor(int c) {
    if (c > 50) return const Color(0xFFE0463F);
    if (c > 20) return const Color(0xFFE0A23C);
    return const Color(0xFF38C793);
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selectedId;
    final selCount = sel != null ? (widget.counts[sel] ?? 0) : 0;
    final selName = sel != null
        ? (widget.zoneNames[sel] ?? _Iso3DPainter.zoneLabelFor(sel))
        : '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ─── الخريطة ────────────────────────────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onTapUp: _onTapUp,
                child: AnimatedBuilder(
                  animation: widget.pulse,
                  builder: (_, __) => CustomPaint(
                    painter: _Iso3DPainter(
                      counts: widget.counts,
                      isDark: widget.isDark,
                      phase: widget.pulse.value,
                      azimuth: _azimuth,
                      elevation: _elevation,
                      scale: _scale,
                      selectedId: _selectedId,
                      hitZones: _hitZones,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),

          // ─── بطاقة المنطقة المحددة ───────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: sel == null
                ? const SizedBox.shrink()
                : Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF141720)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _densityColor(selCount).withOpacity(.5),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _densityColor(selCount).withOpacity(.15),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _densityColor(selCount),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selName,
                            style: TextStyle(
                              color:
                                  widget.isDark ? Colors.white : Colors.black87,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'AlamirBold',
                            ),
                          ),
                        ),
                        Text(
                          '$selCount حاجّ',
                          style: TextStyle(
                            color: _densityColor(selCount),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // ─── مفتاح الألوان + تلميح التحكم ───────────────────────
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend('هادئ', const Color(0xFF38C793)),
              const SizedBox(width: 14),
              _legend('متوسط', const Color(0xFFE0A23C)),
              const SizedBox(width: 14),
              _legend('مزدحم', const Color(0xFFE0463F)),
              const Spacer(),
              Icon(Icons.swipe_rounded,
                  size: 14,
                  color: widget.isDark ? Colors.white30 : Colors.black26),
              const SizedBox(width: 4),
              Text('اسحب للدوران',
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isDark ? Colors.white30 : Colors.black38,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: widget.isDark ? Colors.white70 : Colors.black54,
                  fontSize: 10.5)),
        ],
      );
}

// ───────────────────────────────────────────────────────────────
// Iso3DPainter — رسم 3D قابل للدوران مع hit-testing
// ───────────────────────────────────────────────────────────────
class _ZoneHit {
  final String id;
  final List<Offset> topPoly;
  const _ZoneHit(this.id, this.topPoly);
}

class _Iso3DPainter extends CustomPainter {
  final Map<String, int> counts;
  final bool isDark;
  final double phase;
  final double azimuth;
  final double elevation;
  final double scale;
  final String? selectedId;
  final List<_ZoneHit> hitZones;

  static String zoneLabelFor(String id) {
    const m = {
      'Z_MASAA': 'المسعى',
      'Z_MARWAH': 'المروة',
      'Z_SAFA': 'الصفا',
      'Z_MATAF': 'المطاف',
      'Z_MAQAM': 'مقام إبراهيم',
      'Z_ZAMZAM': 'بئر زمزم',
      'Z_GATE_1': 'الباب الأول',
      'Z_GATE_2': 'الباب الثاني',
    };
    return m[id] ?? id;
  }

  const _Iso3DPainter({
    required this.counts,
    required this.isDark,
    required this.phase,
    required this.azimuth,
    required this.elevation,
    required this.scale,
    required this.selectedId,
    required this.hitZones,
  });

  static const double _gridCX = 2.5; // مركز الشبكة
  static const double _gridCY = 2.5;

  double get _pulse => (math.sin(phase * 2 * math.pi) + 1) / 2;

  /// إسقاط نقطة 3D بزاوية دوران وميل ديناميكيَّين
  Offset _proj(double gx, double gy, double gz, Offset origin, double cs) {
    final dx = gx - _gridCX;
    final dy = gy - _gridCY;
    final cosA = math.cos(azimuth);
    final sinA = math.sin(azimuth);
    final sinE = math.sin(elevation);
    final cosE = math.cos(elevation);
    final rx = dx * cosA - dy * sinA;
    final ry = dx * sinA + dy * cosA;
    return Offset(
      origin.dx + rx * cs,
      origin.dy + ry * cs * sinE - gz * cs * cosE * 0.9,
    );
  }

  Color _densityColor(int c, {String id = ''}) {
    if (c > 50) return const Color(0xFFE0463F);
    if (c > 20) return const Color(0xFFE0A23C);
    if (c > 0) return const Color(0xFF38C793);
    // ألوان مميّزة لكل منطقة حتى عند الفراغ
    switch (id) {
      case 'Z_MATAF':
        return const Color(0xFF1C3A5E); // أزرق داكن — مطاف
      case 'Z_MASAA':
        return const Color(0xFF2E3A1E); // أخضر داكن — مسعى
      case 'Z_SAFA':
        return const Color(0xFF3A2A1E); // بني — صفا
      case 'Z_MARWAH':
        return const Color(0xFF3A2A1E); // بني — مروة
      case 'Z_MAQAM':
        return const Color(0xFF3A321E); // ذهبي داكن — مقام
      case 'Z_ZAMZAM':
        return const Color(0xFF1E2E3A); // أزرق رمادي — زمزم
      case 'Z_GATE_1':
      case 'Z_GATE_2':
        return const Color(0xFF2A2240); // بنفسجي — باب
      default:
        return const Color(0xFF2A2D35);
    }
  }

  double _pillarH(int c) {
    if (c == 0) return 0.15;
    if (c > 50) return 3.5 + _pulse * 0.4;
    if (c > 20) return 2.2 + _pulse * 0.3;
    return 1.0 + _pulse * 0.2;
  }

  Color _shade(Color c, double f) => Color.fromARGB(
        c.alpha,
        (c.red * f).clamp(0, 255).toInt(),
        (c.green * f).clamp(0, 255).toInt(),
        (c.blue * f).clamp(0, 255).toInt(),
      );

  /// يرسم مكعباً ويعيد نقاط السقف الأربع لـ hit-testing
  List<Offset> _drawBox(
    Canvas canvas,
    Offset origin,
    double cs,
    double gx,
    double gy,
    double gw,
    double gd,
    double gh,
    Color base, {
    bool glow = false,
    bool selected = false,
    String? label,
  }) {
    Offset p(double x, double y, double z) => _proj(x, y, z, origin, cs);

    final t0 = p(gx, gy, gh);
    final t1 = p(gx + gw, gy, gh);
    final t2 = p(gx + gw, gy + gd, gh);
    final t3 = p(gx, gy + gd, gh);
    final b1 = p(gx + gw, gy, 0);
    final b2 = p(gx + gw, gy + gd, 0);
    final b3 = p(gx, gy + gd, 0);

    // هالة توهّج
    if (glow || selected) {
      final ctr = Offset(
        (t0.dx + t1.dx + t2.dx + t3.dx) / 4,
        (t0.dy + t1.dy + t2.dy + t3.dy) / 4,
      );
      final r = cs * (selected ? 1.8 : 1.2 + _pulse * 0.5);
      final gCol = selected ? const Color(0xFFD4AF37) : base;
      canvas.drawCircle(
        ctr,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            gCol.withOpacity(selected ? 0.7 : 0.5 + _pulse * 0.3),
            gCol.withOpacity(0),
          ]).createShader(Rect.fromCircle(center: ctr, radius: r))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    // جانب أيسر
    canvas.drawPath(Path()..addPolygon([t3, t2, b2, b3], true),
        Paint()..color = _shade(base, 0.45));
    // جانب أيمن
    canvas.drawPath(Path()..addPolygon([t1, t2, b2, b1], true),
        Paint()..color = _shade(base, 0.65));
    // السقف
    final topPath = Path()..addPolygon([t0, t1, t2, t3], true);
    canvas.drawPath(topPath, Paint()..color = _shade(base, 1.0));
    // حدّ ذهبي على المنطقة المحددة
    if (selected) {
      canvas.drawPath(
        topPath,
        Paint()
          ..color = const Color(0xFFD4AF37)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    } else {
      canvas.drawPath(
        topPath,
        Paint()
          ..color = Colors.white.withOpacity(.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7,
      );
    }

    // نص العدد أو الاسم
    if (label != null && label.isNotEmpty) {
      final tc = Offset(
        (t0.dx + t1.dx + t2.dx + t3.dx) / 4,
        (t0.dy + t1.dy + t2.dy + t3.dy) / 4,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, tc - Offset(tp.width / 2, tp.height / 2));
    }

    return [t0, t1, t2, t3];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cs = w * 0.13 * scale; // حجم الخلية ديناميكي
    final origin = Offset(w * 0.5, h * 0.55);

    // خلفية
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, w, h), const Radius.circular(20)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0C10), Color(0xFF060709)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // شبكة الأرضية
    final gridP = Paint()
      ..color = Colors.white.withOpacity(.04)
      ..strokeWidth = 0.7;
    for (int gx = -3; gx <= 7; gx++) {
      canvas.drawLine(
        _proj(gx.toDouble(), -1, 0, origin, cs),
        _proj(gx.toDouble(), 7, 0, origin, cs),
        gridP,
      );
    }
    for (int gy = -1; gy <= 7; gy++) {
      canvas.drawLine(
        _proj(-3, gy.toDouble(), 0, origin, cs),
        _proj(7, gy.toDouble(), 0, origin, cs),
        gridP,
      );
    }

    // المناطق
    const zoneDefs = [
      _ZoneDef('Z_MASAA', -1, 1, 1.0, 4.0, 'المسعى'),
      _ZoneDef('Z_MARWAH', -1, 0, 1.0, 1.0, 'المروة'),
      _ZoneDef('Z_SAFA', -1, 5, 1.0, 1.0, 'الصفا'),
      _ZoneDef('Z_MATAF', 1, 1, 1.0, 4.0, 'مطاف'),
      _ZoneDef('Z_MATAF', 4, 1, 1.0, 4.0, 'مطاف'),
      _ZoneDef('Z_MATAF', 1, 1, 4.0, 1.0, 'مطاف'),
      _ZoneDef('Z_MATAF', 1, 4, 4.0, 1.0, 'مطاف'),
      _ZoneDef('Z_MAQAM', 3, 2, 0.8, 0.8, 'مقام'),
      _ZoneDef('Z_ZAMZAM', 3, 3, 0.8, 0.8, 'زمزم'),
      _ZoneDef('Z_GATE_1', 5, 0, 1.2, 1.2, 'باب 1'),
      _ZoneDef('Z_GATE_2', 5, 5, 1.2, 1.2, 'باب 2'),
    ];

    // ترتيب painter's algorithm حسب العمق
    final sorted = zoneDefs.toList()
      ..sort((a, b) {
        final cosA = math.cos(azimuth);
        final sinA = math.sin(azimuth);
        double depth(double x, double y) =>
            (x - _gridCX) * sinA + (y - _gridCY) * cosA;
        return depth(b.gx + b.spanW / 2, b.gy + b.spanD / 2)
            .compareTo(depth(a.gx + a.spanW / 2, a.gy + a.spanD / 2));
      });

    // أعد بناء hitZones في كل رسم
    hitZones.clear();

    for (final z in sorted) {
      final c = counts[z.id] ?? 0;
      final color = _densityColor(c, id: z.id);
      final pilH = _pillarH(c);
      final isSel = selectedId == z.id;
      final topPoly = _drawBox(
        canvas,
        origin,
        cs,
        z.gx,
        z.gy,
        z.spanW,
        z.spanD,
        pilH,
        color,
        glow: c > 20,
        selected: isSel,
        label: c > 0 ? '$c' : z.label,
      );
      // أضف أو حدّث hit zone (لكل id مرة واحدة فقط)
      if (!hitZones.any((h) => h.id == z.id)) {
        hitZones.add(_ZoneHit(z.id, topPoly));
      }
    }

    // الكعبة
    _drawBox(canvas, origin, cs, 2, 2, 1.8, 1.8, 2.5, const Color(0xFF1A1A1A),
        label: '🕋');

    // حدّ ذهبي على سقف الكعبة
    final kTop = Path()
      ..addPolygon([
        _proj(2, 2, 2.5, origin, cs),
        _proj(3.8, 2, 2.5, origin, cs),
        _proj(3.8, 3.8, 2.5, origin, cs),
        _proj(2, 3.8, 2.5, origin, cs),
      ], true);
    canvas.drawPath(
      kTop,
      Paint()
        ..color = const Color(0xFFD4AF37).withOpacity(0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // ─── قوس الطواف الدوّار ─────────────────────────────────────────────
    // مركز الكعبة تقريباً (2.9, 2.9 هو منتصف المربع 2..3.8)
    final kCenter = _proj(2.9, 2.9, 2.5, origin, cs);
    final tawafR = cs * 1.55; // نصف قطر الحلقة حول الكعبة

    // هالة ذهبية
    canvas.drawCircle(
      kCenter,
      tawafR + _pulse * cs * 0.15,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFD4AF37).withOpacity(0.18 + _pulse * 0.10),
          const Color(0xFFD4AF37).withOpacity(0),
        ]).createShader(
            Rect.fromCircle(center: kCenter, radius: tawafR + cs * 0.3))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // قوس دوّار (عكس عقارب الساعة)
    final sweepRect = Rect.fromCircle(center: kCenter, radius: tawafR);
    final sweepAngle = -phase * 2 * math.pi; // دوران سالب = عكس العقارب
    canvas.drawArc(
      sweepRect,
      sweepAngle,
      math.pi * 1.1,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: sweepAngle,
          endAngle: sweepAngle + math.pi * 1.1,
          colors: [
            const Color(0xFFD4AF37).withOpacity(0),
            const Color(0xFFD4AF37).withOpacity(0.7),
          ],
        ).createShader(sweepRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // ─── نقاط الحجاج المتحركة حول الكعبة ───────────────────────────────
    const pilgramCount = 12;
    for (int i = 0; i < pilgramCount; i++) {
      final frac = i / pilgramCount;
      // زاوية كل حاج — يتحرك عكس العقارب
      final angle = sweepAngle + frac * 2 * math.pi;
      final dotX = kCenter.dx + tawafR * math.cos(angle);
      final dotY = kCenter.dy + tawafR * math.sin(angle);
      // تباين في الحجم والسطوع لإحساس العمق
      final brightness = (math.sin(angle + phase * math.pi) + 1) / 2;
      final dotR = 2.2 + brightness * 1.4;
      canvas.drawCircle(
        Offset(dotX, dotY),
        dotR,
        Paint()..color = Colors.white.withOpacity(0.55 + brightness * 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_Iso3DPainter old) =>
      old.counts != counts ||
      old.phase != phase ||
      old.azimuth != azimuth ||
      old.elevation != elevation ||
      old.scale != scale ||
      old.selectedId != selectedId;
}

// بيانات تعريف منطقة
class _ZoneDef {
  final String id;
  final double gx, gy, spanW, spanD;
  final String label;
  const _ZoneDef(this.id, this.gx, this.gy, this.spanW, this.spanD, this.label);
}
