/**
 * Dhakker — وسيط المساعد الذكي (Cloudflare Worker مجاني).
 *
 * الغرض: يحمل مفتاح Groq على الخادم فلا يُشحن داخل تطبيق الجوال إطلاقاً.
 * التطبيق يرسل رسائل المحادثة لهذا الوسيط، والوسيط يضيف المفتاح ويمرّرها لـ Groq.
 *
 * الإعداد:
 *   1) أنشئ Worker مجاني على https://workers.cloudflare.com (حساب مجاني).
 *   2) الصق هذا الملف كاملاً في الـ Worker.
 *   3) من Settings → Variables أضف متغيّراً سرّياً:  GROQ_API_KEY = مفتاحك
 *   4) انشر، وخذ رابط الـ Worker (مثل https://dhakker.<اسمك>.workers.dev).
 *   5) ابنِ التطبيق به:
 *        flutter build apk --dart-define=ASSISTANT_PROXY_URL=https://dhakker.<اسمك>.workers.dev
 *
 * بعد ذلك يعمل المساعد بدون أي مفتاح داخل التطبيق — آمن للنشر.
 */

const GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";

export default {
  async fetch(request, env) {
    // نقبل POST فقط.
    if (request.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    let body;
    try {
      body = await request.json();
    } catch (_) {
      return jsonError("Invalid JSON body", 400);
    }

    // حماية أساسية: نتأكد من وجود قائمة الرسائل ونحدّ من حجمها.
    if (!Array.isArray(body.messages) || body.messages.length === 0) {
      return jsonError("messages array is required", 400);
    }
    if (body.messages.length > 40) {
      return jsonError("conversation too long", 413);
    }

    const payload = {
      model: body.model || "llama-3.3-70b-versatile",
      messages: body.messages,
      temperature: typeof body.temperature === "number" ? body.temperature : 0.4,
      max_tokens: typeof body.max_tokens === "number" ? body.max_tokens : 800,
    };

    const upstream = await fetch(GROQ_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        // المفتاح يُضاف هنا على الخادم — لا يصل للتطبيق أبداً.
        Authorization: `Bearer ${env.GROQ_API_KEY}`,
      },
      body: JSON.stringify(payload),
    });

    // نمرّر رد Groq كما هو ليطابق ما يتوقّعه التطبيق.
    const text = await upstream.text();
    return new Response(text, {
      status: upstream.status,
      headers: { "Content-Type": "application/json" },
    });
  },
};

function jsonError(message, status) {
  return new Response(JSON.stringify({ error: { message } }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
