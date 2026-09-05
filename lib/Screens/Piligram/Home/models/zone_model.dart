import 'package:cloud_firestore/cloud_firestore.dart';

class ZonePoint {
  final double lat;
  final double lng;

  const ZonePoint({
    required this.lat,
    required this.lng,
  });

  factory ZonePoint.fromMap(Map<String, dynamic> map) {
    return ZonePoint(
      lat: (map['lat'] ?? 0).toDouble(),
      lng: (map['lng'] ?? 0).toDouble(),
    );
  }
}

class ZoneModel {
  final String zoneId;

  /// معرّف ثابت مقروء (slug) مثل `mataf` / `hajar_aswad`.
  ///
  /// نستعمله لربط النصوص بالمواضع بدل الاسم العربي القابل للتعديل من لوحة
  /// الإدارة: تغيير `nameAr` يجب ألا يفصل الدعاء عن موضعه. يبقى `zoneId`
  /// المفتاح الأساسي في Firestore، و`zoneKey` هو الرابط الدلالي المستقر.
  final String zoneKey;

  final String nameAr;
  final String nameEn;
  final String type;
  final double? centerLat;
  final double? centerLng;
  final double? radiusM;
  final List<ZonePoint> polygonPoints;
  final int priority;
  final bool isActive;
  final Timestamp? updatedAt;

  const ZoneModel({
    required this.zoneId,
    this.zoneKey = '',
    required this.nameAr,
    required this.nameEn,
    required this.type,
    required this.centerLat,
    required this.centerLng,
    required this.radiusM,
    required this.polygonPoints,
    required this.priority,
    required this.isActive,
    required this.updatedAt,
  });

  // الـ Getters المضافة خصيصاً لمطابقة كود الخريطة وحل الأخطاء
  double get latitude => centerLat ?? 0.0;
  double get longitude => centerLng ?? 0.0;
  double get radius => radiusM ?? 0.0;

  factory ZoneModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final centerRaw = data['center'];
    double? safeDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    int safeInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    Map<String, dynamic> centerMap = {};
    if (centerRaw is Map<String, dynamic>) {
      centerMap = centerRaw;
    } else if (centerRaw is Map) {
      centerMap = Map<String, dynamic>.from(centerRaw);
    }

    final pointsRaw = data['points'];
    final points = <ZonePoint>[];

    if (pointsRaw is List) {
      for (final item in pointsRaw) {
        if (item is Map<String, dynamic>) {
          points.add(ZonePoint.fromMap(item));
        } else if (item is Map) {
          points.add(ZonePoint.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return ZoneModel(
      zoneId: (data['zoneId'] ?? doc.id).toString(),
      zoneKey: (data['zoneKey'] ?? '').toString().trim(),
      nameAr: (data['nameAr'] ?? '').toString(),
      nameEn: (data['nameEn'] ?? '').toString(),
      type: (data['type'] ?? 'circle').toString(),
      centerLat: safeDouble(centerMap['lat']),
      centerLng: safeDouble(centerMap['lng']),
      radiusM: safeDouble(data['radiusM']),
      polygonPoints: points,
      priority: safeInt(data['priority']),
      isActive: data['isActive'] ?? true,
      updatedAt: data['updatedAt'] is Timestamp
          ? data['updatedAt'] as Timestamp
          : null,
    );
  }

  String displayName(String langCode) {
    if (langCode == 'ar') {
      return nameAr.isNotEmpty ? nameAr : nameEn;
    }
    return nameEn.isNotEmpty ? nameEn : nameAr;
  }
}
