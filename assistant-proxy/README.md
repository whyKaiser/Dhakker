# تأمين مفتاح المساعد الذكي (مجاني)

الهدف: ألا يُشحن مفتاح Groq داخل تطبيق الجوال (يمكن استخراجه من الـ APK). الحل وسيط
مجاني على Cloudflare Workers يحمل المفتاح على الخادم.

## الخطوات (≈ 5 دقائق، مجاناً)

1. سجّل دخول/أنشئ حساباً مجانياً على <https://dash.cloudflare.com> → **Workers & Pages**.
2. **Create** → **Create Worker** → أعطه اسماً (مثل `dhakker`) → **Deploy**.
3. **Edit code** → احذف الموجود والصق محتوى [`worker.js`](./worker.js) كاملاً → **Deploy**.
4. **Settings → Variables and Secrets** → أضف:
   - الاسم: `GROQ_API_KEY`
   - القيمة: مفتاح Groq الحقيقي
   - اختر **Encrypt** (سرّي) → **Save**.
5. انسخ رابط الـ Worker (مثل `https://dhakker.<اسمك>.workers.dev`).

## بناء التطبيق ليستخدم الوسيط

```
flutter build apk --dart-define=ASSISTANT_PROXY_URL=https://dhakker.<اسمك>.workers.dev
```

عندها يعمل المساعد **بدون أي مفتاح داخل التطبيق** — جاهز وآمن للنشر.

## ملاحظات
- للتطوير المحلي يمكنك الاستمرار بـ `--dart-define=GROQ_API_KEY=...` (مباشر، بدون وسيط).
- إن ضُبط `ASSISTANT_PROXY_URL` فهو المقدّم دائماً ويُتجاهل المفتاح المباشر.
- الخطة المجانية في Cloudflare Workers تكفي لعشرات الآلاف من الطلبات يومياً.
- (اختياري لاحقاً) أضف في الوسيط تحققاً من هوية الطلب (مثل رأس سرّي) لمنع إساءة استخدام الرابط.
