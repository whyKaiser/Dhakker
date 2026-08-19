/// Decides which language the assistant replies in.
///
/// WHY THIS EXISTS. The reply language used to come from a picker inside the
/// Assistant screen that always started on Arabic — `_languages.first` — so
/// the app's own selected locale was never consulted. An English-speaking
/// pilgrim who opened the assistant got Arabic until they noticed the picker.
/// Meanwhile the dev direct path told the model to "reply in the same
/// language as the user", i.e. it let the model detect. Three different
/// answers to one question.
///
/// The rule is now one rule, applied on every path: the app's selected
/// locale decides. Detection from the message is a fallback for when there
/// is no setting to read, never the primary signal.
library;

/// Where a resolved language came from — surfaced for tests and diagnostics,
/// so a wrong answer can be traced to the input that produced it.
enum LanguageSource {
  /// An explicit `responseLanguage` passed by the caller.
  explicitSetting,

  /// The app's selected locale (`userLocale`).
  appLocale,

  /// The script of the latest user message. Fallback only.
  messageDetection,

  /// Nothing usable was available.
  defaultLanguage,
}

class LanguageDecision {
  const LanguageDecision({
    required this.responseLanguage,
    required this.userLocale,
    required this.source,
  });

  /// ISO code the reply must use, e.g. `ar`.
  final String responseLanguage;

  /// Canonical locale, e.g. `ar-SA`.
  final String userLocale;

  final LanguageSource source;

  @override
  String toString() =>
      'LanguageDecision($responseLanguage, $userLocale, $source)';
}

class LanguagePolicy {
  const LanguagePolicy._();

  static const List<String> supported = ['ar', 'en', 'ur', 'tr', 'id', 'fr'];

  static const String defaultLanguage = 'en';

  /// Arabic has no finer locale distinction in this app, so `ar-SA` is the
  /// canonical form wherever a full locale is required.
  static const Map<String, String> canonicalLocales = {
    'ar': 'ar-SA',
    'en': 'en-US',
    'ur': 'ur-PK',
    'tr': 'tr-TR',
    'id': 'id-ID',
    'fr': 'fr-FR',
  };

  /// Extracts a supported language code from a locale string such as
  /// `ar_SA`, `ar-SA`, or `ar`. Returns null when unsupported or empty.
  static String? languageFromLocale(String? locale) {
    final base =
        (locale ?? '').trim().toLowerCase().split(RegExp(r'[-_]')).first;
    return supported.contains(base) ? base : null;
  }

  static String localeFor(String language) =>
      canonicalLocales[language] ?? '$language-${language.toUpperCase()}';

  /// Detects the language of a message. Deliberately narrow: it recognises
  /// Arabic script and otherwise says English, because that is the only
  /// distinction this app can make reliably. Guessing between Turkish,
  /// French and Indonesian from letter frequency would be worse than
  /// falling back to the default.
  static String? detectFromMessage(String? message) {
    final text = message ?? '';
    if (text.isEmpty) return null;
    // Letters only. Arabic punctuation (؟ ، ؛) and Arabic-Indic digits are
    // deliberately excluded: "؟؟؟ 123" is not evidence of an Arabic message,
    // and counting it would route a symbol-only message to Arabic.
    final arabic =
        RegExp(r'[\u0621-\u064A\u0671-\u06D3\u06FA-\u06FF\uFB50-\uFDFF]')
            .allMatches(text)
            .length;
    final latin = RegExp(r'[A-Za-z]').allMatches(text).length;
    if (arabic > 0 && arabic >= latin) return 'ar';
    if (latin > 0) return 'en';
    return null;
  }

  /// Resolves the reply language.
  ///
  /// Precedence:
  ///   1. [responseLanguage] — an explicit setting.
  ///   2. [userLocale] — the app's selected locale.
  ///   3. the script of [latestUserMessage] — fallback only.
  ///   4. [defaultLanguage].
  static LanguageDecision resolve({
    String? responseLanguage,
    String? userLocale,
    String? latestUserMessage,
  }) {
    final explicit = languageFromLocale(responseLanguage);
    if (explicit != null) {
      return LanguageDecision(
        responseLanguage: explicit,
        userLocale: userLocale?.trim().isNotEmpty == true
            ? userLocale!.trim()
            : localeFor(explicit),
        source: LanguageSource.explicitSetting,
      );
    }

    final fromLocale = languageFromLocale(userLocale);
    if (fromLocale != null) {
      return LanguageDecision(
        responseLanguage: fromLocale,
        userLocale: userLocale!.trim(),
        source: LanguageSource.appLocale,
      );
    }

    final detected = detectFromMessage(latestUserMessage);
    if (detected != null) {
      return LanguageDecision(
        responseLanguage: detected,
        userLocale: localeFor(detected),
        source: LanguageSource.messageDetection,
      );
    }

    return LanguageDecision(
      responseLanguage: defaultLanguage,
      userLocale: localeFor(defaultLanguage),
      source: LanguageSource.defaultLanguage,
    );
  }
}
