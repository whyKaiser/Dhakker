# Dhakker — مرشد الحاج

## نوع المشروع
تطبيق Flutter + Firebase — مرشد الحاج/المعتمر بالـ GPS والـ Geofencing

## مسار المشروع
`C:\Users\User\StudioProjects\dhakker`

## البيئة
- Flutter: `C:\flutter_windows_3.24.2-stable\flutter\bin\flutter.bat`
- المحاكي: Pixel_4_XL_API_36
- Firebase: مشروع `dhakker-160d0` — حساب `chanooh515@gmail.com`
- اسم الحزمة: `com.dhakker.app`
- الإصدار: 1.0.0+1

## ما أُنجز
- ✅ عدّ الطواف (GPS + بوصلة + Kalman filter)
- ✅ عدّ السعي (GPS + pedometer + dead-reckoning)
- ✅ ربط العدّادات بمناطقها (تظهر فقط داخل المنطقة)
- ✅ مساعد ذكي (Groq llama-3.3-70b) مع TTS + STT
- ✅ منظومة تنبيهات للأدمن
- ✅ لوحة ازدحام لحظية للأدمن
- ✅ نظام SOS (واتساب + Firestore)
- ✅ قواعد Firestore + Storage (منشورة)
- ✅ أيقونة احترافية + splash
- ✅ شاشة About/Privacy

## ملفات مهمة
- المنطق الرئيسي: `lib/bloc/cubit.dart`
- المساعد: `lib/services/assistant_service.dart`
- فلتر الموقع: `lib/shared/location/location_smoother.dart`
- وكيل Cloudflare: `assistant-proxy/worker.js` (منشور على `https://dhakker-proxy.songokualshareef.workers.dev`، والمفتاح GROQ_API_KEY محفوظ كـ Secret عليه)

## مناطق GPS المهمة
- المطاف (Z_MATAF): polygon، centroid ≈ (21.422487, 39.826206)
- الصفا (Z_SAFA): centroid ≈ (21.42193, 39.82754)
- المروة (Z_MARWAH): centroid ≈ (21.42529, 39.82709)

## المتبقّي للنشر (إجراءات يدوية فقط)
1. حساب Google Play + رفع ($25)
2. اختبار ميداني بجوال حقيقي (معايرة المستشعرات)
3. نشر Cloudflare Worker للمساعد الذكي
4. (اختياري) iOS / لغات إضافية

## ملاحظة الـ Groq API Key
- تطوير: `--dart-define=GROQ_API_KEY=...`
- إنتاج: عبر Proxy `--dart-define=ASSISTANT_PROXY_URL=...`
