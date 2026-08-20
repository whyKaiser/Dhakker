import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/offline_knowledge_repository.dart';
import 'language_policy.dart';

/// A single citation returned by the assistant for a grounded answer.
class AssistantCitation {
  final String documentId;
  final String title;
  final String authority;
  final String section;
  final String url;

  const AssistantCitation({
    required this.documentId,
    required this.title,
    required this.authority,
    this.section = '',
    this.url = '',
  });

  factory AssistantCitation.fromJson(Map<String, dynamic> json) {
    return AssistantCitation(
      documentId: (json['documentId'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      authority: (json['authority'] as String?)?.trim() ?? '',
      section: (json['section'] as String?)?.trim() ?? '',
      url: (json['url'] as String?)?.trim() ?? '',
    );
  }

  bool get isValid =>
      documentId.isNotEmpty && title.isNotEmpty && authority.isNotEmpty;
}

/// A verified religious text, delivered by the server byte-for-byte from the
/// stored record.
///
/// This is deliberately NOT the model's rendering of the text. The generated
/// answer may paraphrase or summarise; scripture may not. So the server
/// returns the stored text alongside the answer and the UI shows it as its
/// own card, visually separate from anything the model wrote.
///
/// [text] must never be trimmed, normalised, or re-encoded on the way to the
/// screen: a stripped diacritic or a "fixed" Uthmanic glyph is the exact
/// defect this path exists to prevent.
class VerifiedExcerpt {
  final String documentId;
  final String title;
  final String authority;
  final String text;

  /// Language of the TEXT — not of the reply. A French answer still carries
  /// Arabic scripture, and the UI labels it accordingly.
  final String textLanguage;

  const VerifiedExcerpt({
    required this.documentId,
    required this.title,
    required this.authority,
    required this.text,
    required this.textLanguage,
  });

  static List<VerifiedExcerpt> listFrom(dynamic raw) {
    // An older proxy simply does not send this field. That is not an error:
    // the client shows citations as before and no excerpt card.
    if (raw is! List) return const [];
    final out = <VerifiedExcerpt>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final text = map['text'];
      final documentId = (map['documentId'] as String?)?.trim() ?? '';
      // No trim() on `text` — see the class comment.
      if (text is! String || text.isEmpty || documentId.isEmpty) continue;
      out.add(VerifiedExcerpt(
        documentId: documentId,
        title: (map['title'] as String?)?.trim() ?? '',
        authority: (map['authority'] as String?)?.trim() ?? '',
        text: text,
        textLanguage: (map['textLanguage'] as String?)?.trim() ?? 'ar',
      ));
    }
    return out;
  }
}

/// The structured response contract returned by the assistant proxy.
///
/// Mirrors the JSON contract enforced server-side in `assistant-proxy/worker.js`.
/// The client re-validates every field defensively — never trusts the
/// network response blindly, since a compromised/misbehaving proxy or a
/// transport error must never surface a fabricated "grounded" answer.
class AssistantResponse {
  final String answer;
  final String language;
  final bool grounded;
  final String confidence; // high | medium | low
  final List<AssistantCitation> citations;

  /// Verbatim verified texts to render separately from [answer]. Empty when
  /// the proxy did not send any — including an older proxy that has no such
  /// field.
  final List<VerifiedExcerpt> verifiedExcerpts;
  final String? recommendedAction;
  final bool requiresHumanGuide;
  final String? safetyNotice;
  final bool isOffline;
  final bool signInRequired;

  /// Set only when [isOffline]. Lets the UI distinguish an operational
  /// connectivity notice from an "unavailable offline without an approved
  /// source" referral, and from genuinely approved cached guidance — so
  /// unverified offline text is never presented as verified guidance.
  final OfflineContentStatus? offlineStatus;

  const AssistantResponse({
    required this.answer,
    required this.language,
    required this.grounded,
    required this.confidence,
    required this.citations,
    this.verifiedExcerpts = const [],
    this.recommendedAction,
    required this.requiresHumanGuide,
    this.safetyNotice,
    this.isOffline = false,
    this.signInRequired = false,
    this.offlineStatus,
  });

