import 'dart:convert';

import 'package:http/http.dart' as http;

/// خدمة المساعد الذكي للحج والعمرة.
///
/// تتصل بـ Groq (نموذج llama-3.3-70b-versatile) وتجيب عن أسئلة المناسك
/// **بنفس لغة سؤال المستخدم**، مع حفظ سجل المحادثة لإعطاء سياق متّصل.
///
/// أمان المفتاح: لا يُكتب المفتاح في الكود إطلاقاً. يُمرَّر وقت البناء عبر:
///   flutter run --dart-define=GROQ_API_KEY=القيمة
/// وللإنتاج يُفضّل وضعه خلف Proxy (خادم) فلا يصل للجهاز أصلاً.
class AssistantService {
  // المفتاح المباشر — للتطوير فقط. للإنتاج استخدم Proxy فلا يصل المفتاح للجهاز.
  static const String _apiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  // عنوان الـ Proxy (Cloudflare Worker مثلاً). عند ضبطه يكلّم التطبيق الـ Proxy
  // بدل Groq مباشرة، فالمفتاح يبقى على الخادم ولا يُشحن داخل التطبيق إطلاقاً:
  //   flutter build apk --dart-define=ASSISTANT_PROXY_URL=https://...workers.dev
  static const String _proxyUrl =
      String.fromEnvironment('ASSISTANT_PROXY_URL', defaultValue: '');

  bool get _useProxy => _proxyUrl.isNotEmpty;

  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  // البرومبت بالإنجليزية عمداً: النماذج تتبع التعليمات الإنجليزية بدقة أعلى،
  // وأهمها قاعدة الرد بنفس لغة المستخدم (كان البرومبت العربي يميل للعربية دائماً).
  static const String _systemPrompt =
      "You are 'Dhakker', a kind and knowledgeable assistant for Hajj and Umrah "
      "pilgrims. You answer questions about the rituals (Ihram, Tawaf, Sa'i, "
      "shaving/trimming, supplications, and common mistakes) accurately, clearly, "
      "and concisely, with a warm and compassionate tone — many users are elderly, "
      "first-time pilgrims, or non-Arabic speakers.\n\n"
      "ABSOLUTELY CRITICAL: Reply in EXACTLY the same language the user wrote in. "
      "If the user writes in English, reply ONLY in English. If in Urdu, reply ONLY "
      "in Urdu. If in Turkish, French, Indonesian, etc., reply ONLY in that language. "
      "If in Arabic, reply in Arabic. Never switch languages and never mix languages.\n\n"
      "For disputed jurisprudential matters, do not issue fatwas; advise consulting a "
      "scholar or the on-site guide. If a question is outside Hajj/Umrah, kindly and "
      "briefly say so in the user's language.";

  final List<Map<String, String>> _history = [];

  /// سجل المحادثة (للعرض في الواجهة) — للقراءة فقط.
  List<Map<String, String>> get history => List.unmodifiable(_history);

  bool get isConfigured => _useProxy || _apiKey.isNotEmpty;

  /// يرسل رسالة المستخدم ويعيد رد المساعد نصاً. يرمي استثناءً عند الفشل.
  Future<String> ask(String userMessage) async {
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) return '';

    if (!isConfigured) {
      throw Exception(
        'مفتاح Groq غير مُمرَّر. شغّل التطبيق بـ '
        '--dart-define=GROQ_API_KEY=مفتاحك (أو اضبط ASSISTANT_PROXY_URL للإنتاج)',
      );
    }

    _history.add({'role': 'user', 'content': trimmed});

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
      ..._history,
    ];

    final payload = jsonEncode({
      'model': _model,
      'messages': messages,
      'temperature': 0.4,
      'max_tokens': 800,
    });

    // عند وجود Proxy نكلّمه بدل Groq مباشرة، ولا نرسل أي مفتاح من التطبيق.
    final endpoint = _useProxy ? _proxyUrl : _endpoint;

    // package:http يعمل على الجوال والويب معاً (بخلاف dart:io الخاص بالجوال فقط).
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (!_useProxy) headers['Authorization'] = 'Bearer $_apiKey';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: headers,
      body: utf8.encode(payload),
    );

    final respBody = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw Exception('Assistant API ${response.statusCode}: $respBody');
    }

    final data = jsonDecode(respBody) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('استجابة غير متوقعة من الخادم.');
    }

    final content =
        (choices.first['message']['content'] as String? ?? '').trim();
    _history.add({'role': 'assistant', 'content': content});
    return content;
  }

  /// يمسح سجل المحادثة لبدء محادثة جديدة.
  void clearHistory() => _history.clear();
}
