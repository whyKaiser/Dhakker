<div align="center">

<img src="assets/images/appIcon.png" width="110" alt="Dhakker logo"/>

# ذكّر — Dhakker

**رفيق الحاج والمعتمر الذكي — عدّاد طواف وسعي تلقائي، أدعية حسب موقعك، ومساعد ذكي يجيب على أسئلة المناسك**

*Smart GPS companion for Hajj & Umrah — automatic Tawaf/Sa'i counting, location-aware duas, and an AI assistant for rituals*

[![Flutter](https://img.shields.io/badge/Flutter-3.24-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Live-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Web App](https://img.shields.io/badge/Web-dhakker--160d0.web.app-4CAF50)](https://dhakker-160d0.web.app)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue)]()

[**🌐 جرّب التطبيق الآن — Live Demo**](https://dhakker-160d0.web.app)

</div>

---

## 💡 الفكرة

الحاج وسط زحام الملايين ما يحتاج تطبيق يشغله عن عبادته — يحتاج تطبيق **يشتغل عنه**.

ذكّر يعدّ أشواط الطواف والسعي **تلقائياً** بالـ GPS والبوصلة، ويعرض الدعاء المناسب **حسب مكانك** في الحرم، ويجاوب على أسئلة المناسك فوراً — حتى والشاشة مقفلة.

## ✨ المميزات

### للحاج والمعتمر
| الميزة | كيف تشتغل |
|--------|-----------|
| 🕋 **عدّاد الطواف التلقائي** | GPS + بوصلة مع فلتر Kalman — يعدّ الأشواط حول الكعبة بلا أي لمسة، ويتحقق من اتجاه الدوران (عكس عقارب الساعة) |
| 🚶 **عدّاد السعي التلقائي** | GPS + عدّاد خطوات + dead-reckoning — يميّز الوصول الفعلي للصفا والمروة حتى داخل المسعى المغطى |
| 📿 **أدعية حسب الموقع** | يعرض دعاء الطواف وأنت تطوف، ودعاء السعي وأنت تسعى — يتغير تلقائياً مع تنقلك بين مناطق الحرم |
| 🤖 **مساعد المناسك الذكي** | اسأل صوتاً أو كتابة عن أي حكم أو خطوة — يرد بالعربي مع نطق صوتي (TTS/STT) |
| 📖 **دليل المناسك** | شرح خطوة بخطوة لـ 9 مناسك + جدول أيام الحج (8–13 ذي الحجة) |
| 👨‍👩‍👧‍👦 **مجموعات العائلة** | كود `HAJJ-XXXX` يجمع عائلتك على خريطة واحدة — مشاركة الموقع بموافقة صريحة فقط |
| 🆘 **زر الطوارئ SOS** | إرسال موقعك فوراً عبر WhatsApp + إشعار مباشر لغرفة العمليات |
| 🔋 **ذكاء البطارية** | أعلى دقة GPS فقط داخل نطاق 120م من المطاف والمسعى — وضع توفير تلقائي في منى وعرفات والفندق |
| 📴 **يعمل والشاشة مقفلة** | خدمة أمامية (Foreground Service) تكمل عدّ الأشواط في جيبك |

### لغرفة العمليات (لوحة المشرف)
- 🗺️ **لوحة الزحام الحية** — خريطة حرارية متحركة لمناطق الحرم مع مؤشر LIVE
- 📢 **تنبيهات موجّهة** — إرسال تنبيه لمنطقة محددة (المطاف فقط، المسعى فقط...)
- 🚨 **مراقبة نداءات SOS** — استقبال ومتابعة وإغلاق الحالات
- 📍 **محرر مناطق تفاعلي** — رسم مناطق الحرم على الخريطة بنمط Google Maps

## 🏗️ البنية التقنية

```
Flutter (Dart) — واجهة واحدة لـ Android / iOS / Web
│
├── الموقع والحساسات
│     geolocator (bestForNavigation) · بوصلة · عدّاد خطوات
│     فلتر Kalman لتنعيم مسار GPS وسط تشويش المباني
│
├── Firebase
│     Firestore (أدعية · مناطق · مجموعات · تنبيهات فورية · SOS)
│     Hosting (نسخة الويب) · Crashlytics · قواعد أمان مشددة
│
└── المساعد الذكي
      Cloudflare Worker (proxy) → Groq LLM
      المفتاح السري محفوظ خادمياً — لا يلمس التطبيق أبداً
```

**قرارات تصميم أساسية:**
- **الخصوصية أولاً:** مشاركة الموقع في المجموعات اختيارية بالكامل (opt-in)، تُكتب كل 45 ثانية كحد أقصى، وقواعد Firestore تمنع أي قراءة من خارج أعضاء المجموعة
- **لا مفاتيح في الكود:** مفتاح الذكاء الاصطناعي في Cloudflare Worker Secret — العميل يتصل بالـ proxy فقط
- **دقة الأشواط قبل كل شيء:** العدّ لا يبدأ إلا بعد المرور الأول بنقطة البداية (تسليح العدّاد)، والدوران يُحتسب عكس عقارب الساعة فقط

## 🚀 التشغيل

```bash
# المتطلبات: Flutter 3.24+ ومشروع Firebase مهيأ
flutter pub get

# تشغيل تطويري
flutter run --dart-define=ASSISTANT_PROXY_URL=<رابط الـ proxy>

# بناء الإنتاج
flutter build apk --release --dart-define=ASSISTANT_PROXY_URL=<رابط الـ proxy>
flutter build web --release --dart-define=ASSISTANT_PROXY_URL=<رابط الـ proxy>
firebase deploy --only hosting
```

## 📱 التجربة

| المنصة | الرابط |
|--------|--------|
| 🌐 ويب | [dhakker-160d0.web.app](https://dhakker-160d0.web.app) |
| 🤖 Android | APK من صفحة Releases |
| 🍎 iOS | IPA عبر Sideloadly (بناء Codemagic) |

---

<div align="center">

**ذكّر — عبادتك أولاً، والتقنية تخدمك بصمت** 🕋

</div>
