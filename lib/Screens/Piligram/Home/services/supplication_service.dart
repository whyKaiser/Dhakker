import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/supplication_model.dart';

class SupplicationService {
  final FirebaseFirestore firestore;

  final Map<String, List<SupplicationModel>> _zoneCache = {};

  SupplicationService({required this.firestore});

  static String _prefKey(String cacheKey) => 'duas_cache_$cacheKey';

  /// يجلب نصوص المنطقة.
  ///
  /// [zoneKey] هو المعرّف الثابت (slug) للمنطقة، وهو الرابط المفضَّل: السجلات
  /// المستوردة من حزم المصادر تحمل `zoneKey` ولا تحمل بالضرورة `zoneId`
  /// الخاص بهذا المشروع. نستعلم به أولًا، ثم نرجع إلى `zoneId` للسجلات
  /// القديمة. النتيجتان تُدمجان بلا تكرار حتى لا يختفي أي نوع من السجلات.
  Future<List<SupplicationModel>> getSupplicationsByZone(
    String zoneId, {
    String zoneKey = '',
  }) async {
    final cacheKey = zoneKey.trim().isNotEmpty ? zoneKey.trim() : zoneId;
    if (_zoneCache.containsKey(cacheKey)) return _zoneCache[cacheKey]!;

    // أولاً: جرّب Firestore.
    try {
      final byId = <String, SupplicationModel>{};

      if (zoneKey.trim().isNotEmpty) {
        final keyQuery = await firestore
            .collection('supplications')
            .where('zoneKey', isEqualTo: zoneKey.trim())
            .where('isActive', isEqualTo: true)
            .get();
        for (final doc in keyQuery.docs) {
          final item = SupplicationModel.fromFirestore(doc);
          byId[item.duaId.isNotEmpty ? item.duaId : doc.id] = item;
        }
      }

      if (zoneId.trim().isNotEmpty) {
        final idQuery = await firestore
            .collection('supplications')
            .where('zoneId', isEqualTo: zoneId)
            .where('isActive', isEqualTo: true)
            .get();
        for (final doc in idQuery.docs) {
          final item = SupplicationModel.fromFirestore(doc);
          byId.putIfAbsent(item.duaId.isNotEmpty ? item.duaId : doc.id, () => item);
        }
      }

      final items = byId.values.toList();
      items.sort((a, b) => b.usageCount.compareTo(a.usageCount));
      _zoneCache[cacheKey] = items;

      // احفظ في SharedPreferences للاستخدام offline.
      _persistToCache(cacheKey, items);
      return items;
    } catch (_) {}

    // ثانياً: إذا فشل Firestore (بدون نت) → ارجع للكاش المحلي.
    final cached = await _loadFromCache(cacheKey);
    if (cached != null) {
      _zoneCache[cacheKey] = cached;
      return cached;
    }

    return [];
  }

  Future<void> _persistToCache(String cacheKey, List<SupplicationModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(items.map((e) => e.toJson()).toList());
      await prefs.setString(_prefKey(cacheKey), json);
    } catch (_) {}
  }

  Future<List<SupplicationModel>?> _loadFromCache(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey(cacheKey));
      if (raw == null) return null;
      final list = (jsonDecode(raw) as List)
          .map((e) => SupplicationModel.fromJson(Map<String, dynamic>.from(e as Map)))
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