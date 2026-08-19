import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/supplication_model.dart';

class SupplicationService {
  final FirebaseFirestore firestore;

  final Map<String, List<SupplicationModel>> _zoneCache = {};

  SupplicationService({required this.firestore});

  static String _prefKey(String zoneId) => 'duas_cache_$zoneId';

  Future<List<SupplicationModel>> getSupplicationsByZone(String zoneId) async {
    if (_zoneCache.containsKey(zoneId)) return _zoneCache[zoneId]!;

    // أولاً: جرّب Firestore.
    try {
      final query = await firestore
          .collection('supplications')
          .where('zoneId', isEqualTo: zoneId)
          .where('isActive', isEqualTo: true)
          .get();

      final items = query.docs.map(SupplicationModel.fromFirestore).toList();
      items.sort((a, b) => b.usageCount.compareTo(a.usageCount));
      _zoneCache[zoneId] = items;

      // احفظ في SharedPreferences للاستخدام offline.
      _persistToCache(zoneId, items);
      return items;
    } catch (_) {}

    // ثانياً: إذا فشل Firestore (بدون نت) → ارجع للكاش المحلي.
    final cached = await _loadFromCache(zoneId);
    if (cached != null) {
      _zoneCache[zoneId] = cached;
      return cached;
    }

    return [];
  }

  Future<void> _persistToCache(
      String zoneId, List<SupplicationModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(items.map((e) => e.toJson()).toList());
      await prefs.setString(_prefKey(zoneId), json);
    } catch (_) {}
  }

  Future<List<SupplicationModel>?> _loadFromCache(String zoneId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey(zoneId));
      if (raw == null) return null;
      final list = (jsonDecode(raw) as List)
          .map((e) =>
              SupplicationModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return list;
    } catch (_) {
      return null;
    }
  }

  SupplicationModel? pickBestSupplication({
    required List<SupplicationModel> items,
    required String langCode,
  }) {
    if (items.isEmpty) return null;

    for (final item in items) {
      if (item.supportsLanguage(langCode) &&
          item.textByLanguage(langCode).trim().isNotEmpty) {
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