  factory AssistantResponse.fromJson(
      Map<String, dynamic> json, String requestedLanguage) {
    final rawCitations = json['citations'];
    final citations = <AssistantCitation>[];
    if (rawCitations is List) {
      for (final entry in rawCitations) {
        if (entry is Map<String, dynamic>) {
          final c = AssistantCitation.fromJson(entry);
          if (c.isValid) citations.add(c);
        }
      }
    }
    final answer = (json['answer'] as String?)?.trim() ?? '';

    // Defense in depth (mirrors the Worker-side invariant): a response can
    // NEVER end up grounded when its final, validated citations list is
    // empty — regardless of what the raw JSON claimed. If the network layer
    // or a misbehaving/compromised proxy ever sent grounded:true with no
    // valid citations, force the safe state here too.
    final claimedGrounded = json['grounded'] == true;
    final grounded = claimedGrounded && citations.isNotEmpty;
    final confidence = !grounded
        ? 'low'
        : (const ['high', 'medium', 'low'].contains(json['confidence'])
            ? json['confidence'] as String
            : 'low');
    final requiresHumanGuide =
        !grounded ? true : (json['requiresHumanGuide'] == true);

    return AssistantResponse(
      answer: answer.isEmpty ? _unverifiedAnswer(requestedLanguage) : answer,
      language: (json['language'] as String?) ?? requestedLanguage,
      grounded: grounded,
      confidence: confidence,
      citations: citations,
      verifiedExcerpts: VerifiedExcerpt.listFrom(json['verifiedExcerpts']),
      recommendedAction: json['recommendedAction'] as String?,
      requiresHumanGuide: requiresHumanGuide,
      safetyNotice: json['safetyNotice'] as String?,
    );
  }

  /// Offline response built from a deterministic [OfflineKnowledgeEntry].
  ///
  /// [offlineStatus] is carried through so the UI can distinguish an ordinary
  /// connectivity notice from "I cannot answer this ritual question offline
  /// without an approved source" — and from genuinely approved, citation-backed
  /// offline guidance, which is the only kind that may ever be labelled
  /// verified. `requiresHumanGuide` is set for ritual questions, since the
  /// correct action there is to consult an authorized guide.
  factory AssistantResponse.offline(OfflineKnowledgeEntry entry) {
    return AssistantResponse(
      answer: entry.text,
      language: entry.language,
      grounded: entry.isApproved,
      confidence: 'low',
      citations: const [],
      requiresHumanGuide:
          entry.status == OfflineContentStatus.noApprovedSourceOffline,
      isOffline: true,
      offlineStatus: entry.status,
    );
  }

  factory AssistantResponse.unverified(String language, {String? notice}) {
    return AssistantResponse(
      answer: _unverifiedAnswer(language),
      language: language,
      grounded: false,
      confidence: 'low',
      citations: const [],
      requiresHumanGuide: true,
      safetyNotice: notice,
    );
  }

  /// Distinct state: no authenticated user (or the server rejected the
  /// token as expired/invalid). The UI must show this differently from a
  /// generic failure — e.g. a "please sign in" prompt, not a red error toast.
  factory AssistantResponse.signInRequired(String language) {
    return AssistantResponse(
      answer: _signInRequiredAnswer(language),
      language: language,
      grounded: false,
      confidence: 'low',
      citations: const [],
      requiresHumanGuide: false,
      signInRequired: true,
    );
  }

  static String _signInRequiredAnswer(String language) {
    switch (language) {
      case 'ar':
        return 'يرجى تسجيل الدخول لاستخدام المساعد.';
      case 'ur':
        return 'معاون استعمال کرنے کے لیے براہ کرم سائن ان کریں۔';
      case 'tr':
        return 'Asistanı kullanmak için lütfen giriş yapın.';
      case 'id':
        return 'Silakan masuk untuk menggunakan asisten.';
      case 'fr':
        return "Veuillez vous connecter pour utiliser l'assistant.";
      default:
        return 'Please sign in to use the assistant.';
    }
  }

