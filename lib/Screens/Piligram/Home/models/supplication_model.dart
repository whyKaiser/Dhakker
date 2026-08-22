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
  proceduralGuidance,

  /// أثر أو حديث يسوقه المصدر **للتعليم والاستدلال**، لا للترديد.
  ///
  /// مثاله قول عمر رضي الله عنه عند الحجر: «إني أعلم أنك حجر…». هو نصّ
  /// مرويّ صحيح الإسناد، لكنه ليس ذكرًا يقوله الحاج، وليس إجراءً يتّبعه.
  /// عرضه دعاءً يجعل الحاج يردّده، وعرضه إرشادًا يطمس كونه أثرًا مرويًّا
  /// ويقدّمه كأنه صياغة إدارية. فله نوعه الخاص: بطاقة «أثر موثّق» تحفظ
  /// نسبته ومصدره، بلا زر تشغيل.
  contextualEvidence;

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
      case 'contextual_evidence':
        return SupplicationContentKind.contextualEvidence;
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
      case SupplicationContentKind.contextualEvidence:
        return 'contextual_evidence';
    }
  }
}

extension SupplicationContentKindX on SupplicationContentKind {
  /// هل هذا نص يُتلىٰ (دعاء/ذكر)؟
  ///
  /// الإرشاد ليس كذلك، والأثر التعليمي ليس كذلك أيضًا: صحّة الإسناد لا
  /// تجعل النص ذكرًا يقوله الحاج.
  bool get isRecitable =>
      this != SupplicationContentKind.proceduralGuidance &&
      this != SupplicationContentKind.contextualEvidence;

  /// هل يجوز عرضه في قسم «الأدعية»؟ ما ليس ذكرًا يُعرض في بطاقته الخاصة.
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
      case SupplicationContentKind.contextualEvidence:
        return 'أثر موثّق — للفائدة لا للترديد';
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

/// مرجع منسوب: ما عزا إليه **المصدر المطبوع**، لا ما نصادق نحن عليه.
///
/// [reference] اختياري عمدًا: صفحة تسمّي «الشافعي» بلا رقم تُسجَّل بلا رقم،
/// و`""` ممنوعة لأنها تُقرأ «بحثنا فلم نجد» وهو خبر لم نقله.
class SourceReference {
  const SourceReference({
    required this.type,
    required this.collection,
    required this.referenceKind,
    required this.citedBy,
    required this.citedOnPage,
    this.reference,
  });

  final String type;
  final String collection;
  final String referenceKind;
  final String citedBy;
  final int citedOnPage;
  final String? reference;

  /// «صحيح البخاري (1597)» أو «الشافعي» حين لا رقم.
  String get display {
    final r = reference?.trim() ?? '';
    return r.isEmpty ? collection : '$collection ($r)';
  }

  static List<SourceReference> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    final out = <SourceReference>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final collection = (m['collection'] ?? '').toString().trim();
      if (collection.isEmpty) continue;
      final ref = (m['reference'] ?? '').toString().trim();
      out.add(SourceReference(
        type: (m['type'] ?? '').toString().trim(),
        collection: collection,
        referenceKind: (m['referenceKind'] ?? 'unspecified').toString().trim(),
        citedBy: (m['citedBy'] ?? '').toString().trim(),
        citedOnPage: (m['citedOnPage'] as num?)?.toInt() ?? 0,
        // Absent stays absent: an empty string would claim something the
        // printed page did not say.
        reference: ref.isEmpty ? null : ref,
      ));
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'collection': collection,
        'referenceKind': referenceKind,
        'citedBy': citedBy,
        'citedOnPage': citedOnPage,
        if (reference != null) 'reference': reference,
      };
}

