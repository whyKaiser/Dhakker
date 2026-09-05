import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../theme/dhakker_theme.dart';

/// شاشة اختيار موقع من الخريطة — UX قريب من قوقل ماب:
///   - الوضع المفرد: crosshair في المنتصف دائماً، الخريطة تتحرك تحته.
///   - وضع المضلّع (multiPoint): تضغط على الخريطة لإضافة نقاط.
class MapLocationPickerScreen extends StatefulWidget {
  final LatLng? initialPoint;
  final bool multiPoint;
  final List<LatLng> initialPoints;

  const MapLocationPickerScreen({
    super.key,
    this.initialPoint,
    this.multiPoint = false,
    this.initialPoints = const [],
  });

  @override
  State<MapLocationPickerScreen> createState() =>
      _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  static const LatLng _defaultCenter = LatLng(21.4225, 39.8262);

  // وضع المضلّع
  final List<LatLng> _points = [];

  // المركز الحالي للخريطة (يُحدّث مع كل حركة)
  late LatLng _center;
  bool _isDragging = false;

  late final AnimationController _pinAnim;
  late final Animation<double> _pinLift;

  @override
  void initState() {
    super.initState();

    _center = widget.initialPoint ??
        (widget.initialPoints.isNotEmpty
            ? widget.initialPoints.first
            : _defaultCenter);

    if (widget.multiPoint) _points.addAll(widget.initialPoints);

    _pinAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _pinLift = Tween<double>(begin: 0, end: 14).animate(
      CurvedAnimation(parent: _pinAnim, curve: Curves.easeOut),
    );

    if (widget.initialPoint == null && widget.initialPoints.isEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _goToMyLocation(silent: true));
    }
  }

  @override
  void dispose() {
    _pinAnim.dispose();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveStart) {
      setState(() => _isDragging = true);
      _pinAnim.forward();
    } else if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
      setState(() {
        _isDragging = false;
        _center = event.camera.center;
      });
      _pinAnim.reverse();
      HapticFeedback.selectionClick();
    } else if (event is MapEventMove) {
      setState(() => _center = event.camera.center);
    }
  }

  void _handleTap(LatLng point) {
    if (!widget.multiPoint) return;
    HapticFeedback.lightImpact();
    setState(() => _points.add(point));
  }

  void _addCenterPoint() {
    HapticFeedback.mediumImpact();
    setState(() => _points.add(_center));
  }

  Future<void> _goToMyLocation({bool silent = false}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent)
          _toast(_t('فعّل خدمة الموقع أولاً', 'Enable location service first'));
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (silent) return;
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent)
          _toast(_t('لا يوجد إذن للوصول للموقع', 'Location permission denied'));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      _mapController.move(LatLng(pos.latitude, pos.longitude), 17.5);
    } catch (_) {
      if (!silent)
        _toast(_t('تعذّر تحديد موقعك', 'Could not get your location'));
    }
  }

  void _zoom(double delta) {
    _mapController.move(_mapController.camera.center,
        (_mapController.camera.zoom + delta).clamp(3.0, 20.0));
  }

  void _confirm() {
    if (widget.multiPoint) {
      if (_points.length < 3) {
        _toast(_t('أضف ٣ نقاط على الأقل', 'Add at least 3 points'));
        return;
      }
      Navigator.pop(context, List<LatLng>.from(_points));
    } else {
      Navigator.pop(context, _center);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String ar, String en) => _isAr ? ar : en;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    final markers = <Marker>[];
    final polygons = <Polygon>[];

    if (widget.multiPoint) {
      for (var i = 0; i < _points.length; i++) {
        markers.add(_numberedMarker(_points[i], i + 1, accent));
      }
      if (_points.length >= 2) {
        polygons.add(Polygon(
          points: _points,
          color: accent.withOpacity(0.15),
          borderColor: accent,
          borderStrokeWidth: 2.5,
        ));
      }
    }

    final canConfirm = widget.multiPoint ? _points.length >= 3 : true;
    final lat = _center.latitude.toStringAsFixed(6);
    final lng = _center.longitude.toStringAsFixed(6);

    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          _t('اختر الموقع', 'Pick Location'),
          style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black54, blurRadius: 8)]),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // ── الخريطة ──────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16.5,
              minZoom: 3,
              maxZoom: 20,
              onTap: (_, point) => _handleTap(point),
              onMapEvent: _onMapEvent,
            ),
            children: [
              TileLayer(
                urlTemplate: isDark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'dhakker',
              ),
              if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
            ],
          ),

          // ── Crosshair (وضع النقطة المفردة) ───────────
          if (!widget.multiPoint)
            AnimatedBuilder(
              animation: _pinLift,
              builder: (_, __) {
                return Center(
                  child: Transform.translate(
                    offset: Offset(0, -(_pinLift.value + 24)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ظل تحت البين
                        if (!_isDragging)
                          Container(
                            width: 8,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        const SizedBox(height: 2),
                        // البين نفسه
                        Icon(Icons.location_pin,
                            color: accent,
                            size: 48,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 12)
                            ]),
                      ],
                    ),
                  ),
                );
              },
            ),

          // ── شريط الإحداثيات أعلى الخريطة ────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            left: 12,
            right: 12,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.65),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.multiPoint
                          ? Icons.touch_app_rounded
                          : Icons.drag_indicator_rounded,
                      color: accent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.multiPoint
                          ? _t('اضغط لإضافة نقطة', 'Tap to add point')
                          : '$lat, $lng',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── أزرار التحكم (يمين) ──────────────────────
          PositionedDirectional(
            end: 14,
            bottom: 160,
            child: Column(
              children: [
                _MapBtn(
                    icon: Icons.add_rounded,
                    accent: accent,
                    onTap: () => _zoom(1)),
                const SizedBox(height: 8),
                _MapBtn(
                    icon: Icons.remove_rounded,
                    accent: accent,
                    onTap: () => _zoom(-1)),
                const SizedBox(height: 16),
                _MapBtn(
                  icon: Icons.my_location_rounded,
                  accent: accent,
                  onTap: () => _goToMyLocation(),
                ),
              ],
            ),
          ),

          // ── اللوحة السفلية ────────────────────────────
          PositionedDirectional(
            start: 12,
            end: 12,
            bottom: 16,
            child: _BottomPanel(
              isDark: isDark,
              accent: accent,
              multiPoint: widget.multiPoint,
              center: _center,
              pointsCount: _points.length,
              canConfirm: canConfirm,
              onAddPoint: widget.multiPoint ? _addCenterPoint : null,
              onUndo: widget.multiPoint && _points.isNotEmpty
                  ? () => setState(() => _points.removeLast())
                  : null,
              onClear: widget.multiPoint && _points.isNotEmpty
                  ? () => setState(() => _points.clear())
                  : null,
              onConfirm: _confirm,
              labelConfirm: _t('تأكيد', 'Confirm'),
              labelUndo: _t('تراجع', 'Undo'),
              labelClear: _t('مسح', 'Clear'),
              labelAdd: _t('أضف النقطة الحالية', 'Add current point'),
            ),
          ),
        ],
      ),
    );
  }

  Marker _numberedMarker(LatLng p, int number, Color accent) {
    return Marker(
      point: p,
      width: 30,
      height: 30,
      child: Container(
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.3), blurRadius: 6)
          ],
        ),
        alignment: Alignment.center,
        child: Text('$number',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12)),
      ),
    );
  }
}

