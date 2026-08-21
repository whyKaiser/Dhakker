import 'package:cloud_firestore/cloud_firestore.dart';

/// كيف يُصنَّف محتوى السجل، وكيف يجب أن يُعرض للحاج.
///
/// هذا التصنيف ليس تجميليًّا: الخلط بين «إرشاد» و«دعاء» يوهم الحاج بأن جملة
/// مثل «لا يصح الطواف من داخل الحِجْر» ذكرٌ يُتلىٰ، والخلط بين «دعاء عام»
/// و«نص خاص بالموضع» ينسب إلى المصدر تخصيصًا لم يذكره. الواجهة ملزمة
/// بالتفريق بينها (انظر [SupplicationContentKindX]).
enum SupplicationContentKind {
  /// ذكر أو نص يربطه المصدر صراحةً بهذا الموضع أو النُّسك.
  specificText,

  /// دعاء عام يجوز قوله في أي موضع — المصدر لا يخصّه بهذا المكان.
  generalDua,

  /// ذكر عام غير مخصّص بموضع.
  generalDhikr,

  /// نص دخول المسجد — عام لكل المساجد بنص المصدر، لا خاص بموضع بعينه.
  mosqueEntry,

  /// إرشاد عملي أو حكم — **ليس دعاءً يُتلىٰ**، ويجب ألا يُعرض تحت عنوان دعاء.
  proceduralGuidance;

  static SupplicationContentKind fromRaw(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'specific_text':
        return SupplicationContentKind.specificText;
      case 'general_dhikr':
        return SupplicationContentKind.generalDhikr;
      case 'mosque_entry':
        return SupplicationContentKind.mosqueEntry;
      case 'procedural_guidance':
        return SupplicationContentKind.proceduralGuidance;
      case 'general_dua':
        return SupplicationContentKind.generalDua;
      default:
        // الافتراض الآمن: سجل قديم بلا تصنيف يُعامَل كدعاء عام، فلا يُنسب
        // للموضع ولا يُقدَّم كنص خاص.
        return SupplicationContentKind.generalDua;
    }
  }

  String get raw {
    switch (this) {
      case SupplicationContentKind.specificText:
        return 'specific_text';
      case SupplicationContentKind.generalDua:
        return 'general_dua';
      case SupplicationContentKind.generalDhikr:
        return 'general_dhikr';
      case SupplicationContentKind.mosqueEntry:
        return 'mosque_entry';
      case SupplicationContentKind.proceduralGuidance:
        return 'procedural_guidance';
    }
  }
}

extension SupplicationContentKindX on SupplicationContentKind {
  /// هل هذا نص يُتلىٰ (دعاء/ذكر)؟ الإرشاد ليس كذلك.
  bool get isRecitable => this != SupplicationContentKind.proceduralGuidance;

  /// هل يجوز عرضه في قسم «الأدعية»؟ الإرشاد يُعرض في بطاقة منفصلة.
  bool get belongsInDuaSection => isRecitable;

  /// هل يربطه المصدر بهذا الموضع تحديدًا؟
  /// دخول المسجد ليس كذلك — المصدر ينص أنه عام لكل المساجد.
  bool get isTiedToLocation => this == SupplicationContentKind.specificText;

  /// نص الوسم الظاهر للحاج. لا يجوز حذفه للأنواع العامة.
  String badgeAr() {
    switch (this) {
      case SupplicationContentKind.specificText:
        return 'وارد في هذا الموضع';
      case SupplicationContentKind.generalDua:
        return 'دعاء عام — غير مخصوص بهذا الموضع';
      case SupplicationContentKind.generalDhikr:
        return 'ذكر عام — غير مخصوص بهذا الموضع';
      case SupplicationContentKind.mosqueEntry:
        return 'عام لدخول المساجد';
      case SupplicationContentKind.proceduralGuidance:
        return 'إرشاد — ليس دعاءً';
    }
  }
}

