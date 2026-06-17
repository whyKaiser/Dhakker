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

    http.Response response;
    try {
      response = await http
          .post(Uri.parse(endpoint), headers: headers, body: utf8.encode(payload))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // شبكة منقطعة — رد offline
      _history.removeLast(); // نسحب رسالة المستخدم لأنها لم تُرسَل
      return _offlineReply(trimmed);
    }

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

  // ─── ردود بدون إنترنت ────────────────────────────────────────────────────────
  // قاموس بسيط: أسئلة شائعة → ردود جاهزة. يُفعَّل عند انقطاع الشبكة.
  String _offlineReply(String msg) {
    final q = msg.toLowerCase();

    // الطواف
    if (q.contains('طواف') || q.contains('tawaf') || q.contains('circumambulat')) {
      return 'الطواف سبعة أشواط حول الكعبة المشرفة عكس اتجاه عقارب الساعة، '
          'يبدأ وينتهي بمحاذاة الحجر الأسود. الاضطباع والرمل في الأشواط الثلاثة الأولى '
          'مستحبان للرجال في طواف القدوم فقط.';
    }

    // السعي
    if (q.contains('سعي') || q.contains('sai') || q.contains('safa') ||
        q.contains('marwa') || q.contains('صفا') || q.contains('مروة')) {
      return 'السعي سبعة أشواط بين الصفا والمروة، يبدأ من الصفا وينتهي عند المروة. '
          'الهرولة للرجال في الجزء المضاء بالأخضر. ركن من أركان الحج والعمرة.';
    }

    // الإحرام
    if (q.contains('إحرام') || q.contains('احرام') || q.contains('ihram') ||
        q.contains('ميقات') || q.contains('miqat')) {
      return 'الإحرام: النية + لبس ثوبي الإحرام (للرجال) عند الميقات، والتلبية '
          '(لبيك اللهم لبيك). محظوراته: قص الشعر والأظافر، الطيب، الصيد، عقد النكاح، '
          'وغطاء الرأس للرجل.';
    }

    // الجمرات / رمي
    if (q.contains('جمر') || q.contains('رمي') || q.contains('jamarat') ||
        q.contains('stoning') || q.contains('pebble')) {
      return 'رمي الجمرات: سبع حصيات لكل جمرة، تُرمى من اليوم العاشر. '
          'جمرة العقبة (الكبرى) وحدها يوم النحر، ثم الثلاث (صغرى ثم وسطى ثم كبرى) '
          'أيام التشريق بعد الزوال.';
    }

    // عرفة
    if (q.contains('عرفة') || q.contains('عرفات') || q.contains('arafat') ||
        q.contains('arafah')) {
      return 'الوقوف بعرفة ركن الحج الأعظم: «الحج عرفة». وقته من زوال اليوم التاسع '
          'حتى فجر العاشر. الخروج منه بعد غروب الشمس إلى مزدلفة.';
    }

    // الهدي / الذبح / الأضحية
    if (q.contains('هدي') || q.contains('ذبح') || q.contains('نحر') ||
        q.contains('sacrifice') || q.contains('slaughter')) {
      return 'الهدي واجب على المتمتع والقارن. يُذبح يوم العيد (العاشر) أو أيام التشريق. '
          'إن عجز عنه صام ثلاثة أيام في الحج وسبعة إذا رجع.';
    }

    // دعاء / تلبية
    if (q.contains('دعاء') || q.contains('تلبية') || q.contains('talbiyah') ||
        q.contains('supplication') || q.contains('prayer')) {
      return 'التلبية: «لبيك اللهم لبيك، لبيك لا شريك لك لبيك، إن الحمد والنعمة لك '
          'والملك، لا شريك لك». تُقال من الإحرام حتى رمي جمرة العقبة.';
    }

    // طواف الوداع
    if (q.contains('وداع') || q.contains('farewell') || q.contains('ifadah') ||
        q.contains('إفاضة')) {
      return 'طواف الإفاضة ركن لا يصح الحج بدونه، ويُؤدَّى يوم النحر أو بعده. '
          'طواف الوداع واجب على من أراد السفر — آخر عمل في الحج.';
    }

    // الإنترنت / offline
    if (q.contains('انترنت') || q.contains('شبكة') || q.contains('offline') ||
        q.contains('internet')) {
      return 'أنا في وضع عدم الاتصال الآن. يمكنني الإجابة عن أسئلة المناسك الأساسية '
          'من ذاكرتي. للأسئلة التفصيلية راجع المرشد أو العالم في مخيمك.';
    }

    // الرد الافتراضي
    return '⚠️ لا يوجد اتصال بالإنترنت الآن.\n'
        'يمكنني الإجابة عن الأسئلة الأساسية للمناسك (طواف / سعي / إحرام / جمرات / عرفة). '
        'حاول إعادة صياغة سؤالك.';
  }
}