  static String _unverifiedAnswer(String language) {
    switch (language) {
      case 'ar':
        return 'تعذّر التحقق من إجابة موثوقة الآن. يرجى سؤال المرشد أو العالم المعتمد.';
      case 'ur':
        return 'اس وقت مصدقہ جواب دستیاب نہیں۔ براہ کرم مجاز رہنما یا عالم سے پوچھیں۔';
      case 'tr':
        return 'Şu anda güvenilir bir yanıt doğrulanamadı. Lütfen yetkili rehbere danışın.';
      case 'id':
        return 'Jawaban terverifikasi tidak tersedia saat ini. Silakan tanyakan pemandu resmi.';
      case 'fr':
        return "Une réponse fiable n'a pas pu être vérifiée. Veuillez consulter un guide agréé.";
      default:
        return 'A verified answer is not available right now. Please ask an authorized on-site guide.';
    }
  }
}

/// Optional, consent-gated pilgrim context sent alongside the message.
///
/// Every field is sent ONLY when [consent] is true. The server independently
/// re-validates and drops the whole block if consent is not explicitly true
/// — see `validateContext` in `assistant-proxy/worker.js`.
class PilgrimContext {
  final bool consent;
  final String?
      ritual; // e.g. tawaf, sai, ihram, arafat, muzdalifah, jamarat, tawaf_wadaa
  final int? tawafLapsCompleted;
  final int? saiLapsCompleted;
  final String? mobility; // wheelchair, elderly, limited_walking
  final String? connectivity; // online, offline, limited
  final String? zone; // coarse named zone only — never raw coordinates
  final String? crowdLevel; // low, moderate, high, severe

  const PilgrimContext({
    this.consent = false,
    this.ritual,
    this.tawafLapsCompleted,
    this.saiLapsCompleted,
    this.mobility,
    this.connectivity,
    this.zone,
    this.crowdLevel,
  });

  static const PilgrimContext none = PilgrimContext(consent: false);

  Map<String, dynamic>? toJson() {
    if (!consent) return null; // never send anything without explicit opt-in
    return {
      'consent': true,
      if (ritual != null) 'ritual': ritual,
      if (tawafLapsCompleted != null) 'tawafLapsCompleted': tawafLapsCompleted,
      if (saiLapsCompleted != null) 'saiLapsCompleted': saiLapsCompleted,
      if (mobility != null) 'mobility': mobility,
      if (connectivity != null) 'connectivity': connectivity,
      if (zone != null) 'zone': zone,
      if (crowdLevel != null) 'crowdLevel': crowdLevel,
    };
  }
}

/// Client for the Dhakker assistant proxy (secured Cloudflare Worker).
///
/// The Worker owns the system prompt, model, temperature, and provider
/// selection (Groq primary, Gemini fallback) — this client never chooses or
/// sends any of those. It sends the raw conversation history, the requested
/// reply language, and — only with explicit consent — a small structured
/// [PilgrimContext] block, kept fully separate from the free-text message.
class AssistantService {
  // Direct-key mode: development only. For production always configure
  // ASSISTANT_PROXY_URL so the key never ships inside the app binary.
  static const String _apiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  static const String _compiledProxyUrl =
      String.fromEnvironment('ASSISTANT_PROXY_URL', defaultValue: '');

  /// The proxy URL actually used by this instance. Defaults to the
  /// compile-time `ASSISTANT_PROXY_URL` define (the real production path);
  /// overridable via the constructor purely so tests can force proxy mode
  /// and an injected [http.Client] without needing a `--dart-define` build.
  final String _proxyUrl;

  final http.Client _client;

  AssistantService({String? proxyUrl, http.Client? client})
      : _proxyUrl = proxyUrl ?? _compiledProxyUrl,
        _client = client ?? http.Client();