/// كيف يُؤدَّى النص: كم مرة، ومتى، وهل يتخلّله شيء.
///
/// منفصل عن [SupplicationUsageQualifier] عمدًا. ذاك يصف **صفة** النص
/// (زيادة جائزة)، وهذا يصف **كيفية أدائه** (مرة واحدة، ثلاث مرات بينها
/// دعاء). خلطهما في حقل واحد يجعل «جائز» و«ثلاث مرات» قيمتين متنافيتين
/// في خانة واحدة، وهما وصفان مستقلان قد يجتمعان.
///
/// **لا يجعل هذا الكائن نصًّا غيرَ متلوٍّ متلوًّا.** [SupplicationContentKind]
/// وحده يقرّر ذلك، ويبقى هو الحَكَم.
class RecitationPolicy {
  const RecitationPolicy({
    required this.frequency,
    this.repeatCount,
    this.trigger,
    this.interleave,
    this.autoRepeat = false,
    this.autoPlayCapability,
  });

  /// `once_per_ritual` أو `repeat_count`.
  final String frequency;

  /// عدد المرات — مع `repeat_count` فقط.
  final int? repeatCount;

  /// متى يُقال (قيم محصورة).
  final String? trigger;

  /// ما يتخلّل التكرار (قيم محصورة).
  final String? interleave;

  /// هل يُعاد تلقائيًّا؟ الافتراض `false`، ويلزم بقاؤه false مع [interleave]:
  /// تكرارٌ يتخلّله دعاء المرء لا يمكن أن يؤدّيه المشغّل عنه.
  final bool autoRepeat;

  /// قدرة التشغيل التلقائي المتاحة اليوم لهذا السجل.
  ///
  /// `manual_only_until_trigger_supported` تعني: **لا تشغيل تلقائي بحال**،
  /// لأن الحدث الذي يقتضيه [trigger] غير موجود في التطبيق بعد.
  ///
  /// مثاله `first_safa_approach`: منطقة `masaa` مضلّع واحد يغطي الممر كله،
  /// فدخولها لا يثبت أن الحاج عند الصفا أول مرة — قد يكون عند المروة أو في
  /// وسط المسعى. حاجز «مرة واحدة» يمنع التكرار ولا يثبت أن الأولى في محلّها.
  /// فالفشل المغلق: يُعرض النص ويشغّله الحاج بنفسه، ولا يُقرأ عليه بموقعه.
  ///
  /// تُكتب صراحةً في الحزمة، ولا تُستنتج من عنوان ولا من معرّف سجل.
  final String? autoPlayCapability;

  static const String manualOnlyUntilTriggerSupported =
      'manual_only_until_trigger_supported';

  /// هل يمنع هذا السجلُّ التشغيلَ التلقائي بنفسه؟
  bool get blocksAutoPlay =>
      autoPlayCapability == manualOnlyUntilTriggerSupported;

  bool get isOncePerRitual => frequency == 'once_per_ritual';

  /// التعليمة الظاهرة للحاج. نصّها مقرَّر هنا، لا يولّده نموذج.
  String instructionAr() {
    if (isOncePerRitual) {
      return 'تُقرأ مرة واحدة عند بداية السعي، ولا تُعاد';
    }
    if (frequency == 'repeat_count' && repeatCount != null) {
      if (interleave == 'personal_dua') {
        return 'يُكرَّر $repeatCount مرات، ويدعو بين المرات';
      }
      return 'يُكرَّر $repeatCount مرات';
    }
    return '';
  }

  static RecitationPolicy? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final freq = (m['frequency'] ?? '').toString().trim();
    // قيمة غير معروفة تُقرأ null — لا نخترع سياسة لا نفهمها.
    if (freq != 'once_per_ritual' && freq != 'repeat_count') return null;
    final count = (m['repeatCount'] as num?)?.toInt();
    if (freq == 'repeat_count' && (count == null || count < 1 || count > 10)) {
      return null;
    }
    String? controlled(String key, List<String> allowed) {
      final v = (m[key] ?? '').toString().trim();
      return allowed.contains(v) ? v : null;
    }

