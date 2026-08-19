/// Offline knowledge repository for the Dhakker assistant.
///
/// ── What this is (and deliberately is NOT) ───────────────────────────────
/// This holds DETERMINISTIC, non-generative offline text used only when the
/// device has no network connectivity (see `AssistantService._offlineReply`).
///
/// It contains **no religious or ritual guidance of any kind**. Every ritual
/// or ruling question asked offline is answered by directing the pilgrim to
/// approved guidance they have already saved, or to an authorized human
/// guide — never by this file asserting a religious fact.
///
/// ── Why the previous ritual facts were removed ───────────────────────────
/// An earlier revision of this file shipped statements about Tawaf, Sa'i,
/// Ihram, Jamarat, and Arafat — including a hadith quotation — with no
/// approved-source citation metadata behind any of them, while the surrounding
/// code described them as "reviewed". That is exactly the failure mode the
/// project's religious-safety rule exists to prevent: unverifiable religious
/// claims presented to pilgrims with an implied stamp of review. They have
/// been removed and must not be reintroduced from memory, from a model, or
/// from an unattributed web source.
///
/// The ONLY way ritual content may appear here in future is if it arrives
/// with real approved-source metadata (documentId / authority / URL / version
/// / verification status) via the same approved-source registry the server
/// uses (`knowledge_documents` / `knowledge_chunks`, see
/// `scripts/ingest_knowledge.mjs`), cached locally for offline use. Until
/// such content exists, [approvedOfflineGuidance] is empty by design and
/// [hasApprovedOfflineGuidance] is false.
///
/// ── Languages ────────────────────────────────────────────────────────────
/// The operational (non-religious) messages below are translated for all six
/// supported languages: ar, en, ur, tr, id, fr. These are ordinary UI strings
/// — connectivity notices and a referral to a human guide — so translating
/// them fabricates no religious content.
library;

/// How a piece of offline text should be presented to the user. The UI must
/// render these distinctly — an operational notice must never be styled as
/// though it were verified religious guidance.
enum OfflineContentStatus {
  /// Operational, non-religious app message (connectivity, how to get help).
  /// Carries no religious authority and makes no ritual claim.
  operationalNotice,

  /// The user asked something this app cannot answer offline without an
  /// approved source. Directs them to saved approved guidance or a human
  /// guide. Makes no ritual claim of its own.
  noApprovedSourceOffline,

  /// Genuinely approved, citation-backed guidance cached for offline use.
  /// Only ever produced from the approved-source registry — never hardcoded.
  approvedGuidance,
}

class OfflineKnowledgeEntry {
  final String topicId;
  final String language;
  final String text;
  final OfflineContentStatus status;

  /// Populated only for [OfflineContentStatus.approvedGuidance]. Null for
  /// every entry that is not backed by a real approved-source record.
  final OfflineCitationMetadata? source;

  const OfflineKnowledgeEntry({
    required this.topicId,
    required this.language,
    required this.text,
    required this.status,
    this.source,
  });

  /// True only when this entry is backed by real approved-source metadata.
  /// Never true for the operational messages defined in this file.
  bool get isApproved =>
      status == OfflineContentStatus.approvedGuidance && source != null;
}

/// Citation metadata for genuinely approved offline content. Mirrors the
/// server-side approved-source registry record.
class OfflineCitationMetadata {
  final String documentId;
  final String title;
  final String authority;
  final String? section;
  final String? url;
  final String version;

  const OfflineCitationMetadata({
    required this.documentId,
    required this.title,
    required this.authority,
    required this.version,
    this.section,
    this.url,
  });
}

class OfflineKnowledgeRepository {
  const OfflineKnowledgeRepository._();

  /// Content version — bump whenever entries change so callers/tests can
  /// detect drift. v2 removed all unapproved religious claims (see the
  /// library doc comment).
  static const int version = 2;

  static const List<String> supportedLanguages = [
    'ar',
    'en',
    'ur',
    'tr',
    'id',
    'fr',
  ];

  /// Approved, citation-backed guidance cached for offline use.
  ///
  /// Intentionally EMPTY: no officially approved religious source content has
  /// been ingested into this project yet. Populating this map by hand from
  /// memory or model output is prohibited — entries may only be produced from
  /// the approved-source registry, with real [OfflineCitationMetadata].
  static const Map<String, Map<String, OfflineKnowledgeEntry>>
      approvedOfflineGuidance = {};

  /// Whether any genuinely approved offline guidance is available at all.
  /// The UI uses this to avoid promising offline ritual answers it cannot give.
  static bool get hasApprovedOfflineGuidance =>
      approvedOfflineGuidance.isNotEmpty;

