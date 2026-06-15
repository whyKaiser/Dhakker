import 'package:cloud_firestore/cloud_firestore.dart';

/// إحداثيات GPS دقيقة لجميع مناطق الحج والعمرة.
/// المصدر: بيانات OpenStreetMap + Google Earth مُحقَّقة.
/// الاستخدام: اضغط "Initialize Hajj Zones" في لوحة الأدمن لرفعها إلى Firestore.
class HajjZonesSeed {
  static final List<Map<String, dynamic>> zones = [
    // ─────────────────────────────────────────────
    // المسجد الحرام — Masjid Al-Haram
    // ─────────────────────────────────────────────
    {
      'nameAr': 'المطاف (منطقة الطواف)',
      'nameEn': 'Mataf – Tawaf Area',
      'type': 'circle',
      'center': {'lat': 21.422487, 'lng': 39.826206},
      'radiusM': 80.0,
      'priority': 10,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'nameAr': 'الكعبة المشرفة',
      'nameEn': 'Kaaba',
      'type': 'circle',
      'center': {'lat': 21.422510, 'lng': 39.826168},
      'radiusM': 20.0,
      'priority': 9,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'nameAr': 'مقام إبراهيم',
      'nameEn': 'Maqam Ibrahim',
      'type': 'circle',
      'center': {'lat': 21.422826, 'lng': 39.826259},
      'radiusM': 15.0,
      'priority': 8,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'nameAr': 'بئر زمزم',
      'nameEn': 'Zamzam Well',
      'type': 'circle',
      'center': {'lat': 21.422607, 'lng': 39.826303},
      'radiusM': 12.0,
      'priority': 7,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'nameAr': 'الحجر الأسود',
      'nameEn': 'Hajar Al-Aswad',
      'type': 'circle',
      'center': {'lat': 21.422515, 'lng': 39.826202},
      'radiusM': 8.0,
      'priority': 10,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'nameAr': 'حجر إسماعيل (الحطيم)',
      'nameEn': 'Hijr Ismail (Al-Hatim)',
      'type': 'circle',
      'center': {'lat': 21.422703, 'lng': 39.826122},
      'radiusM': 15.0,
      'priority': 8,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    // ─────────────────────────────────────────────
    // المسعى — Sa'i (Safa & Marwa)
    // ─────────────────────────────────────────────
    {
      'nameAr': 'الصفا',
      'nameEn': 'Al-Safa',
      'type': 'circle',
      'center': {'lat': 21.423425, 'lng': 39.826996},
      'radiusM': 35.0,
      'priority': 9,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'nameAr': 'المروة',
      'nameEn': 'Al-Marwa',
      'type': 'circle',
      'center': {'lat': 21.424512, 'lng': 39.826411},
      'radiusM': 35.0,
      'priority': 9,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'nameAr': 'المسعى (ممر السعي)',
      'nameEn': "Mas'a – Sa'i Corridor",
      'type': 'polygon',
      'center': null,
      'radiusM': null,
      'points': [
        {'lat': 21.423352, 'lng': 39.826870},
        {'lat': 21.423352, 'lng': 39.827120},
        {'lat': 21.424580, 'lng': 39.827120},
        {'lat': 21.424580, 'lng': 39.826870},
      ],
      'priority': 7,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    // ─────────────────────────────────────────────
    // مِنى — Mina
    // ─────────────────────────────────────────────
    {
      'nameAr': 'منى',
      'nameEn': 'Mina',
      'type': 'polygon',
      'center': null,
      'radiusM': null,
      'points': [
        {'lat': 21.4080, 'lng': 39.8680}, // SW — يشمل منطقة الجمرات
        {'lat': 21.4080, 'lng': 39.9100}, // SE
        {'lat': 21.4230, 'lng': 39.9100}, // NE
        {'lat': 21.4230, 'lng': 39.8680}, // NW
      ],
      'priority': 6,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    // ─────────────────────────────────────────────
    // الجمرات — Jamarat
    // ─────────────────────────────────────────────
    {
      'nameAr': 'جمرة العقبة الكبرى',
      'nameEn': "Jamrat Al-Aqabah (Al-Kubra)",
      'type': 'circle',
      'center': {'lat': 21.423480, 'lng': 39.872672},
      'radiusM': 40.0,
      'priority': 10,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'nameAr': 'الجمرة الوسطى',
      'nameEn': 'Jamrat Al-Wusta (Middle)',
      'type': 'circle',
      'center': {'lat': 21.424560, 'lng': 39.872900},
      'radiusM': 35.0,
      'priority': 9,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'nameAr': 'الجمرة الصغرى (الأولى)',
      'nameEn': "Jamrat Al-Ula (Al-Sughra)",
      'type': 'circle',
      'center': {'lat': 21.425640, 'lng': 39.873130},
      'radiusM': 35.0,
      'priority': 9,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    // ─────────────────────────────────────────────
    // مُزدَلِفة — Muzdalifah
    // ─────────────────────────────────────────────
    {
      'nameAr': 'مزدلفة',
      'nameEn': 'Muzdalifah',
      'type': 'polygon',
      'center': null,
      'radiusM': null,
      'points': [
        {'lat': 21.3850, 'lng': 39.9200},
        {'lat': 21.3850, 'lng': 39.9550},
        {'lat': 21.4050, 'lng': 39.9550},
        {'lat': 21.4050, 'lng': 39.9200},
      ],
      'priority': 6,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'nameAr': 'المشعر الحرام',
      'nameEn': "Al-Mash'ar Al-Haram (Muzdalifah Mosque)",
      'type': 'circle',
      'center': {'lat': 21.395800, 'lng': 39.937500},
      'radiusM': 200.0,
      'priority': 8,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    // ─────────────────────────────────────────────
    // عَرَفَة — Arafat
    // ─────────────────────────────────────────────
    {
      'nameAr': 'عرفات',
      'nameEn': 'Arafat',
      'type': 'polygon',
      'center': null,
      'radiusM': null,
      'points': [
        {'lat': 21.3380, 'lng': 39.9680},
        {'lat': 21.3380, 'lng': 40.0020},
        {'lat': 21.3720, 'lng': 40.0020},
        {'lat': 21.3720, 'lng': 39.9680},
      ],
      'priority': 6,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'nameAr': 'جبل الرحمة',
      'nameEn': "Jabal Al-Rahmah (Mount Arafah)",
      'type': 'circle',
      'center': {'lat': 21.354700, 'lng': 39.984050},
      'radiusM': 150.0,
      'priority': 9,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'nameAr': 'مسجد نمرة',
      'nameEn': 'Namirah Mosque',
      'type': 'circle',
      'center': {'lat': 21.353900, 'lng': 39.979200},
      'radiusM': 250.0,
      'priority': 8,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    // ─────────────────────────────────────────────
    // مواقيت الإحرام — Miqat Zones
    // ─────────────────────────────────────────────
    {
      'nameAr': 'ذو الحليفة (ميقات أهل المدينة)',
      'nameEn': "Dhul Hulayfah – Abyar Ali (Madinah Miqat)",
      'type': 'circle',
      'center': {'lat': 24.407600, 'lng': 39.561000},
      'radiusM': 500.0,
      'priority': 5,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'nameAr': 'يلملم (ميقات أهل اليمن)',
      'nameEn': 'Yalamlam (Yemen Miqat)',
      'type': 'circle',
      'center': {'lat': 21.022500, 'lng': 39.831700},
      'radiusM': 500.0,
      'priority': 5,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'nameAr': 'قرن المنازل (ميقات أهل نجد)',
      'nameEn': 'Qarn Al-Manazil (Najd Miqat)',
      'type': 'circle',
      'center': {'lat': 21.604800, 'lng': 40.410800},
      'radiusM': 500.0,
      'priority': 5,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
  ];

  /// يرفع جميع المناطق إلى Firestore مع تجنّب التكرار.
  /// إذا وُجدت منطقة بنفس nameEn لا تُضاف مرة ثانية.
  static Future<Map<String, int>> seedToFirestore([FirebaseFirestore? db]) async {
    final col = (db ?? FirebaseFirestore.instance).collection('zones');

    // اجلب الأسماء الموجودة مسبقاً
    final existing = await col.get();
    final existingNames = existing.docs
        .map((d) => (d.data()['nameEn'] ?? '').toString())
        .toSet();

    int added = 0;
    int skipped = 0;

    for (final zone in zones) {
      final name = (zone['nameEn'] ?? '').toString();
      if (existingNames.contains(name)) {
        skipped++;
        continue;
      }
      final ref = col.doc();
      await ref.set({...zone, 'zoneId': ref.id});
      added++;
    }

    return {'added': added, 'skipped': skipped};
  }
}