    final interleave = controlled('interleave', const ['personal_dua']);
    return RecitationPolicy(
      autoPlayCapability: controlled(
          'autoPlayCapability', const [manualOnlyUntilTriggerSupported]),
      frequency: freq,
      repeatCount: freq == 'repeat_count' ? count : null,
      trigger: controlled('trigger',
          const ['first_safa_approach', 'each_marwah_arrival', 'on_entry']),
      interleave: interleave,
      // يُفرض false عند وجود interleave مهما قال المصدر.
      autoRepeat: interleave == null && m['autoRepeat'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'frequency': frequency,
        if (repeatCount != null) 'repeatCount': repeatCount,
        if (trigger != null) 'trigger': trigger,
        if (interleave != null) 'interleave': interleave,
        if (autoPlayCapability != null)
          'autoPlayCapability': autoPlayCapability,
        'autoRepeat': autoRepeat,
      };
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

  /// الجهة المُصدِرة، والموضع في المطبوع. يحملهما النموذج لأن بطاقة الأثر
  /// الموثّق لا تقوم بدونهما: نصّ مرويّ بلا عزو يفقد سبب عرضه. ويُحفظان في
  /// الكاش أيضًا، فلا يسقط العزو بمجرد انقطاع الشبكة.
  final String authority;
  final String sourceSection;

  /// ما عزا إليه المصدر المطبوع. لا يؤثر في كون النص متلوًّا ولا في تشغيله
  /// ولا في توثيقه — هو بيان مصدر لا صفة محتوى.
  final List<SourceReference> sourceReferences;

  /// كيفية الأداء إن نصّ عليها المصدر. `null` = لم ينصّ، وليس «بلا قيد».
  final RecitationPolicy? recitationPolicy;

  /// إحالة إلى السجل المتلوّ الذي يقصده هذا الإرشاد — بالمعرّف لا بالنص.
  ///
  /// المروة مثالها: المطبوع يقول «ويقولَ مثل ما قال على الصفا» ولا يذكر نصًّا
  /// مستقلًّا للمروة. فنسخ ذكر الصفا هنا يُنشئ نسخةً ثانية من نصٍّ شرعيّ
  /// تفترقان بأول تعديل. الإحالة تُبقي النص الشرعيّ واحدًا في مكان واحد.
  ///
  /// ولا أثر لها البتّة في التوثيق ولا في كون السجل متلوًّا: هي إشارةُ عرضٍ
  /// لا صفةُ محتوى. وللواجهة أن **تدلّ** على البطاقة الأصلية، ولا يجوز لها
  /// أن **تنسخ** نصّها.
  final List<String> relatedRecordIds;

  /// معنىٰ الإحالة. `recitation_link` تعني: «قُل هنا مثل ما هناك».
  ///
  /// تُصرَّح ولا تُستنتج. وإحالةٌ بلا معنىً مصرَّح يرفضها المستورد، لأن
  /// الفحص الوحيد الذي يستحقّ إجراءه — أن يكون الهدف نصًّا يُتلىٰ فعلًا —
  /// متعلّقٌ بمعناها.
  final String? relatedRecordRole;

  static const String recitationLink = 'recitation_link';

  /// هل تُعرض هذه الإحالة زرَّ «انظر: …» إلىٰ بطاقة متلوّة؟
  bool get hasRecitationLink =>
      relatedRecordRole == recitationLink && relatedRecordIds.isNotEmpty;

  /// تعليمة استعمال مستخرجة من المطبوع نفسه — لا اجتهاد فيها ولا تعميم.
  ///
  /// تُعرض للحاج كما هي. وليست نصًّا شرعيًّا يُتلىٰ، فلا تُنطق أبدًا.
  final String usageNoteAr;

  /// سطر العزو الظاهر: الموضع في المطبوع ثم الجهة. فارغ إن غابا معًا.
  String get attribution {
    final parts = [sourceSection.trim(), authority.trim()]
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.join(' — ');
  }

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
    this.authority = '',
    this.sourceSection = '',
    this.sourceReferences = const [],
    this.recitationPolicy,
    this.relatedRecordIds = const [],
    this.relatedRecordRole,
    this.usageNoteAr = '',
  });

  /// تنقية الإحالات: بلا تكرار، وبلا إحالةٍ إلى النفس.
  ///
  /// المستورد يرفض الحالتين رفضًا صريحًا؛ وهذا تشديدٌ من جانب العميل على
  /// بيانات قديمة قد تكون كُتبت قبل وجود ذلك الفحص.
  static List<String> sanitizeRelatedIds(List<String> raw, String selfId) {
    final seen = <String>{};
    final out = <String>[];
    for (final id in raw) {
      final v = id.trim();
      if (v.isEmpty || v == selfId.trim()) continue;
      if (seen.add(v)) out.add(v);
    }
    return List.unmodifiable(out);
  }

  /// هل يجوز للحاج تشغيله بنفسه؟ شرطٌ واحد: أن يكون نصًّا يُتلىٰ.
  ///
  /// الإرشاد والأثر لا زرّ لهما. أما ما عداهما فيُشغَّل **بطلب المستخدم**
  /// دائمًا، مهما قيّدت السياسةُ التشغيلَ التلقائي: منعُ القراءة عليه بالموقع
  /// ليس منعًا له أن يقرأ.
  bool get canPlayManually => contentKind.belongsInDuaSection;

  /// هل يُقرأ عليه تلقائيًّا لمجرد دخوله المنطقة؟
  ///
  /// أضيق من [canPlayManually] بقيدين: ألا تمنعه صفة استعماله (الزيادة
  /// الجائزة)، وألا يعلن السجل أن الحدث الذي يقتضيه غير مدعوم بعد.
  bool get isAutoPlayable =>
      canPlayManually &&
      (usageQualifier?.isAutoPlayable ?? true) &&
      !(recitationPolicy?.blocksAutoPlay ?? false);

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
      authority: (data['authority'] ?? '').toString().trim(),
      sourceSection: (data['sourceSection'] ?? '').toString().trim(),
      sourceReferences: SourceReference.listFrom(data['sourceReferences']),
      recitationPolicy: RecitationPolicy.fromJson(data['recitationPolicy']),
      relatedRecordIds: sanitizeRelatedIds(
        safeStringList(data['relatedRecordIds']),
        (data['duaId'] ?? doc.id).toString(),
      ),
      relatedRecordRole: const [recitationLink]
              .contains((data['relatedRecordRole'] ?? '').toString().trim())
          ? (data['relatedRecordRole'] ?? '').toString().trim()
          : null,
      usageNoteAr: (data['usageNoteAr'] ?? '').toString().trim(),
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
        // Persisted so a cached record can be re-checked on the way OUT of
        // the cache. Without these, `fromJson` would rebuild every record as
        // unverified and the offline path could not tell an approved text
        // from one that was never approved — or from one revoked since.
        'verificationStatus': isVerifiedSource ? 'verified' : 'unverified',
        'revokedAt': null,
        // Persisted so an evidence card keeps its attribution offline. A
        // narration shown without its chain has lost the reason it is there.
        'authority': authority,
        'sourceSection': sourceSection,
        // Persisted so an evidence card keeps its citations offline too.
        'sourceReferences':
            sourceReferences.map((e) => e.toJson()).toList(growable: false),
        // Persisted so the once-only / repeat instruction survives offline.
        'recitationPolicy': recitationPolicy?.toJson(),
        // Persisted so the Marwah card can still point at the canonical
        // dhikr offline. It carries the ID only — never the text, so an
        // offline copy can never drift from the record it points to.
        'relatedRecordIds': relatedRecordIds,
        'relatedRecordRole': relatedRecordRole,
        'usageNoteAr': usageNoteAr,
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
      authority: (data['authority'] ?? '').toString().trim(),
      sourceSection: (data['sourceSection'] ?? '').toString().trim(),
      sourceReferences: SourceReference.listFrom(data['sourceReferences']),
      recitationPolicy: RecitationPolicy.fromJson(data['recitationPolicy']),
      relatedRecordIds: sanitizeRelatedIds(
        safeStringList(data['relatedRecordIds']),
        (data['duaId'] ?? '').toString(),
      ),
      relatedRecordRole: const [recitationLink]
              .contains((data['relatedRecordRole'] ?? '').toString().trim())
          ? (data['relatedRecordRole'] ?? '').toString().trim()
          : null,
      usageNoteAr: (data['usageNoteAr'] ?? '').toString().trim(),
    );
  }
}
