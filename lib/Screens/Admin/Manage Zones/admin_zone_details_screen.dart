import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhakker/admin_bloc/admin_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../generated/l10n.dart';
import '../../../theme/dhakker_theme.dart';
import '../Manage Supplications/AdminSupplicationsList_Screen.dart';

class AdminZoneDetailsScreen extends StatefulWidget {
  final String zoneId;

  const AdminZoneDetailsScreen({
    super.key,
    required this.zoneId,
  });

  @override
  State<AdminZoneDetailsScreen> createState() => _AdminZoneDetailsScreenState();
}

class _AdminZoneDetailsScreenState extends State<AdminZoneDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _zoneData;

  @override
  void initState() {
    super.initState();
    _loadZone();
  }

  Future<void> _loadZone() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('zones')
          .doc(widget.zoneId)
          .get();

      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).adminZoneDetailsNotFound),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        Navigator.pop(context);
        return;
      }

      if (!mounted) return;
      setState(() {
        _zoneData = doc.data();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).adminZoneDetailsLoadError),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final text = isDark ? Colors.white : DhakkerColors.lightText;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: text,
        title: Text(
          s.adminZoneDetailsTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const _ZoneDetailsLoadingView()
            : _zoneData == null
            ? const SizedBox.shrink()
            : _ZoneDetailsBody(
          zoneId: widget.zoneId,
          data: _zoneData!,
        ),
      ),
    );
  }
}

class _ZoneDetailsBody extends StatelessWidget {
  final String zoneId;
  final Map<String, dynamic> data;

