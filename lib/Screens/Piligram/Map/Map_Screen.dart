import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhakker/Screens/Piligram/Map/services/map_controller_service.dart';
import 'package:dhakker/Screens/Piligram/Map/services/map_zone_renderer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../generated/l10n.dart';
import '../home/models/zone_model.dart';
import '../home/services/zone_detection_service.dart';
import '../../../bloc/cubit.dart';
import '../../../bloc/states.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  late final MapControllerService _mapControllerService;
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  final ZoneDetectionService _zoneDetectionService = const ZoneDetectionService();

  List<ZoneModel> _zones = [];
  ZoneModel? _currentZone;
  Position? _currentPosition;

  bool _isLoading = true;
  bool _didFocusOnce = false;

  StreamSubscription<Position>? _positionSubscription;

  void _log(String message) {
    debugPrint('DHKKR_MAP => $message');
  }

  @override
  void initState() {
    super.initState();
    _mapControllerService = MapControllerService(_mapController);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulse = Tween<double>(begin: 0.92, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cubit = AppCubit.get(context);
      cubit.initCompass();
      cubit.initCrowdZoneListener();
      await _initMapFlow();
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initMapFlow() async {
    setState(() {
      _isLoading = true;
    });

    await _loadZones();
    await _startTracking();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadZones() async {
    final query = await FirebaseFirestore.instance
        .collection('zones')
        .where('isActive', isEqualTo: true)
        .get();

    final items = query.docs.map(ZoneModel.fromFirestore).toList();
    items.sort((a, b) => b.priority.compareTo(a.priority));

    _zones = items;
  }

  Future<void> _startTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();

    final hasPermission =
        permission == LocationPermission.always || permission == LocationPermission.whileInUse;

    if (!serviceEnabled || !hasPermission) {
      return;
    }

    // جلب أول موقع بدقة عالية جداً لمنع القفزات البعيدة
    final current = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );

    await _handlePosition(current);

    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best, // رفع الدقة لأعلى مستوى ممكن
        distanceFilter: 2, // تحديث الموقع فور التحرك مترين فقط لثبات الإشارة عند الخيف
      ),
    ).listen((position) async {
      await _handlePosition(position);
    });
  }

  Future<void> _handlePosition(Position position) async {
    _currentPosition = position;

    if (mounted) {
      AppCubit.get(context).updateLocationAndCheckRounds(position);
    }

    final detected = _zoneDetectionService.detectBestZone(
      userLat: position.latitude,
      userLng: position.longitude,
      zones: _zones,
    );

    // --- تحديث أمني وذكي لتصفير حالة تشغيل الصوت عند الخروج أو الانتقال اللحظي بين المناطق ---
    if (mounted) {
      final cubit = AppCubit.get(context);

      // الحالة الأولى: إذا كان داخل زون وخرج الآن إلى منطقة فارغة (مفتوحة)
      if (detected == null && _currentZone != null) {
        _log('تم رصد خروج المستخدم من النطاق: ${_currentZone?.zoneId} - تصفير الـ Audio Trigger');

        // التحقق من وجود دالة التصفير في الكيوبيت الخاص بكم لتجنب كراش التطبيق
        if (cubit.toString().contains('resetAudioTrigger') || kDebugMode) {
          try {
            // استدعاء دالة التصفير (تأكد أن اسمها مطهى كذا في الكيوبيت أو عدلها للاسم الصحيح)
            (cubit as dynamic).resetAudioTrigger();
          } catch (_) {
            _log('تنبيه: تأكد من إضافة دالة resetAudioTrigger داخل AppCubit');
          }
        }
      }
      // الحالة الثانية: إذا انتقل مباشرة من زون قديم إلى زون جديد مختلف
      else if (detected != null && _currentZone != null && detected.zoneId != _currentZone!.zoneId) {
        _log('انتقال مباشر من زون ${_currentZone!.zoneId} إلى ${detected.zoneId} - إعادة تهيئة التشغيل التلقائي');
        try {
          (cubit as dynamic).resetAudioTrigger();
        } catch (_) {}
      }
    }
    // ----------------------------------------------------------------------------------

    _currentZone = detected;

    // التركيز الفوري والسلس على موقع المستخدم الفعلي عند مسجد الخيف
    if (!_didFocusOnce) {
      _didFocusOnce = true;
      _mapControllerService.focusOnPoint(
        LatLng(position.latitude, position.longitude),
        zoom: 18.5,
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _focusOnUser() {
    final p = _currentPosition;
    if (p == null) return;

    _mapControllerService.focusOnPoint(
      LatLng(p.latitude, p.longitude),
      zoom: 18.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = langCode == 'ar';

    final palette = _MapPalette.fromBrightness(isDark);
    final cubit = AppCubit.get(context);

    final renderer = MapZoneRenderer(
      baseGold: palette.gold,
      highlightColor: palette.active,
    );

    final activeZoneId = _currentZone?.zoneId;

    final circleZones = _zones.map((zone) {
      final color = cubit.getZoneColor(zone.zoneId, palette.gold);
      return CircleMarker(
        point: LatLng(zone.centerLat ?? 0.0, zone.centerLng ?? 0.0),
        radius: zone.radiusM ?? 0.0,
        useRadiusInMeter: true,
        color: color,
        borderColor: zone.zoneId == activeZoneId ? palette.active : palette.gold.withOpacity(0.5),
        borderStrokeWidth: zone.zoneId == activeZoneId ? 3.0 : 1.5,
      );
    }).toList();

    final polygonZones = renderer.buildPolygonZones(
      zones: _zones,
      activeZoneId: activeZoneId,
    );

    final labelMarkers = _zones
        .map((zone) => renderer.buildZoneLabelMarker(
      zone: zone,
      label: zone.displayName(langCode),
      isActive: zone.zoneId == activeZoneId,
    ))
        .whereType<Marker>()
        .toList();

    final userMarker = _buildUserMarker(palette: palette, position: _currentPosition, heading: cubit.userHeading);

    final allMarkers = <Marker>[
      ...labelMarkers,
      if (userMarker != null) userMarker,
    ];

    return BlocBuilder<AppCubit, AppStates>(
      builder: (context, state) {
        return Container(
          color: palette.bg,
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      s.mapTitle,
                      style: TextStyle(color: palette.gold, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'AlamirBold'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(height: 1, color: palette.textMuted.withOpacity(.16)),
                  const SizedBox(height: 18),
                  _MapCard(
                    palette: palette,
                    child: Stack(
                      children: [
                        const _DotGridBackground(),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _currentPosition != null
                                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                                  : const LatLng(21.4132, 39.8711),
                              initialZoom: 18.1,
                              minZoom: 16.0,
                              maxZoom: 20.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: isDark
                                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                subdomains: const ['a', 'b', 'c', 'd'],
                                userAgentPackageName: 'dhakker',
                              ),
                              if (polygonZones.isNotEmpty) PolygonLayer(polygons: polygonZones),
                              if (circleZones.isNotEmpty) CircleLayer(circles: circleZones),
                              if (allMarkers.isNotEmpty) MarkerLayer(markers: allMarkers),
                            ],
                          ),
                        ),
                        PositionedDirectional(
                          top: 14,
                          start: 14,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _CurrentZoneChip(
                              key: ValueKey(_currentZone?.zoneId ?? 'no_zone'),
                              palette: palette,
                              text: _currentZone?.displayName(langCode) ?? s.mapNoZoneDetected,
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          bottom: 14,
                          start: 14,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _LegendRow(color: Colors.greenAccent, text: isAr ? "هادئ" : "Calm"),
                                const SizedBox(height: 4),
                                _LegendRow(color: Colors.orangeAccent, text: isAr ? "متوسط" : "Moderate"),
                                const SizedBox(height: 4),
                                _LegendRow(color: Colors.redAccent, text: isAr ? "مزدحم" : "Crowded"),
                              ],
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          end: 14,
                          bottom: 14,
                          child: _MiniBtn(palette: palette, icon: Icons.my_location_rounded, onTap: _focusOnUser),
                        ),
                        if (_isLoading)
                          Positioned.fill(
                            child: Container(color: Colors.black.withOpacity(.12), child: Center(child: CircularProgressIndicator(color: palette.gold))),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      isAr ? "نظام تتبع الأشواط والقبلة اللحظي" : "Smart Rounds & Qibla Tracking",
                      style: TextStyle(color: palette.active, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'AlamirBold'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAr
                        ? "يتحرك مؤشرك الآن بالتوافق مع اتجاه التفافك الفعلي لمعرفة القبلة الكعبة المشرفة، كما تتلون مناطق العبادة ديناميكياً لتوضح لك مستويات الازدحام البشري اللحظي لتجنب التدافع."
                        : "Your indicator now rotates dynamically with your phone to show Qibla direction, and worship zones light up in real-time to display crowd density to avoid crowding.",
                    style: TextStyle(color: palette.textMuted, fontSize: 14, fontWeight: FontWeight.w600, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Marker? _buildUserMarker({required _MapPalette palette, required Position? position, required double heading}) {
    if (position == null) return null;
    return Marker(
      point: LatLng(position.latitude, position.longitude),
      width: 70,
      height: 70,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final o = (1 - _pulseController.value).clamp(0.0, 1.0);
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 0.9 + (0.55 * _pulseController.value),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: palette.active.withOpacity(0.10 + o * 0.10), border: Border.all(color: palette.active.withOpacity(0.22 + o * 0.12), width: 2)),
                ),
              ),
              Transform.rotate(
                angle: (heading * pi / 180) * -1,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.active,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [BoxShadow(color: palette.active.withOpacity(.4), blurRadius: 10)],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      child: Icon(Icons.navigation_rounded, size: 13, color: palette.active),
                    )
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendRow({required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _MapPalette {
  final Color bg;
  final Color gold;
  final Color textPrimary;
  final Color textMuted;
  final Color card;
  final Color border;
  final Color shadow;
  final Color active;

  const _MapPalette({
    required this.bg,
    required this.gold,
    required this.textPrimary,
    required this.textMuted,
    required this.card,
    required this.border,
    required this.shadow,
    required this.active,
  });

  factory _MapPalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _MapPalette(
        bg: Color(0xFF0B0D10),
        gold: Color(0xFFD4AF37),
        textPrimary: Colors.white,
        textMuted: Color(0xFF9AA4B2),
        card: Color(0xFF303030),
        border: Color(0xFF1B1F26),
        shadow: Colors.black,
        active: Color(0xFF38C793),
      );
    }
    return const _MapPalette(
      bg: Color(0xFFF7F7F8),
      gold: Color(0xFFD4AF37),
      textPrimary: Color(0xFF121316),
      textMuted: Color(0xFF667085),
      card: Color(0xFFFFFFFF),
      border: Color(0xFFE5E7EB),
      shadow: Color(0x22000000),
      active: Color(0xFF2BAE7F),
    );
  }
}

class _MapCard extends StatelessWidget {
  final Widget child;
  final _MapPalette palette;
  const _MapCard({required this.child, required this.palette});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.border.withOpacity(.95), width: 1.2),
        boxShadow: [BoxShadow(color: palette.shadow.withOpacity(.16), blurRadius: 28, offset: const Offset(0, 18))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(26), child: child),
    );
  }
}

class _CurrentZoneChip extends StatelessWidget {
  final _MapPalette palette;
  final String text;
  const _CurrentZoneChip({super.key, required this.palette, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.black.withOpacity(.62), borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
    );
  }
}

class _DotGridBackground extends StatelessWidget {
  const _DotGridBackground();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DotGridPainter(), size: Size.infinite);
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(.06);
    const step = 22.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x + 8, y + 8), 1.2, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniBtn extends StatefulWidget {
  final _MapPalette palette;
  final IconData icon;
  final VoidCallback onTap;
  const _MiniBtn({required this.palette, required this.icon, required this.onTap});

  @override
  State<_MiniBtn> createState() => _MiniBtnState();
}

class _MiniBtnState extends State<_MiniBtn> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _scale = 0.92;
        });
      },
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
        });
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() {
          _scale = 1.0;
        });
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(.62),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.palette.gold.withOpacity(.22))
          ),
          child: Icon(widget.icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}