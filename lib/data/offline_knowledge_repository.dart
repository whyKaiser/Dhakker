/// Offline knowledge repository for the Dhakker assistant.
///
/// This is a small, versioned, source-aware set of DETERMINISTIC,
/// non-generative fallback answers used ONLY when the device has no network
/// connectivity at all (see `AssistantService._offlineReply`). It is
/// deliberately NOT a replacement for the server-side grounded/RAG pipeline
/// in `assistant-proxy/worker.js` — it exists purely to keep a handful of
/// basic, uncontroversial ritual-mechanics facts available offline.
///
/// ── Labeling ─────────────────────────────────────────────────────────────
/// Every entry carries [OfflineKnowledgeEntry.sourceLabel] and
/// [OfflineKnowledgeEntry.isVerified]. None of the entries here are tied to
/// a real, approved-source citation record (unlike the server-side
/// `knowledge_documents`/`knowledge_chunks` registry), so they are ALL
/// labeled `isVerified: false` / "Unverified offline content — general
/// knowledge, not a citation-backed ruling". Only ever flip `isVerified` to
/// true for an entry that is actually backed by a real source metadata
/// field (documentId/authority/url) — never blanket-label offline content
/// as verified.
///
/// ── Languages ────────────────────────────────────────────────────────────
/// The app supports ar/en/ur/tr/id/fr. Verified/reviewed translations exist
/// today only in English. Rather than fabricate unreviewed religious-fact
/// translations in the other five languages, entries for a topic in a
/// language that has no reviewed translation yet simply fall back to the
/// English text with an explicit `isFallbackTranslation: true` marker so
/// callers can, if desired, prefix a "shown in English" notice. This must
/// be kept honest: add a real translation only when it has actually been
/// reviewed, never guessed.
library;

class OfflineKnowledgeEntry {
  final String topicId;
  final String language;
  final String text;
  final bool isVerified;
  final String sourceLabel;
  final bool isFallbackTranslation;

  const OfflineKnowledgeEntry({
    required this.topicId,
    required this.language,
    required this.text,
    this.isVerified = false,
    this.sourceLabel =
        'Unverified offline content — general knowledge, not a citation-backed ruling',
    this.isFallbackTranslation = false,
  });
}

class OfflineKnowledgeRepository {
  const OfflineKnowledgeRepository._();

  /// Schema/content version — bump whenever entries are added, edited, or a
  /// new reviewed translation is added, so callers/tests can detect drift.
  static const int version = 1;

  static const List<String> supportedLanguages = [
    'ar',
    'en',
    'ur',
    'tr',
    'id',
    'fr'
  ];

  /// Reviewed, source-of-truth English text per topic. English is the only
  /// language with reviewed coverage today for every topic below.
  static const Map<String, String> _en = {
    'tawaf': 'Tawaf is seven circuits around the Kaaba, counter-clockwise, '
        'starting and ending level with the Black Stone.',
    'sai': "Sa'i is seven circuits between Safa and Marwah, starting at Safa "
        'and ending at Marwah.',
    'ihram': 'Ihram: intention (niyyah) + wearing the ihram garments at the '
        'miqat, followed by the Talbiyah.',
    'jamarat':
        'Stoning the Jamarat: seven pebbles per pillar, starting the 10th day.',
    'arafat':
        "Standing at Arafat is the greatest pillar of Hajj: 'Hajj is Arafah.'",
    'fallback':
        'You are offline right now. I can answer a few basic ritual facts '
            '(Tawaf / Sai / Ihram / Jamarat / Arafat) from memory. For anything '
            'else, please ask your on-site guide once connected.',
  };

  /// Reviewed translations. Only add a language here for a topic once an
  /// actual reviewed translation exists — never fabricate one. Topics
  /// missing from a language's map fall back to English (see [textFor]).
  static const Map<String, Map<String, String>> _reviewedTranslations = {
    'ar': {
      'tawaf': 'الطواف هو سبعة أشواط حول الكعبة، عكس اتجاه عقارب الساعة، '
          'يبدأ وينتهي عند الحجر الأسود.',
      'sai':
          'السعي هو سبعة أشواط بين الصفا والمروة، يبدأ من الصفا وينتهي بالمروة.',
      'ihram': 'الإحرام: النية + لبس ثياب الإحرام عند الميقات، ثم التلبية.',
      'jamarat': 'رمي الجمرات: سبع حصيات لكل جمرة، ابتداءً من اليوم العاشر.',
      'arafat': 'الوقوف بعرفة هو أعظم أركان الحج: "الحج عرفة".',
      'fallback': 'أنت الآن غير متصل بالإنترنت. يمكنني الإجابة عن بعض الحقائق '
          'الأساسية للمناسك (الطواف / السعي / الإحرام / الجمرات / عرفة) من الذاكرة. '
          'لأي شيء آخر، يرجى سؤال مرشدك عند عودة الاتصال.',
    },
  };

  /// Returns the offline text for [topicId] in [language]. If no reviewed
  /// translation exists for that language, honestly falls back to the
  /// reviewed English text rather than fabricating one.
  static OfflineKnowledgeEntry textFor(String topicId, String language) {
    final reviewed = _reviewedTranslations[language]?[topicId];
    if (reviewed != null) {
      return OfflineKnowledgeEntry(
          topicId: topicId, language: language, text: reviewed);
    }
    final en = _en[topicId] ?? _en['fallback']!;
    return OfflineKnowledgeEntry(
      topicId: topicId,
      language: language,
      text: en,
      isFallbackTranslation: language != 'en',
    );
  }

  /// Matches free-text [message] against known topics via simple keyword
  /// containment (Arabic + English/transliterated keywords), mirroring the
  /// previous inline logic in `AssistantService`. Returns 'fallback' when no
  /// topic matches.
  static String topicFor(String message) {
    final q = message.toLowerCase();
    if (q.contains('طواف') ||
        q.contains('tawaf') ||
        q.contains('circumambulat')) return 'tawaf';
    if (q.contains('سعي') ||
        q.contains('sai') ||
        q.contains('safa') ||
        q.contains('marwa')) return 'sai';
    if (q.contains('إحرام') || q.contains('ihram') || q.contains('miqat')) {
      return 'ihram';
    }
    if (q.contains('جمر') || q.contains('jamarat') || q.contains('stoning')) {
      return 'jamarat';
    }
    if (q.contains('عرفة') || q.contains('arafat') || q.contains('arafah')) {
      return 'arafat';
    }
    return 'fallback';
  }
}