  const _ZoneDetailsBody({
    required this.zoneId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';

    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    final name = isAr
        ? (data['nameAr'] ?? data['nameEn'] ?? '').toString().trim()
        : (data['nameEn'] ?? data['nameAr'] ?? '').toString().trim();

    final type = (data['type'] ?? '').toString().trim().toLowerCase();
    final isActive = data['isActive'] == true;
    final priority = data['priority'];

    final center = data['center'];
    final centerLat = _toDouble(center is Map ? center['lat'] : null);
    final centerLng = _toDouble(center is Map ? center['lng'] : null);
    final radiusM = _toDouble(data['radiusM']);
    final points = _extractPoints(data['points']);

    final typeLabel = type == 'circle'
        ? s.adminZoneDetailsTypeCircle
        : type == 'polygon'
        ? s.adminZoneDetailsTypePolygon
        : '—';

    final statusLabel = isActive
        ? s.adminZoneDetailsStatusActive
        : s.adminZoneDetailsStatusInactive;

    return Container(
      color: bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionTitle(title: s.adminZoneDetailsOverviewTitle),
            const SizedBox(height: 12),
            _HeroInfoCard(
              title: name.isEmpty ? '—' : name,
              typeLabel: typeLabel,
              statusLabel: statusLabel,
              priority: priority?.toString() ?? '—',
            ),
            const SizedBox(height: 18),
            _SectionTitle(title: s.adminZoneDetailsMapTitle),
            const SizedBox(height: 12),
            _ZoneMapCard(
              zoneName: name,
              type: type,
              centerLat: centerLat,
              centerLng: centerLng,
              radiusM: radiusM,
              points: points,
            ),
            const SizedBox(height: 18),
            _SectionTitle(title: s.adminZoneDetailsInfoTitle),
            const SizedBox(height: 12),
            _DetailsCard(
              children: [
                _InfoRow(
                  label: s.adminZoneDetailsNameAr,
                  value: (data['nameAr'] ?? '').toString().trim().isEmpty
                      ? '—'
                      : (data['nameAr'] ?? '').toString().trim(),
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: s.adminZoneDetailsNameEn,
                  value: (data['nameEn'] ?? '').toString().trim().isEmpty
                      ? '—'
                      : (data['nameEn'] ?? '').toString().trim(),
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: s.adminZoneDetailsTypeLabel,
                  value: typeLabel,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: s.adminZoneDetailsPriorityLabel,
                  value: priority?.toString() ?? '—',
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: s.adminZoneDetailsStatusLabel,
                  value: statusLabel,
                ),
                if (type == 'circle') ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    label: s.adminZoneDetailsCenterLatLabel,
                    value: centerLat?.toString() ?? '—',
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    label: s.adminZoneDetailsCenterLngLabel,
                    value: centerLng?.toString() ?? '—',
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    label: s.adminZoneDetailsRadiusLabel,
                    value: radiusM == null ? '—' : '${radiusM.toString()} m',
                  ),
                ],
                if (type == 'polygon') ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    label: s.adminZoneDetailsPointsCountLabel,
                    value: points.length.toString(),
                  ),
                ],
              ],
            ),
            if (type == 'polygon') ...[
              const SizedBox(height: 18),
              _SectionTitle(title: s.adminZoneDetailsPointsTitle),
              const SizedBox(height: 12),
              _PolygonPointsCard(points: points),
            ],
            const SizedBox(height: 18),
            _SectionTitle(title: s.adminZoneDetailsRelatedTitle),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('supplications')
                  .where('zoneId', isEqualTo: zoneId)
                  .snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                return _RelatedSupplicationsCard(
                  count: count,
                  onTap: () {

                    AdminCubit.get(context).changeScreen(2);

                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (_) => AdminSupplicationsListScreen(
                    //       initialZoneId: zoneId,
                    //     ),
                    //   ),
                    // );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              s.adminZoneDetailsHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted.withOpacity(.9),
                fontWeight: FontWeight.w700,
                fontSize: 12.3,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static List<LatLng> _extractPoints(dynamic raw) {
    if (raw is! List) return [];

    final points = <LatLng>[];
    for (final item in raw) {
      if (item is Map) {
        final lat = _toDouble(item['lat']);
        final lng = _toDouble(item['lng']);
        if (lat != null && lng != null) {
          points.add(LatLng(lat, lng));
        }
      }
    }
    return points;
  }
}

class _HeroInfoCard extends StatelessWidget {
  final String title;
  final String typeLabel;
  final String statusLabel;
  final String priority;

  const _HeroInfoCard({
    required this.title,
    required this.typeLabel,
    required this.statusLabel,
    required this.priority,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    final statusColor = statusLabel == s.adminZoneDetailsStatusActive
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);

    final typeColor = typeLabel == s.adminZoneDetailsTypeCircle
        ? const Color(0xFF2563EB)
        : const Color(0xFF7C3AED);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          right: BorderSide(
            color: accent.withOpacity(.55),
            width: 3,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .30 : .07),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: accent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStatBadge(
                  label: typeLabel,
                  color: typeColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatBadge(
                  label: statusLabel,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: (isDark ? Colors.white : Colors.black).withOpacity(.04),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withOpacity(.06),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '${s.adminZoneDetailsPriorityLabel}: ',
                  style: TextStyle(
                    color: muted.withOpacity(.95),
                    fontWeight: FontWeight.w800,
                    fontSize: 12.8,
                  ),
                ),
                Expanded(
                  child: Text(
                    priority,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: text,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneMapCard extends StatelessWidget {
  final String zoneName;
  final String type;
  final double? centerLat;
  final double? centerLng;
  final double? radiusM;
  final List<LatLng> points;

  const _ZoneMapCard({
    required this.zoneName,
    required this.type,
    required this.centerLat,
    required this.centerLng,
    required this.radiusM,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    final mapCenter = _buildMapCenter();
    final hasValidMap = mapCenter != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .30 : .07),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 310,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accent.withOpacity(.14),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasValidMap
                ? FlutterMap(
              options: MapOptions(
                initialCenter: mapCenter!,
                initialZoom: _initialZoom(),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.dhakker.app',
                  maxZoom: 19,
                ),
                if (type == 'circle' &&
                    centerLat != null &&
                    centerLng != null &&
                    radiusM != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: LatLng(centerLat!, centerLng!),
                        radius: radiusM!,
                        useRadiusInMeter: true,
                        color: accent.withOpacity(.18),
                        borderColor: accent,
                        borderStrokeWidth: 2.4,
                      ),
                    ],
                  ),
                if (type == 'polygon' && points.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: points,
                        color: accent.withOpacity(.18),
                        borderColor: accent,
                        borderStrokeWidth: 2.6,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: _markers(accent),
                ),
              ],
            )
                : _EmptyMapState(
              title: s.adminZoneDetailsMapUnavailableTitle,
              subtitle: s.adminZoneDetailsMapUnavailableSubtitle,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: (isDark ? Colors.white : Colors.black).withOpacity(.04),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withOpacity(.06),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: accent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    zoneName.isEmpty ? s.adminZoneDetailsZonePreview : zoneName,
                    style: TextStyle(
                      color: text,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  type == 'circle'
                      ? s.adminZoneDetailsTypeCircle
                      : s.adminZoneDetailsTypePolygon,
                  style: TextStyle(
                    color: muted.withOpacity(.95),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LatLng? _buildMapCenter() {
    if (type == 'circle' && centerLat != null && centerLng != null) {
      return LatLng(centerLat!, centerLng!);
    }

    if (type == 'polygon' && points.isNotEmpty) {
      double latSum = 0;
      double lngSum = 0;
      for (final p in points) {
        latSum += p.latitude;
        lngSum += p.longitude;
      }
      return LatLng(latSum / points.length, lngSum / points.length);
    }

    return null;
  }

  double _initialZoom() {
    if (type == 'circle') {
      if (radiusM == null) return 17;
      if (radiusM! <= 20) return 19;
      if (radiusM! <= 50) return 18;
      if (radiusM! <= 120) return 17;
      if (radiusM! <= 300) return 16;
      return 15;
    }

    if (type == 'polygon') return 17;

    return 16;
  }

  List<Marker> _markers(Color accent) {
    if (type == 'circle' && centerLat != null && centerLng != null) {
      return [
        Marker(
          point: LatLng(centerLat!, centerLng!),
          width: 54,
          height: 54,
          child: _MapPin(accent: accent),
        ),
      ];
    }

    if (type == 'polygon' && points.isNotEmpty) {
      return [
        Marker(
          point: points.first,
          width: 54,
          height: 54,
          child: _MapPin(accent: accent),
        ),
      ];
    }

    return [];
  }
}

class _MapPin extends StatelessWidget {
  final Color accent;

  const _MapPin({
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

class _EmptyMapState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyMapState({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    return Container(
      color: (isDark ? Colors.white : Colors.black).withOpacity(.03),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                color: accent,
                size: 34,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted.withOpacity(.92),
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final List<Widget> children;

  const _DetailsCard({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .30 : .07),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _PolygonPointsCard extends StatelessWidget {
  final List<LatLng> points;

  const _PolygonPointsCard({
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          s.adminZoneDetailsNoPoints,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .30 : .07),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: List.generate(points.length, (index) {
          final point = points[index];
          return Container(
            margin: EdgeInsets.only(bottom: index == points.length - 1 ? 0 : 10),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: (isDark ? Colors.white : Colors.black).withOpacity(.04),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withOpacity(.06),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: accent.withOpacity(.14),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lat: ${point.latitude}, Lng: ${point.longitude}',
                    style: TextStyle(
                      color: text,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.6,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _RelatedSupplicationsCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _RelatedSupplicationsCard({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border(
            right: BorderSide(
              color: accent.withOpacity(.55),
              width: 3,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? .30 : .07),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withOpacity(.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                color: accent,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.adminZoneDetailsRelatedSupplicationsButton,
                    style: TextStyle(
                      color: text,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.adminZoneDetailsRelatedCountLabel}: $count',
                    style: TextStyle(
                      color: muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: muted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniStatBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: muted.withOpacity(.95),
              fontSize: 12.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: text,
              fontSize: 12.8,
              fontWeight: FontWeight.w800,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: .1,
            ),
          ),
        ),
        Container(
          width: 26,
          height: 3,
          decoration: BoxDecoration(
            color: muted.withOpacity(.35),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }
}

class _ZoneDetailsLoadingView extends StatelessWidget {
  const _ZoneDetailsLoadingView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: Column(
        children: [
          const _SectionTitle(title: '...'),
          const SizedBox(height: 12),
          _LoadingCard(card: card, height: 150),
          const SizedBox(height: 18),
          const _SectionTitle(title: '...'),
          const SizedBox(height: 12),
          _LoadingCard(card: card, height: 360),
          const SizedBox(height: 18),
          const _SectionTitle(title: '...'),
          const SizedBox(height: 12),
          _LoadingCard(card: card, height: 200),
          const SizedBox(height: 18),
          const _SectionTitle(title: '...'),
          const SizedBox(height: 12),
          _LoadingCard(card: card, height: 96),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final Color card;
  final double height;

  const _LoadingCard({
    required this.card,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}