/// Choosing the voice the assistant speaks with.
///
/// ── What was wrong ────────────────────────────────────────────────────────
///
/// The screen pinned an Arabic voice ONCE, when it opened, with `setVoice`.
/// A pinned voice outranks a later `setLanguage` on the platform side, so
/// every reply afterwards — English, Turkish, French — came out of an Arabic
/// larynx. That is the "broken, robotic" reading: not a bad engine, the wrong
/// mouth.
///
/// The locale was also guessed from the SHAPE of the text (does it contain
/// Arabic-script characters?) rather than taken from the reply itself. The
/// server decides the reply language and returns it; guessing re-derives —
/// wrongly — something already known. Urdu is Arabic-script, so an Urdu reply
/// was read as Arabic; and an Arabic reply reached while the app was set to
/// English was read as English.
///
/// ── What this does instead ────────────────────────────────────────────────
///
/// Both functions are pure, so the decision is testable without a device: the
/// TTS plugin needs a real platform channel, and a bug here is inaudible in a
/// widget test but obvious to a pilgrim.
library;

/// BCP-47 locale for a language code the assistant replies in.
///
/// The codes are the six the proxy accepts. Anything else falls back to
/// English rather than to the device default: an unknown code read in
/// whatever the phone happens to be set to is how this broke in the first
/// place.
String ttsLocaleForLanguageCode(String? code) {
  switch ((code ?? '').trim().toLowerCase()) {
    case 'ar':
      return 'ar-SA';
    case 'ur':
      return 'ur-PK';
    case 'tr':
      return 'tr-TR';
    case 'id':
      return 'id-ID';
    case 'fr':
      return 'fr-FR';
    case 'en':
      return 'en-US';
    default:
      return 'en-US';
  }
}

/// Picks the best installed voice for [locale], or null to leave the engine
/// on its own default.
///
/// Order of preference:
///   1. exact locale match (`ur-PK` for `ur-PK`)
///   2. same language, another region — ranked by [_regionPreference], so
///      Arabic reaches for Saudi first and for Egyptian only as a last
///      resort. All of these voices read Modern Standard Arabic; the region
///      is an accent, not a dialect. But this app is read in the Haramain,
///      and the accent of the place is the right default.
///   3. nothing: return null so the caller does NOT call setVoice
///
/// Within a tier, a Google voice wins: on Android these are the neural ones,
/// and the difference is audible.
///
/// Returning null matters. Calling `setVoice` with a mismatched voice is
/// exactly the bug this file exists to fix, so when nothing fits it is better
/// to let `setLanguage` alone decide.
/// Which regional variants to reach for, per language, best first.
///
/// Only Arabic needs an opinion today: the six app languages have one obvious
/// region each except Arabic, which has many, all of them reading the same
/// Modern Standard Arabic in different accents.
const Map<String, List<String>> _regionPreference = {
  'ar': ['sa', 'ae', 'kw', 'qa', 'bh', 'om', 'jo', 'iq', 'ye'],
};

/// Regional variants to use only if nothing else in the language exists.
///
/// Still far better than reading Arabic with an English voice — the point is
/// ordering, not exclusion.
const Map<String, List<String>> _regionLastResort = {
  'ar': ['eg', 'ma', 'dz', 'tn', 'ly'],
};

int _regionRank(String language, String region) {
  final preferred = _regionPreference[language] ?? const [];
  final index = preferred.indexOf(region);
  if (index >= 0) return index;
  if ((_regionLastResort[language] ?? const []).contains(region)) return 1000;
  // An unlisted region sits between: unknown is not a reason to rank it below
  // one we deliberately deprioritised.
  return 500;
}

Map<String, String>? pickVoiceForLocale(
  List<dynamic>? voices,
  String locale,
) {
  if (voices == null || voices.isEmpty) return null;
  final wanted = locale.toLowerCase().replaceAll('_', '-');
  final wantedLanguage = wanted.split('-').first;

  final candidates = <Map<String, String>>[];
  for (final raw in voices) {
    if (raw is! Map) continue;
    final name = raw['name']?.toString();
    // A voice with no name cannot be selected: setVoice addresses it by name.
    if (name == null || name.isEmpty) continue;
    final voiceLocale = (raw['locale'] ?? raw['language'] ?? '')
        .toString()
        .toLowerCase()
        .replaceAll('_', '-');
    if (voiceLocale.isEmpty) continue;
    candidates.add({'name': name, 'locale': voiceLocale});
  }
  if (candidates.isEmpty) return null;

  bool isGoogle(Map<String, String> v) =>
      v['name']!.toLowerCase().contains('google');

  Map<String, String>? bestOf(bool Function(Map<String, String>) matches) {
    final matching = candidates.where(matches).toList();
    if (matching.isEmpty) return null;
    final google = matching.where(isGoogle);
    final chosen = google.isNotEmpty ? google.first : matching.first;
    // The locale is echoed back as the CALLER asked for it, not as the voice
    // reports it: a voice listed as `ar` should still be addressed with a
    // full tag.
    return {'name': chosen['name']!, 'locale': chosen['locale']!};
  }

  final exact = bestOf((v) => v['locale'] == wanted);
  if (exact != null) return exact;

  // Same language, best region first. A stable sort by rank keeps the
  // Google-preference inside each rank intact.
  final sameLanguage = candidates
      .where((v) => v['locale']!.split('-').first == wantedLanguage)
      .toList();
  if (sameLanguage.isEmpty) return null;
  String regionOf(Map<String, String> v) {
    final parts = v['locale']!.split('-');
    return parts.length > 1 ? parts[1] : '';
  }

  sameLanguage.sort((a, b) {
    final ra = _regionRank(wantedLanguage, regionOf(a));
    final rb = _regionRank(wantedLanguage, regionOf(b));
    if (ra != rb) return ra.compareTo(rb);
    final ga = isGoogle(a) ? 0 : 1;
    final gb = isGoogle(b) ? 0 : 1;
    return ga.compareTo(gb);
  });
  final chosen = sameLanguage.first;
  return {'name': chosen['name']!, 'locale': chosen['locale']!};
}