// ── زر دائري للخريطة ────────────────────────────────────────
class _MapBtn extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  const _MapBtn(
      {required this.icon, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(.25)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 8)
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ── اللوحة السفلية ──────────────────────────────────────────
class _BottomPanel extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final bool multiPoint;
  final LatLng center;
  final int pointsCount;
  final bool canConfirm;
  final VoidCallback? onAddPoint;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;
  final VoidCallback onConfirm;
  final String labelConfirm;
  final String labelUndo;
  final String labelClear;
  final String labelAdd;

  const _BottomPanel({
    required this.isDark,
    required this.accent,
    required this.multiPoint,
    required this.center,
    required this.pointsCount,
    required this.canConfirm,
    required this.onAddPoint,
    required this.onUndo,
    required this.onClear,
    required this.onConfirm,
    required this.labelConfirm,
    required this.labelUndo,
    required this.labelClear,
    required this.labelAdd,
  });

  @override
  Widget build(BuildContext context) {
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .4 : .12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // معلومات الموقع
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: multiPoint
                    ? Text(
                        'نقاط: $pointsCount',
                        style: TextStyle(
                            color: text,
                            fontWeight: FontWeight.w800,
                            fontSize: 14),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            center.latitude.toStringAsFixed(6),
                            style: TextStyle(
                                color: text,
                                fontWeight: FontWeight.w900,
                                fontSize: 13),
                          ),
                          Text(
                            center.longitude.toStringAsFixed(6),
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // أزرار الإجراءات
          Row(
            children: [
              if (multiPoint) ...[
                _SmallBtn(
                  label: labelUndo,
                  icon: Icons.undo_rounded,
                  muted: muted,
                  text: text,
                  onTap: onUndo,
                ),
                const SizedBox(width: 6),
                _SmallBtn(
                  label: labelClear,
                  icon: Icons.delete_outline_rounded,
                  muted: muted,
                  text: text,
                  onTap: onClear,
                ),
                const SizedBox(width: 6),
                _SmallBtn(
                  label: '+',
                  icon: Icons.add_location_alt_rounded,
                  muted: accent,
                  text: accent,
                  onTap: onAddPoint,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: isDark ? DhakkerColors.bg : Colors.white,
                    disabledBackgroundColor: accent.withOpacity(.3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: canConfirm ? onConfirm : null,
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: Text(labelConfirm,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color muted;
  final Color text;
  final VoidCallback? onTap;

  const _SmallBtn({
    required this.label,
    required this.icon,
    required this.muted,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.35,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: muted.withOpacity(.4)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: enabled
            ? () {
                HapticFeedback.lightImpact();
                onTap!();
              }
            : null,
        icon: Icon(icon, size: 16),
        label: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
      ),
    );
  }
}