  /// Message shown when the device is offline and the user asked something
  /// requiring an approved religious/ritual source. Makes no ritual claim.
  static const Map<String, String> _noApprovedSourceOffline = {
    'ar': 'أنت غير متصل بالإنترنت حالياً، ولا تتوفر لدي إجابة من مصدر معتمد '
        'لهذا السؤال دون اتصال. لا أستطيع الإجابة عن أسئلة المناسك أو الأحكام '
        'من تلقاء نفسي. يرجى الرجوع إلى الإرشادات المعتمدة المحفوظة لديك، أو '
        'سؤال مرشد معتمد أو عالم مخوّل.',
    'en': 'You are currently offline, and I have no approved-source answer '
        'available for this question offline. I cannot answer ritual or ruling '
        'questions on my own. Please refer to approved guidance you have saved, '
        'or ask an authorized guide or a qualified scholar.',
    'ur': 'آپ اس وقت آف لائن ہیں، اور اس سوال کے لیے میرے پاس منظور شدہ ماخذ '
        'سے کوئی جواب دستیاب نہیں۔ میں مناسک یا احکام کے سوالات کا جواب خود سے '
        'نہیں دے سکتا۔ براہ کرم اپنی محفوظ کردہ منظور شدہ رہنمائی دیکھیں، یا '
        'کسی مجاز رہنما یا مستند عالم سے پوچھیں۔',
    'tr': 'Şu anda çevrimdışısınız ve bu soru için çevrimdışı olarak onaylı '
        'kaynaklı bir yanıtım yok. İbadet veya hüküm sorularını kendi başıma '
        'yanıtlayamam. Lütfen kaydettiğiniz onaylı rehbere bakın veya yetkili '
        'bir rehbere ya da ehil bir alime danışın.',
    'id': 'Anda sedang offline, dan saya tidak memiliki jawaban dari sumber '
        'resmi untuk pertanyaan ini secara offline. Saya tidak dapat menjawab '
        'pertanyaan ibadah atau hukum sendiri. Silakan merujuk pada panduan '
        'resmi yang telah Anda simpan, atau tanyakan kepada pemandu resmi atau '
        'ulama yang berwenang.',
    'fr': "Vous êtes actuellement hors ligne et je n'ai aucune réponse issue "
        "d'une source approuvée pour cette question hors ligne. Je ne peux pas "
        "répondre seul aux questions de rites ou de jurisprudence. Veuillez "
        "consulter les directives approuvées que vous avez enregistrées, ou "
        "demander à un guide agréé ou à un érudit qualifié.",
  };

  /// General offline notice for non-ritual questions. Operational only.
  static const Map<String, String> _operationalOffline = {
    'ar': 'أنت غير متصل بالإنترنت حالياً، لذا لا يمكنني البحث عن إجابة الآن. '
        'لا تزال عدادات الطواف والسعي، والخرائط المحفوظة، وجهات اتصال الطوارئ '
        'تعمل دون اتصال. سيعمل المساعد عند عودة الاتصال.',
    'en': 'You are currently offline, so I cannot look up an answer right now. '
        'Your Tawaf and Sa\'i counters, saved maps, and emergency contacts still '
        'work offline. The assistant will work again once you reconnect.',
    'ur': 'آپ اس وقت آف لائن ہیں، اس لیے میں ابھی جواب تلاش نہیں کر سکتا۔ آپ '
        'کے طواف اور سعی کے کاؤنٹر، محفوظ نقشے، اور ہنگامی رابطے آف لائن بھی '
        'کام کرتے ہیں۔ دوبارہ منسلک ہونے پر معاون کام کرنے لگے گا۔',
    'tr': 'Şu anda çevrimdışısınız, bu nedenle şimdi bir yanıt arayamıyorum. '
        'Tavaf ve sa\'y sayaçlarınız, kayıtlı haritalarınız ve acil durum '
        'kişileriniz çevrimdışı çalışmaya devam eder. Yeniden bağlandığınızda '
        'asistan tekrar çalışacaktır.',
    'id': 'Anda sedang offline, jadi saya tidak dapat mencari jawaban sekarang. '
        'Penghitung Tawaf dan Sa\'i, peta tersimpan, dan kontak darurat Anda '
        'tetap berfungsi offline. Asisten akan berfungsi lagi setelah Anda '
        'terhubung kembali.',
    'fr': "Vous êtes actuellement hors ligne, je ne peux donc pas rechercher de "
        "réponse pour le moment. Vos compteurs de Tawaf et de Sa'i, vos cartes "
        "enregistrées et vos contacts d'urgence fonctionnent toujours hors "
        "ligne. L'assistant refonctionnera une fois reconnecté.",
  };

  /// Keywords that indicate a ritual/ruling question, which this repository
  /// must never answer on its own. Matching only changes WHICH safe message
  /// is returned — no branch of this method ever asserts a religious fact.
  static const List<String> _ritualKeywords = [
    // Arabic
    'طواف', 'سعي', 'إحرام', 'احرام', 'جمر', 'عرفة', 'حكم', 'يجوز',
    'مناسك', 'تلبية', 'هدي', 'حلق', 'تقصير', 'ميقات', 'صلاة', 'دعاء',
    // Latin / transliterated
    'tawaf', 'circumambulat', 'sai', "sa'i", 'safa', 'marwa', 'ihram',
    'miqat', 'jamarat', 'stoning', 'arafat', 'arafah', 'muzdalifah',
    'talbiyah', 'hady', 'halq', 'ruling', 'permissible', 'allowed',
    'fatwa', 'sunnah', 'obligatory', 'wajib', 'fard', 'prayer', 'dua',
  ];

  /// True when [message] looks like a ritual/ruling question.
  static bool isRitualQuestion(String message) {
    final q = message.toLowerCase();
    return _ritualKeywords.any(q.contains);
  }

  /// Returns the offline entry for [message] in [language].
  ///
  /// Never returns religious content. A ritual/ruling question yields a
  /// referral to approved guidance or a human guide; anything else yields an
  /// operational connectivity notice.
  static OfflineKnowledgeEntry replyFor(String message, String language) {
    final lang = supportedLanguages.contains(language) ? language : 'en';
    if (isRitualQuestion(message)) {
      return OfflineKnowledgeEntry(
        topicId: 'no_approved_source_offline',
        language: lang,
        text: _noApprovedSourceOffline[lang]!,
        status: OfflineContentStatus.noApprovedSourceOffline,
      );
    }
    return OfflineKnowledgeEntry(
      topicId: 'offline_notice',
      language: lang,
      text: _operationalOffline[lang]!,
      status: OfflineContentStatus.operationalNotice,
    );
  }
}