  /// Compile-time (not a runtime-flippable settings toggle) release-build
  /// flag — `dart.vm.product` is baked in by the Dart/Flutter build tool
  /// itself for `flutter build ... --release`/`--profile` output, so it
  /// cannot be silently left on by a stray runtime setting. Direct-key mode
  /// is HARD-DISABLED whenever this is true, even if a build accidentally
  /// still carries a `GROQ_API_KEY` define — release builds must always go
  /// through the Worker proxy.
  static const bool _isReleaseBuild = bool.fromEnvironment('dart.vm.product');

  /// Optional Firebase ID token supplier. Set by app startup once a signed-in
  /// user's token is available. The proxy requires this in production.
  Future<String?> Function()? idTokenProvider;

  bool get _useProxy => _proxyUrl.isNotEmpty;

  /// True only in a non-release build with no proxy configured and a direct
  /// key present. Production/release builds NEVER use direct mode, even if
  /// a key was accidentally compiled in — see [_isReleaseBuild].
  bool get _useDirectDevMode =>
      !_useProxy && !_isReleaseBuild && _apiKey.isNotEmpty;

  static const String _directEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _directModel = 'llama-3.3-70b-versatile';

  final List<Map<String, String>> _history = [];

  List<Map<String, String>> get history => List.unmodifiable(_history);

  bool get isConfigured => _useProxy || _useDirectDevMode;

  /// Sends a message with the requested reply [language] (ISO code among
  /// ar/en/ur/tr/id/fr) and an optional consent-gated [context].
  /// Never throws for expected failure modes — always returns a safe
  /// [AssistantResponse] (offline fallback, or "cannot verify" fallback).
  /// Sends a message. [language] is the RESOLVED reply language — callers
  /// must pass what [LanguagePolicy] decided from app settings, never a
  /// picker default and never the language they guessed from the message.
  /// Sends a message and returns the structured reply.
  ///
  /// [language] must be the language [LanguagePolicy] RESOLVED from app
  /// settings — not a picker default, and not a guess from the message.
  /// Passing the app's locale in [userLocale] lets the server apply the same
  /// precedence if a client ever disagrees.
  ///
  /// [contentLanguage] is the language of the religious CONTENT, which is
  /// not the reply language: a French reply still quotes Arabic scripture.
  /// [allowLanguageFallback] false means only content reviewed in
  /// [contentLanguage] may be used — the server then returns the honest
  /// no-approved-source reply rather than translating anything.
  Future<AssistantResponse> ask(
    String userMessage, {
    String language = 'en',
    String? userLocale,
    String? contentLanguage,
    bool allowLanguageFallback = true,
    PilgrimContext context = PilgrimContext.none,
  }) async {
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      return AssistantResponse.unverified(language);
    }

    if (!isConfigured) {
      return AssistantResponse.unverified(
        language,
        notice: 'assistant_not_configured',
      );
    }

    _history.add({'role': 'user', 'content': trimmed});
    // Cap conversation history sent per request; the server also enforces
    // its own cap independently.
    final recentHistory = _history.length > 20
        ? _history.sublist(_history.length - 20)
        : _history;

    final Map<String, dynamic> requestBody = {
      'messages': recentHistory,
      // Explicit language contract. `language` stays as the field older
      // deployments understand; the three below are the authoritative ones
      // and the Worker resolves from them in that order. They are not
      // competing duplicates — `language` is the legacy alias of
      // `responseLanguage`, and the server treats it as the lowest-priority
      // spelling of the same thing.
      'language': language,
      'responseLanguage': language,
      'userLocale': userLocale ?? LanguagePolicy.localeFor(language),
      'contentLanguage': contentLanguage ?? language,
      'allowLanguageFallback': allowLanguageFallback,
    };
    final contextJson = context.toJson();
    if (contextJson != null) requestBody['context'] = contextJson;

