import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../home/models/zone_model.dart';

class MapZoneRenderer {
  final Color baseGold;
  final Color highlightColor;

  const MapZoneRenderer({
    required this.baseGold,
    required this.highlightColor,
  });

  List<CircleMarker> buildCircleZones({
    required List<ZoneModel> zones,
    required String? activeZoneId,
  }) {
    final items = <CircleMarker>[];

    for (final zone in zones) {
      if (!zone.isActive || zone.type != 'circle') continue;
      if (zone.centerLat == null || zone.centerLng == null || zone.radiusM == null) continue;

      final isActiveZone = zone.zoneId == activeZoneId;
      final color = isActiveZone ? highlightColor : baseGold;

      items.add(
        CircleMarker(
          point: LatLng(zone.centerLat!, zone.centerLng!),
          radius: zone.radiusM!,
          useRadiusInMeter: true,
          color: color.withOpacity(isActiveZone ? 0.18 : 0.09),
          borderColor: color.withOpacity(isActiveZone ? 0.92 : 0.40),
          borderStrokeWidth: isActiveZone ? 3 : 2,
        ),
      );
    }

    return items;
  }

  List<Polygon> buildPolygonZones({
    required List<ZoneModel> zones,
    required String? activeZoneId,
  }) {
    final items = <Polygon>[];

    for (final zone in zones) {
      if (!zone.isActive || zone.type != 'polygon') continue;
      if (zone.polygonPoints.length < 3) continue;

      final isActiveZone = zone.zoneId == activeZoneId;
      final color = isActiveZone ? highlightColor : baseGold;

      items.add(
        Polygon(
          points: zone.polygonPoints
              .map((e) => LatLng(e.lat, e.lng))
              .toList(),
          color: color.withOpacity(isActiveZone ? 0.18 : 0.09),
          borderColor: color.withOpacity(isActiveZone ? 0.95 : 0.42),
          borderStrokeWidth: isActiveZone ? 3 : 2,
        ),
      );
    }

    return items;
  }

  Marker? buildZoneLabelMarker({
    required ZoneModel zone,
    required String label,
    required bool isActive,
  }) {
    LatLng? point;

    if (zone.type == 'circle' && zone.centerLat != null && zone.centerLng != null) {
      point = LatLng(zone.centerLat!, zone.centerLng!);
    } else if (zone.type == 'polygon' && zone.polygonPoints.isNotEmpty) {
      final avgLat =
          zone.polygonPoints.map((e) => e.lat).reduce((a, b) => a + b) / zone.polygonPoints.length;
      final avgLng =
          zone.polygonPoints.map((e) => e.lng).reduce((a, b) => a + b) / zone.polygonPoints.length;
      point = LatLng(avgLat, avgLng);
    }

    if (point == null) return null;

    return Marker(
      point: point,
      width: 130,
      height: 56,
      child: _ZoneChip(
        label: label,
        isActive: isActive,
        baseGold: baseGold,
        highlightColor: highlightColor,
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color baseGold;
  final Color highlightColor;

  const _ZoneChip({
    required this.label,
    required this.isActive,
    required this.baseGold,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? highlightColor : baseGold;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(isActive ? .72 : .58),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withOpacity(isActive ? .90 : .28),
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.34),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
            if (isActive)
              BoxShadow(
                color: color.withOpacity(.16),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
          ],
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}