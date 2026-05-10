import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/zone_model.dart';

class ZoneDetectionService {
  const ZoneDetectionService();

  bool isInsideCircle({
    required double userLat,
    required double userLng,
    required ZoneModel zone,
  }) {
    if (zone.centerLat == null || zone.centerLng == null || zone.radiusM == null) {
      return false;
    }

    final distance = Geolocator.distanceBetween(
      userLat,
      userLng,
      zone.centerLat!,
      zone.centerLng!,
    );

    return distance <= zone.radiusM!;
  }

  bool isInsidePolygon({
    required double userLat,
    required double userLng,
    required ZoneModel zone,
  }) {
    if (zone.polygonPoints.length < 3) {
      return false;
    }

    bool inside = false;
    int j = zone.polygonPoints.length - 1;

    for (int i = 0; i < zone.polygonPoints.length; i++) {
      final xi = zone.polygonPoints[i].lng;
      final yi = zone.polygonPoints[i].lat;
      final xj = zone.polygonPoints[j].lng;
      final yj = zone.polygonPoints[j].lat;

      final intersect = ((yi > userLat) != (yj > userLat)) &&
          (userLng < (xj - xi) * (userLat - yi) / ((yj - yi) == 0 ? 0.0000001 : (yj - yi)) + xi);

      if (intersect) {
        inside = !inside;
      }

      j = i;
    }

    return inside;
  }

  ZoneModel? detectBestZone({
    required double userLat,
    required double userLng,
    required List<ZoneModel> zones,
  }) {
    final matches = <ZoneModel>[];

    for (final zone in zones) {
      if (!zone.isActive) continue;

      bool isMatch = false;

      if (zone.type == 'polygon') {
        isMatch = isInsidePolygon(
          userLat: userLat,
          userLng: userLng,
          zone: zone,
        );

        debugPrint(
          'DHKKR_ZONE_CHECK => zone=${zone.zoneId}, type=${zone.type}, matched=$isMatch',
        );
      } else {
        if (zone.centerLat != null && zone.centerLng != null && zone.radiusM != null) {
          final distance = Geolocator.distanceBetween(
            userLat,
            userLng,
            zone.centerLat!,
            zone.centerLng!,
          );

          isMatch = distance <= zone.radiusM!;

          debugPrint(
            'DHKKR_ZONE_CHECK => zone=${zone.zoneId}, type=${zone.type}, distance=$distance, radius=${zone.radiusM}, matched=$isMatch',
          );
        } else {
          debugPrint(
            'DHKKR_ZONE_CHECK => zone=${zone.zoneId}, type=${zone.type}, missing center or radius',
          );
        }
      }

      if (isMatch) {
        matches.add(zone);
      }
    }

    if (matches.isEmpty) return null;

    matches.sort((a, b) => b.priority.compareTo(a.priority));

    debugPrint('DHKKR_ZONE_CHECK => bestZone=${matches.first.zoneId}');
    return matches.first;
  }
}