    final headers = <String, String>{'Content-Type': 'application/json'};
    String endpoint;
    if (_useProxy) {
      endpoint = _proxyUrl;
      // Always fetch a FRESH Firebase ID token per request (force-refresh) —
      // never reuse/cache a token across a long session, since a stale one
      // can expire mid-session and would otherwise 401 forever.
      String? token;
      try {
        token = await idTokenProvider?.call();
      } catch (_) {
        token = null;
      }
      if (token == null || token.isEmpty) {
        // No authenticated user (or the token provider isn't wired up):
        // report this distinctly instead of attempting a request that the
        // server will reject, and instead of a generic failure state.
        _history.removeLast();
        return AssistantResponse.signInRequired(language);
      }
      headers['Authorization'] = 'Bearer $token';
    } else {
      // Direct-mode (dev only) does not speak the structured contract —
      // it talks straight to Groq with a minimal local system prompt.
      endpoint = _directEndpoint;
      headers['Authorization'] = 'Bearer $_apiKey';
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(endpoint),
            headers: headers,
            body: utf8.encode(_useProxy
                ? jsonEncode(requestBody)
                : _directPayload(recentHistory, language)),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      _history.removeLast();
      return AssistantResponse.offline(_offlineEntry(trimmed, language));
    }

    final respBody = utf8.decode(response.bodyBytes);

    if (response.statusCode == 401) {
      _history.removeLast();
      // Token was rejected as invalid/expired by the server: same distinct
      // sign-in-required state as having no token at all, never a generic
      // error — this also avoids a silent permanent 401 loop, since the UI
      // can react by prompting a fresh sign-in rather than retrying blindly.
      return AssistantResponse.signInRequired(language);
    }
    if (response.statusCode != 200) {
      _history.removeLast();
      // Never surface raw provider errors/status/config to the user.
      return AssistantResponse.unverified(language,
          notice: 'assistant_unavailable');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(respBody) as Map<String, dynamic>;
    } catch (_) {
      _history.removeLast();
      return AssistantResponse.unverified(language,
          notice: 'assistant_bad_response');
    }

    if (_useProxy) {
      final structured = AssistantResponse.fromJson(data, language);
      _history.add({'role': 'assistant', 'content': structured.answer});
      return structured;
    }

    // Direct dev-mode: plain Groq chat-completions shape, not structured.
    final choices = data['choices'] as List?;
    final content = (choices != null && choices.isNotEmpty)
        ? ((choices.first['message']['content'] as String?) ?? '').trim()
        : '';
    if (content.isEmpty) {
      _history.removeLast();
      return AssistantResponse.unverified(language,
          notice: 'assistant_bad_response');
    }
    _history.add({'role': 'assistant', 'content': content});
    return AssistantResponse(
      answer: content,
      language: language,
      grounded: false,
      confidence: 'low',
      citations: const [],
      requiresHumanGuide: false,
    );
  }

  String _directPayload(
    List<Map<String, String>> recentHistory,
    String language,
  ) {
    // Internal prompts stay in English for consistency and model reliability,
    // whatever language the reply is in.
    //
    // This previously said "reply in the same language as the user", which
    // made the MODEL decide — the one thing the language policy forbids. The
    // resolved language is injected instead, so the dev path cannot disagree
    // with the production path.
    final systemPrompt =
        "You are 'Dhakker', a Hajj/Umrah assistant (dev direct-mode, no retrieval). "
        'LANGUAGE POLICY: reply in "$language". This was resolved from the '
        "user's app settings, not from the language of their message; do not "
        'switch languages because their message looks like another language. '
        'Never translate, paraphrase, or alter Quranic verses, verified '
        'supplications, or other religious quotations — quote them exactly or '
        'not at all. For disputed fiqh questions, do not issue fatwas — '
        'recommend an authorized on-site guide.';
    return jsonEncode({
      'model': _directModel,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        ...recentHistory,
      ],
      'temperature': 0.4,
      'max_tokens': 800,
    });
  }

  void clearHistory() => _history.clear();

  // ─── Offline fallback ──────────────────────────────────────────────────
  // Deterministic and non-generative, used only when there is no network
  // connectivity at all. Contains NO religious or ritual guidance: a ritual
  // question offline yields a referral to approved saved guidance or an
  // authorized human guide, never a claim made by this app. See
  // `OfflineKnowledgeRepository` (lib/data) for why.
  OfflineKnowledgeEntry _offlineEntry(String msg, String language) {
    return OfflineKnowledgeRepository.replyFor(msg, language);
  }
}
