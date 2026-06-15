import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/supplication_model.dart';

class SupplicationService {
  final FirebaseFirestore firestore;

  final Map<String, List<SupplicationModel>> _zoneCache = {};

  SupplicationService({
    required this.firestore,
  });

  Future<List<SupplicationModel>> getSupplicationsByZone(String zoneId) async {
    if (_zoneCache.containsKey(zoneId)) {
      return _zoneCache[zoneId]!;
    }

    final query = await firestore
        .collection('supplications')
        .where('zoneId', isEqualTo: zoneId)
        .where('isActive', isEqualTo: true)
        .get();

    final items = query.docs.map(SupplicationModel.fromFirestore).toList();

    // التعديل هنا: الترتيب تنازلياً بناءً على عداد التشغيل (usage_count)
    items.sort((a, b) {
      // جلب عدد مرات التشغيل (ووضع صفر كقيمة افتراضية إذا لم يكن موجوداً)
      final aCount = a.usageCount;
      final bCount = b.usageCount;

      return bCount.compareTo(aCount); // ترتيب تنازلي
    });

    _zoneCache[zoneId] = items;
    return items;
  }

  SupplicationModel? pickBestSupplication({
    required List<SupplicationModel> items,
    required String langCode,
  }) {
    if (items.isEmpty) return null;

    for (final item in items) {
      if (item.supportsLanguage(langCode) && item.textByLanguage(langCode).trim().isNotEmpty) {
        return item;
      }
    }

    for (final item in items) {
      if (item.textByLanguage(langCode).trim().isNotEmpty) {
        return item;
      }
    }

    return items.first;
  }
}