/// كيف يُستعمل النص، لا ما هو. منفصل عن [SupplicationContentKind] عمدًا:
/// ذاك يقول *نوع المحتوى*، وهذا يقول *صفة الاستعمال*.
///
/// **الغياب لا يعني الوجوب.** لا يوجد `mandatory` ولا `required` في هذا
/// التعداد، ولن يُضاف: أكثر نصوص الكتاب لم يصفها المصدر بلزوم ولا بجواز،
/// فوسمها «واجبة» لمجرد خلوّها من وصف يُلبِس الحاج حكمًا لم يقله أحد.
/// السجل بلا qualifier يُعرض بلا أي وصف إلزامي — نصًّا كما ورد.
enum SupplicationUsageQualifier {
  /// زيادة يذكرها المصدر بصيغة الجواز («وإن زاد … فلا بأس»).
  /// تُعرض بشارتها، ولا تدخل التشغيل التلقائي، ولا تُدمج بالنص الأساسي.
  optionalAddition;

  /// القيم المدعومة اليوم. قيمة غير معروفة تُقرأ `null` — أي «بلا وصف»،
  /// وهو الافتراض الآمن: لا نخترع صفة لسجل لا نفهم وسمه.
  static SupplicationUsageQualifier? fromRaw(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'optional_addition':
        return SupplicationUsageQualifier.optionalAddition;
      default:
        return null;
    }
  }

  String get raw {
    switch (this) {
      case SupplicationUsageQualifier.optionalAddition:
        return 'optional_addition';
    }
  }

  String badgeAr() {
    switch (this) {
      case SupplicationUsageQualifier.optionalAddition:
        return 'زيادة جائزة';
    }
  }

  String badgeEn() {
    switch (this) {
      case SupplicationUsageQualifier.optionalAddition:
        return 'Optional addition';
    }
  }

  /// هل يدخل هذا السجل التشغيل التلقائي عند دخول المنطقة؟
  /// الزيادة الجائزة لا تُقرأ إلا باختيار المستخدم.
  bool get isAutoPlayable {
    switch (this) {
      case SupplicationUsageQualifier.optionalAddition:
        return false;
    }
  }
}

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

  /// تصنيف المحتوى — يقرّر كيف يُعرض (دعاء/ذكر/إرشاد) وهل يُنسب للموضع.
  final SupplicationContentKind contentKind;

  /// معرّف المنطقة الثابت (slug) — آمن للربط بخلاف الاسم القابل للتغيير.
  final String zoneKey;

  /// موثّق بمصدر معتمد؟ لا يُستشهد به في المساعد إلا إذا كان true.
  final bool isVerifiedSource;

  /// صفة الاستعمال إن وصفها المصدر. `null` = لم يصفه المصدر بشيء،
  /// **لا** أنه واجب. انظر [SupplicationUsageQualifier].
  final SupplicationUsageQualifier? usageQualifier;

  /// النُّسك الذي يرتبط به النص (مثل `ihram`) حين لا يكون مرتبطًا بموضع.
  /// التلبية مثالها: لا تخصّ ميقاتًا بعينه، بل تخصّ الإحرام.
  final String ritualKey;

  /// المناطق التي ينطبق عليها نصٌّ مرتبط بنُسك. فارغة = لا قيد إضافي.
  final List<String> appliesToZoneKeys;

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
    this.contentKind = SupplicationContentKind.generalDua,
    this.zoneKey = '',
    this.isVerifiedSource = false,
    this.usageQualifier,
    this.ritualKey = '',
    this.appliesToZoneKeys = const [],
  });

  /// هل يُشغَّل تلقائيًّا عند دخول المنطقة؟ يجمع الشرطين: أن يكون نصًّا
  /// يُتلىٰ أصلًا (لا إرشادًا)، وألا تمنعه صفة استعماله.
  bool get isAutoPlayable =>
      contentKind.belongsInDuaSection &&
      (usageQualifier?.isAutoPlayable ?? true);

  /// هل ينطبق هذا السجل على المنطقة المعطاة؟
  ///
  /// السجل المرتبط بنُسك (مثل التلبية، `ritualKey: ihram`) لا يحمل zoneKey —
  /// فربطه بميقات واحد يخفيه عن بقية المواقيت. تحديد انطباقه يمرّ عبر
  /// [appliesToZoneKeys]، وقائمةٌ غير فارغة تعني: هنا فقط، ولا شيء سواه.
  bool appliesToZone(String candidateZoneKey) {
    final key = candidateZoneKey.trim();
    if (appliesToZoneKeys.isNotEmpty) return appliesToZoneKeys.contains(key);
    if (zoneKey.trim().isNotEmpty) return zoneKey.trim() == key;
    return false;
  }

  factory SupplicationModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    Map<String, String> safeTextMap(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        return raw
            .map((key, value) => MapEntry(key.toString(), value.toString()));
      }
      if (raw is Map) {
        return Map<String, String>.from(
          raw.map((key, value) => MapEntry(key.toString(), value.toString())),
        );
      }
      return {};
    }

    List<String> safeStringList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
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
      updatedAt: data['updatedAt'] is Timestamp
          ? data['updatedAt'] as Timestamp
          : null,
      // 3. قراءة الحقل من قاعدة البيانات مع إعطائه قيمة 0 افتراضياً
      usageCount: (data['usage_count'] as num?)?.toInt() ?? 0,
      contentKind:
          SupplicationContentKind.fromRaw(data['contentKind']?.toString()),
      zoneKey: (data['zoneKey'] ?? '').toString(),
      isVerifiedSource:
          (data['verificationStatus'] ?? '').toString().trim() == 'verified' &&
              data['revokedAt'] == null,
      usageQualifier: SupplicationUsageQualifier.fromRaw(
          data['usageQualifier']?.toString()),
      ritualKey: (data['ritualKey'] ?? '').toString().trim(),
      appliesToZoneKeys: safeStringList(data['appliesToZoneKeys']),
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

  Map<String, dynamic> toJson() => {
        'duaId': duaId,
        'zoneId': zoneId,
        'title': title,
        'text': text,
        'audioMode': audioMode,
        'audioUrl': audioUrl,
        'languageCodes': languageCodes,
        'isActive': isActive,
        'usage_count': usageCount,
        'contentKind': contentKind.raw,
        'zoneKey': zoneKey,
        // Passed through explicitly, never spread: a field that is only
        // carried by accident is a field that gets dropped by accident.
        // `null` is preserved as null — it means "the source described no
        // usage", which is not the same as any value we could invent.
        'usageQualifier': usageQualifier?.raw,
        'ritualKey': ritualKey,
        'appliesToZoneKeys': appliesToZoneKeys,
      };

  factory SupplicationModel.fromJson(Map<String, dynamic> data) {
    Map<String, String> safeMap(dynamic raw) {
      if (raw is Map) {
        return Map<String, String>.from(
          raw.map((k, v) => MapEntry(k.toString(), v.toString())),
        );
      }
      return {};
    }

    List<String> safeStringList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    final langs = <String>[];
    final rawLangs = data['languageCodes'];
    if (rawLangs is List) {
      for (final item in rawLangs) {
        langs.add(item.toString());
      }
    }

    return SupplicationModel(
      duaId: (data['duaId'] ?? '').toString(),
      zoneId: (data['zoneId'] ?? '').toString(),
      title: safeMap(data['title']),
      text: safeMap(data['text']),
      audioMode: (data['audioMode'] ?? 'tts').toString(),
      audioUrl: (data['audioUrl'] ?? '').toString(),
      languageCodes: langs,
      isActive: data['isActive'] ?? true,
      updatedAt: null,
      usageCount: (data['usage_count'] as num?)?.toInt() ?? 0,
      contentKind:
          SupplicationContentKind.fromRaw(data['contentKind']?.toString()),
      zoneKey: (data['zoneKey'] ?? '').toString(),
      isVerifiedSource:
          (data['verificationStatus'] ?? '').toString().trim() == 'verified' &&
              data['revokedAt'] == null,
      usageQualifier: SupplicationUsageQualifier.fromRaw(
          data['usageQualifier']?.toString()),
      ritualKey: (data['ritualKey'] ?? '').toString().trim(),
      appliesToZoneKeys: safeStringList(data['appliesToZoneKeys']),
    );
  }
}
