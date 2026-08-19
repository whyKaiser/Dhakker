import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/offline_knowledge_repository.dart';

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

  bool get isValid => documentId.isNotEmpty && title.isNotEmpty && authority.isNotEmpty;
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
  final String? recommendedAction;
  final bool requiresHumanGuide;
  final String? safetyNotice;
  final bool isOffline;
  final bool signInRequired;

  const AssistantResponse({
    required this.answer,
    required this.language,
    required this.grounded,
    required this.confidence,
    required this.citations,
    this.recommendedAction,
    required this.requiresHumanGuide,
    this.safetyNotice,
    this.isOffline = false,
    this.signInRequired = false,
  });

  factory AssistantResponse.fromJson(Map<String, dynamic> json, String requestedLanguage) {
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
    final requiresHumanGuide = !grounded ? true : (json['requiresHumanGuide'] == true);

    return AssistantResponse(
      answer: answer.isEmpty ? _unverifiedAnswer(requestedLanguage) : answer,
      language: (json['language'] as String?) ?? requestedLanguage,
      grounded: grounded,
      confidence: confidence,
      citations: citations,
      recommendedAction: json['recommendedAction'] as String?,
      requiresHumanGuide: requiresHumanGuide,
      safetyNotice: json['safetyNotice'] as String?,
    );
  }

  factory AssistantResponse.offline(String text, String language) {
    return AssistantResponse(
      answer: text,
      language: language,
      grounded: false,
      confidence: 'low',
      citations: const [],
      requiresHumanGuide: false,
      isOffline: true,
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
  final String? ritual; // e.g. tawaf, sai, ihram, arafat, muzdalifah, jamarat, tawaf_wadaa
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
  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  static const String _compiledProxyUrl = String.fromEnvironment('ASSISTANT_PROXY_URL', defaultValue: '');

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
  bool get _useDirectDevMode => !_useProxy && !_isReleaseBuild && _apiKey.isNotEmpty;

  static const String _directEndpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _directModel = 'llama-3.3-70b-versatile';

  final List<Map<String, String>> _history = [];

  List<Map<String, String>> get history => List.unmodifiable(_history);

  bool get isConfigured => _useProxy || _useDirectDevMode;

  /// Sends a message with the requested reply [language] (ISO code among
  /// ar/en/ur/tr/id/fr) and an optional consent-gated [context].
  /// Never throws for expected failure modes — always returns a safe
  /// [AssistantResponse] (offline fallback, or "cannot verify" fallback).
  Future<AssistantResponse> ask(
    String userMessage, {
    String language = 'en',
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
      'language': language,
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
            body: utf8.encode(_useProxy ? jsonEncode(requestBody) : _directPayload(recentHistory)),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      _history.removeLast();
      return AssistantResponse.offline(_offlineReply(trimmed, language), language);
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
      return AssistantResponse.unverified(language, notice: 'assistant_unavailable');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(respBody) as Map<String, dynamic>;
    } catch (_) {
      _history.removeLast();
      return AssistantResponse.unverified(language, notice: 'assistant_bad_response');
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
      return AssistantResponse.unverified(language, notice: 'assistant_bad_response');
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

  String _directPayload(List<Map<String, String>> recentHistory) {
    const systemPrompt =
        "You are 'Dhakker', a Hajj/Umrah assistant (dev direct-mode, no retrieval). "
        'Reply in the same language as the user. For disputed fiqh questions, '
        'do not issue fatwas — recommend an authorized on-site guide.';
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

  // ─── Offline fixed-fact fallback ───────────────────────────────────────
  // Deterministic, non-generative answers for a handful of common topics —
  // used only when there is no network connectivity at all. Not a
  // replacement for grounded retrieval; content lives in the versioned,
  // language-aware `OfflineKnowledgeRepository` (lib/data), which labels
  // every entry as unverified general knowledge (not citation-backed).
  String _offlineReply(String msg, String language) {
    final topic = OfflineKnowledgeRepository.topicFor(msg);
    return OfflineKnowledgeRepository.textFor(topic, language).text;
  }
}
