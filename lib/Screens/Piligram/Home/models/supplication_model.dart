import 'package:cloud_firestore/cloud_firestore.dart';

class SupplicationModel {
  final String duaId;
  final String zoneId;
  final Map<String, String> title;
  final Map<String, String> text;
  final String audioMode;
  final String audioUrl;
  final List<String> languageCodes;
  final bool isActive;
  final Timestamp? updatedAt;
  final int usageCount; // 1. إضافة المتغير الخاص بعداد التشغيل

  const SupplicationModel({
    required this.duaId,
    required this.zoneId,
    required this.title,
    required this.text,
    required this.audioMode,
    required this.audioUrl,
    required this.languageCodes,
    required this.isActive,
    required this.updatedAt,
    required this.usageCount, // 2. إضافته هنا
  });

  factory SupplicationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    Map<String, String> safeTextMap(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        return raw.map((key, value) => MapEntry(key.toString(), value.toString()));
      }
      if (raw is Map) {
        return Map<String, String>.from(
          raw.map((key, value) => MapEntry(key.toString(), value.toString())),
        );
      }
      return {};
    }

    final langs = <String>[];
    final rawLangs = data['languageCodes'];
    if (rawLangs is List) {
      for (final item in rawLangs) {
        langs.add(item.toString());
      }
    }

    return SupplicationModel(
      duaId: (data['duaId'] ?? doc.id).toString(),
      zoneId: (data['zoneId'] ?? '').toString(),
      title: safeTextMap(data['title']),
      text: safeTextMap(data['text']),
      audioMode: (data['audioMode'] ?? 'tts').toString(),
      audioUrl: (data['audioUrl'] ?? '').toString(),
      languageCodes: langs,
      isActive: data['isActive'] ?? true,
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] as Timestamp : null,
      // 3. قراءة الحقل من قاعدة البيانات مع إعطائه قيمة 0 افتراضياً
      usageCount: (data['usage_count'] as num?)?.toInt() ?? 0,
    );
  }

  String titleByLanguage(String langCode) {
    if (langCode == 'ar') {
      return (title['ar']?.trim().isNotEmpty ?? false)
          ? title['ar']!.trim()
          : (title['en'] ?? '');
    }
    return (title['en']?.trim().isNotEmpty ?? false)
        ? title['en']!.trim()
        : (title['ar'] ?? '');
  }

  String textByLanguage(String langCode) {
    if (langCode == 'ar') {
      return (text['ar']?.trim().isNotEmpty ?? false)
          ? text['ar']!.trim()
          : (text['en'] ?? '');
    }
    return (text['en']?.trim().isNotEmpty ?? false)
        ? text['en']!.trim()
        : (text['ar'] ?? '');
  }

  bool supportsLanguage(String langCode) {
    if (languageCodes.isEmpty) return true;
    return languageCodes.contains(langCode);
  }
}