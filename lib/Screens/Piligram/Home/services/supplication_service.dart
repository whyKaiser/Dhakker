import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/supplication_model.dart';

/// لماذا عادت القائمة فارغة. `null` يعني «لم يفشل شيء — لا نصوص هنا فعلًا».
///
/// الفرق ليس تجميليًّا: فهرس غير جاهز، وقواعد ترفض الاستعلام، ومنطقة بلا
/// نصوص — ثلاثتها تنتج قائمة فارغة. بلا هذا التمييز يظهر عطل النشر كأنه
/// سلوك طبيعي، ولا يبقى له أثر يُشخَّص به.
class SupplicationQueryFailure {
  const SupplicationQueryFailure({
    required this.code,
    required this.cacheKey,
    required this.hint,
  });

  final String code;
  final String cacheKey;
  final String hint;

  @override
  String toString() => 'SupplicationQueryFailure($code, $cacheKey): $hint';
}

class SupplicationService {
  final FirebaseFirestore firestore;

  final Map<String, List<SupplicationModel>> _zoneCache = {};

  /// آخر فشل استعلام، أو `null` إن كان آخر جلب سليمًا. تقرؤه الواجهة
  /// لتفرّق بين «لا نصوص هنا» و«تعذّر الجلب».
  SupplicationQueryFailure? lastQueryFailure;

  SupplicationService({required this.firestore});

  static String _prefKey(String cacheKey) => 'duas_cache_$cacheKey';

  /// هل يجوز عرض هذا السجل للحاج؟ موثَّق، فعّال، غير ملغى.
  ///
  /// المرشِّح نفسه مطبَّق في ثلاثة مواضع مستقلة عمدًا: في `firestore.rules`
  /// (فلا يُقرأ أصلًا)، وفي كل استعلام (فلا يصل إلى الجهاز)، وهنا (فما
  /// حُفظ في الكاش أيام قاعدة أضعف لا يُعرض اليوم).
  static bool isDisplayable(SupplicationModel item) =>
      item.isActive && item.isVerifiedSource;

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
            .where('verificationStatus', isEqualTo: 'verified')
            .where('revokedAt', isNull: true)
            .get();
        for (final doc in keyQuery.docs) {
          final item = SupplicationModel.fromFirestore(doc);
          byId[item.duaId.isNotEmpty ? item.duaId : doc.id] = item;
        }
      }

      // ثالثًا — النصوص المرتبطة بنُسك لا بموضع.
      //
      // التلبية مثالها: `zoneKey: ""` و`zoneId: ""`، لأن المصدر يربطها
      // بالإحرام لا بميقات بعينه. فلا الاستعلام بـzoneKey ولا الاستعلام
      // بـzoneId يجدها — كانت تختفي عن **كل** ميقات. الحل ليس تثبيتها
      // بميقات واحد (فتختفي عن الاثنين الآخرين) بل الاستعلام بقائمة
      // المناطق التي ينطبق عليها النص.
      //
      // القيود الثلاثة إلزامية في الاستعلامات الثلاثة كلها: القواعد تُقيَّم
      // على كل مستند يطابق الاستعلام، فاستعلام لا يحملها يطابق سجلًا غير
      // موثّق ويفشل كاملًا بـ permission-denied. القواعد ليست مرشِّحًا.
      // ويحتاج كل مزيج منها فهرسًا مركّبًا (انظر firestore.indexes.json).
      if (zoneKey.trim().isNotEmpty) {
        final ritualQuery = await firestore
            .collection('supplications')
            .where('appliesToZoneKeys', arrayContains: zoneKey.trim())
            .where('isActive', isEqualTo: true)
            .where('verificationStatus', isEqualTo: 'verified')
            .where('revokedAt', isNull: true)
            .get();
        for (final doc in ritualQuery.docs) {
          final item = SupplicationModel.fromFirestore(doc);
          byId.putIfAbsent(item.duaId.isNotEmpty ? item.duaId : doc.id, () => item);
        }
      }

      if (zoneId.trim().isNotEmpty) {
        final idQuery = await firestore
            .collection('supplications')
            .where('zoneId', isEqualTo: zoneId)
            .where('isActive', isEqualTo: true)
            .where('verificationStatus', isEqualTo: 'verified')
            .where('revokedAt', isNull: true)
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
      lastQueryFailure = null;
      return items;
    } on FirebaseException catch (e) {
      // لا يُبتلع الفشل صامتًا.
      //
      // أخطر حالتين متشابهتان في النتيجة ومختلفتان تمامًا في السبب:
      //   failed-precondition → فهرس مركّب غير جاهز بعدُ (انظر
      //       firestore.indexes.json وترتيب النشر في docs/).
      //   permission-denied   → استعلام لا يحمل القيود الثلاثة، أو قواعد
      //       نُشرت قبل نسخة التطبيق التي تحملها.
      //
      // كلاهما يُنتج قائمة فارغة، وبلا هذا الأثر يبدوان «لا أدعية هنا».
      lastQueryFailure = SupplicationQueryFailure(
        code: e.code,
        cacheKey: cacheKey,
        // بلا نص الاستعلام ولا محتوى أي سجل — تشخيص لا تسريب.
        hint: e.code == 'failed-precondition'
            ? 'فهرس مركّب مفقود أو ما يزال يُبنى — انشر firestore.indexes.json وانتظر READY.'
            : e.code == 'permission-denied'
                ? 'القواعد ترفض الاستعلام: يجب أن يحمل isActive وverificationStatus وrevokedAt.'
                : 'فشل استعلام Firestore.',
      );
      debugPrint(
        '[supplications] query failed (${e.code}) for "$cacheKey": '
        '${lastQueryFailure!.hint}',
      );
      // لا ارتداد إلى بيانات غير موثّقة: الكاش نفسه مُرشَّح عند القراءة.
    } catch (e) {
      lastQueryFailure = SupplicationQueryFailure(
        code: 'unknown',
        cacheKey: cacheKey,
        hint: 'فشل غير متوقع أثناء جلب النصوص.',
      );
      debugPrint('[supplications] unexpected query failure for "$cacheKey": $e');
    }

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
      final json =
          jsonEncode(items.where(isDisplayable).map((e) => e.toJson()).toList());
      await prefs.setString(_prefKey(cacheKey), json);
    } catch (_) {}
  }

  Future<List<SupplicationModel>?> _loadFromCache(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey(cacheKey));
      if (raw == null) return null;
      // يُرشَّح عند القراءة لا عند الكتابة فقط: كاش كُتب بنسخة أقدم قد
      // يحوي سجلًا غير موثّق أو أُلغي بعد حفظه، وحذفه من الجهاز ليس بيدنا.
      // فالفلترة هنا هي ما يحمي الحاج من نصّ سُحب بعد أن خُزِّن عنده.
      final list = (jsonDecode(raw) as List)
          .map((e) => SupplicationModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .where(isDisplayable)
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