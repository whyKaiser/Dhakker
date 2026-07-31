/**
 * Dhakker — وسيط المساعد الذكي (Cloudflare Worker مجاني).
 *
 * الغرض: يحمل مفتاح Groq (والآن Gemini كاحتياطي) على الخادم فلا يُشحن أي
 * مفتاح داخل تطبيق الجوال إطلاقاً. التطبيق يرسل رسائل المحادثة لهذا الوسيط،
 * والوسيط يضيف المفتاح ويمرّرها لـ Groq، ولو فشل (شبكة/حد استخدام) يجرّب
 * Gemini تلقائياً ويعيد الرد بنفس شكل استجابة Groq حتى لا يحتاج التطبيق أي تعديل.
 *
 * الإعداد:
 *   1) أنشئ Worker مجاني على https://workers.cloudflare.com (حساب مجاني).
 *   2) الصق هذا الملف كاملاً في الـ Worker.
 *   3) من Settings → Variables أضف متغيّرين سرّيين:
 *        GROQ_API_KEY = مفتاح Groq
 *        GEMINI_API_KEY = مفتاح مشروع gemini-dhakker (احتياطي)
 *   4) انشر، وخذ رابط الـ Worker (مثل https://dhakker.<اسمك>.workers.dev).
 *   5) ابنِ التطبيق به:
 *        flutter build apk --dart-define=ASSISTANT_PROXY_URL=https://dhakker.<اسمك>.workers.dev
 *
 * بعد ذلك يعمل المساعد بدون أي مفتاح داخل التطبيق — آمن للنشر.
 */

const GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";
const GEMINI_ENDPOINT =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent";

// ترويسات CORS — تسمح لنسخة الويب (dhakker-160d0.web.app) بالاتصال بالوسيط
// من المتصفّح. بدونها يحجب المتصفّح الطلب رغم نجاحه على الجوال.
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
  "Access-Control-Max-Age": "86400",
};

export default {
  async fetch(request, env) {
    // طلب التحقّق المسبق (preflight) من المتصفّح.
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    // نقبل POST فقط.
    if (request.method !== "POST") {
      return new Response("Method Not Allowed", {
        status: 405,
        headers: CORS_HEADERS,
      });
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

    let upstream;
    try {
      upstream = await fetch(GROQ_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          // المفتاح يُضاف هنا على الخادم — لا يصل للتطبيق أبداً.
          Authorization: `Bearer ${env.GROQ_API_KEY}`,
        },
        body: JSON.stringify(payload),
      });
    } catch (_) {
      upstream = null; // خطأ شبكة — جرّب Gemini أدناه.
    }

    if (upstream && upstream.ok) {
      const text = await upstream.text();
      return new Response(text, {
        status: upstream.status,
        headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      });
    }

    // Groq فشل (شبكة أو حد استخدام) — احتياطي عبر Gemini إن توفّر مفتاحه.
    if (!env.GEMINI_API_KEY) {
      const text = upstream ? await upstream.text() : "";
      return new Response(
        text || JSON.stringify({ error: { message: "Groq unavailable" } }),
        {
          status: upstream ? upstream.status : 502,
          headers: { "Content-Type": "application/json", ...CORS_HEADERS },
        }
      );
    }

    try {
      const geminiReply = await askGemini(payload.messages, env.GEMINI_API_KEY);
      return new Response(
        JSON.stringify({ choices: [{ message: { role: "assistant", content: geminiReply } }] }),
        { status: 200, headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
      );
    } catch (error) {
      return jsonError(`Both providers failed: ${error.message}`, 502);
    }
  },
};

// يحوّل صيغة رسائل OpenAI/Groq (system + messages[]) إلى صيغة Gemini، ويعيد
// نص الرد فقط — حتى يبقى شكل استجابة الوسيط ثابت بغض النظر عن المزوّد الفعلي.
async function askGemini(messages, apiKey) {
  const systemMessage = messages.find((m) => m.role === "system");
  const turns = messages.filter((m) => m.role !== "system");

  const contents = turns.map((m) => ({
    role: m.role === "assistant" ? "model" : "user",
    parts: [{ text: m.content }],
  }));

  const body = {
    contents,
    ...(systemMessage
      ? { systemInstruction: { parts: [{ text: systemMessage.content }] } }
      : {}),
  };

  const response = await fetch(`${GEMINI_ENDPOINT}?key=${apiKey}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    throw new Error(`Gemini ${response.status}: ${await response.text()}`);
  }

  const data = await response.json();
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
  if (!text) throw new Error("Gemini returned an empty response");
  return text;
}

function jsonError(message, status) {
  return new Response(JSON.stringify({ error: { message } }), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}
