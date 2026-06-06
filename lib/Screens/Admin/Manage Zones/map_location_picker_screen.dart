import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../theme/dhakker_theme.dart';

/// شاشة اختيار موقع من الخريطة (مثل تجربة قوقل ماب: تتنقّل وتكبّر وتضغط).
///
/// - الوضع المفرد (multiPoint=false): تختار نقطة واحدة (مركز الدائرة)
///   وترجع `LatLng` عبر Navigator.pop.
/// - وضع تعدد النقاط (multiPoint=true): ترسم نقاط حدود المضلّع بالتسلسل
///   وترجع `List<LatLng>`.
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
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  final MapController _mapController = MapController();

  // مركز افتراضي: مكة المكرمة (يُستخدم فقط لو ما فيه نقطة بداية ولا موقع للمستخدم)
  static const LatLng _defaultCenter = LatLng(21.4225, 39.8262);

  LatLng? _selected; // الوضع المفرد
  final List<LatLng> _points = []; // وضع المضلّع

  @override
  void initState() {
    super.initState();
    if (widget.multiPoint) {
      _points.addAll(widget.initialPoints);
    } else {
      _selected = widget.initialPoint;
    }

    // لو ما فيه نقطة بداية، نحاول نركّز على موقع المستخدم الحالي (إن كان الإذن متاحاً)
    if (widget.initialPoint == null && widget.initialPoints.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToMyLocation(silent: true));
    }
  }

  LatLng get _initialCenter {
    if (widget.initialPoint != null) return widget.initialPoint!;
    if (widget.initialPoints.isNotEmpty) return widget.initialPoints.first;
    return _defaultCenter;
  }

  void _handleTap(LatLng point) {
    HapticFeedback.lightImpact();
    setState(() {
      if (widget.multiPoint) {
        _points.add(point);
      } else {
        _selected = point;
      }
    });
  }

  Future<void> _goToMyLocation({bool silent = false}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent) _toast(_t('فعّل خدمة الموقع أولاً', 'Enable location service first'));
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (silent) return; // لا نطلب الإذن تلقائياً عند الفتح
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent) _toast(_t('لا يوجد إذن للوصول للموقع', 'Location permission denied'));
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      _mapController.move(LatLng(pos.latitude, pos.longitude), 17.0);
    } catch (_) {
      if (!silent) _toast(_t('تعذّر تحديد موقعك', 'Could not get your location'));
    }
  }

  void _confirm() {
    if (widget.multiPoint) {
      if (_points.length < 3) {
        _toast(_t('أضف ٣ نقاط على الأقل', 'Add at least 3 points'));
        return;
      }
      Navigator.pop(context, List<LatLng>.from(_points));
    } else {
      if (_selected == null) {
        _toast(_t('اضغط على الخريطة لتحديد الموقع', 'Tap the map to set a location'));
        return;
      }
      Navigator.pop(context, _selected);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String ar, String en) => _isAr ? ar : en;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final textColor = isDark ? Colors.white : DhakkerColors.lightText;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    final markers = <Marker>[];
    if (widget.multiPoint) {
      for (var i = 0; i < _points.length; i++) {
        markers.add(_numberedMarker(_points[i], i + 1, accent));
      }
    } else if (_selected != null) {
      markers.add(_dotMarker(_selected!, accent));
    }

    final polygons = <Polygon>[];
    if (widget.multiPoint && _points.length >= 2) {
      polygons.add(
        Polygon(
          points: _points,
          color: accent.withOpacity(0.18),
          borderColor: accent,
          borderStrokeWidth: 2.5,
        ),
      );
    }

    final canConfirm = widget.multiPoint ? _points.length >= 3 : _selected != null;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: textColor,
        title: Text(
          _t('اختر الموقع من الخريطة', 'Pick location on map'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 16.5,
              minZoom: 3,
              maxZoom: 20,
              onTap: (tapPosition, point) => _handleTap(point),
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

          // شريط التعليمات أعلى
          PositionedDirectional(
            top: 12,
            start: 12,
            end: 12,
            child: _InfoChip(
              text: widget.multiPoint
                  ? _t('اضغط على الخريطة لإضافة نقاط الحدود (٣ على الأقل)',
                      'Tap the map to add boundary points (min 3)')
                  : _t('اضغط على الخريطة لتحديد المركز',
                      'Tap the map to set the center'),
            ),
          ),

          // زر "موقعي"
          PositionedDirectional(
            end: 14,
            bottom: 168,
            child: _RoundBtn(
              icon: Icons.my_location_rounded,
              accent: accent,
              onTap: () => _goToMyLocation(),
            ),
          ),

          // اللوحة السفلية
          PositionedDirectional(
            start: 12,
            end: 12,
            bottom: 16,
            child: _BottomPanel(
              isDark: isDark,
              accent: accent,
              multiPoint: widget.multiPoint,
              selected: _selected,
              pointsCount: _points.length,
              canConfirm: canConfirm,
              labelSelected: _t('الموقع المحدد', 'Selected location'),
              labelNone: _t('لم تحدد موقعاً بعد', 'No location selected yet'),
              labelPoints: _t('عدد النقاط', 'Points'),
              labelConfirm: _t('تأكيد', 'Confirm'),
              labelUndo: _t('تراجع', 'Undo'),
              labelClear: _t('مسح', 'Clear'),
              onUndo: widget.multiPoint && _points.isNotEmpty
                  ? () => setState(() => _points.removeLast())
                  : null,
              onClear: widget.multiPoint && _points.isNotEmpty
                  ? () => setState(() => _points.clear())
                  : null,
              onConfirm: _confirm,
            ),
          ),
        ],
      ),
    );
  }

  Marker _dotMarker(LatLng p, Color accent) {
    return Marker(
      point: p,
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withOpacity(.18)),
          ),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.3), blurRadius: 8)],
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.3), blurRadius: 6)],
        ),
        alignment: Alignment.center,
        child: Text(
          '$number',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String text;
  const _InfoChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.66),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.accent, required this.onTap});

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
          color: Colors.black.withOpacity(.66),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(.30)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final bool multiPoint;
  final LatLng? selected;
  final int pointsCount;
  final bool canConfirm;
  final String labelSelected;
  final String labelNone;
  final String labelPoints;
  final String labelConfirm;
  final String labelUndo;
  final String labelClear;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;
  final VoidCallback onConfirm;

  const _BottomPanel({
    required this.isDark,
    required this.accent,
    required this.multiPoint,
    required this.selected,
    required this.pointsCount,
    required this.canConfirm,
    required this.labelSelected,
    required this.labelNone,
    required this.labelPoints,
    required this.labelConfirm,
    required this.labelUndo,
    required this.labelClear,
    required this.onUndo,
    required this.onClear,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    String infoText;
    if (multiPoint) {
      infoText = '$labelPoints: $pointsCount';
    } else if (selected != null) {
      infoText =
          '$labelSelected:\n${selected!.latitude.toStringAsFixed(6)}, ${selected!.longitude.toStringAsFixed(6)}';
    } else {
      infoText = labelNone;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .35 : .12),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            infoText,
            style: TextStyle(color: text, fontSize: 13.5, fontWeight: FontWeight.w800, height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (multiPoint) ...[
                _SmallBtn(
                  label: labelUndo,
                  icon: Icons.undo_rounded,
                  color: muted,
                  textColor: text,
                  onTap: onUndo,
                ),
                const SizedBox(width: 8),
                _SmallBtn(
                  label: labelClear,
                  icon: Icons.delete_outline_rounded,
                  color: muted,
                  textColor: text,
                  onTap: onClear,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: isDark ? DhakkerColors.bg : Colors.white,
                    disabledBackgroundColor: accent.withOpacity(.35),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: canConfirm ? onConfirm : null,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    labelConfirm,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
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
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  const _SmallBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: BorderSide(color: color.withOpacity(.5)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: enabled
            ? () {
                HapticFeedback.lightImpact();
                onTap!();
              }
            : null,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
      ),
    );
  }
}
