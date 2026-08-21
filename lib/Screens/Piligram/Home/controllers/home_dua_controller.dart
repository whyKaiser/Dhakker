import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../services/notification_service.dart';
import '../../../../shared/network/local/cash_helper.dart';
import '../models/supplication_model.dart';
import '../models/zone_model.dart';
import '../services/dua_playback_service.dart';
import '../services/supplication_service.dart';
import '../services/zone_detection_service.dart';

class HomeDuaController extends ChangeNotifier {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final ZoneDetectionService zoneDetectionService;
  final SupplicationService supplicationService;
  final DuaPlaybackService playbackService;

  HomeDuaController({
    required this.firestore,
    required this.auth,
    required this.zoneDetectionService,
    required this.supplicationService,
    required this.playbackService,
  });

  String get userId => auth.currentUser?.uid ?? '';

  bool isLoading = true;
  bool isPlaying = false;
  bool autoLocationEnabled = true;
  bool voiceNotificationsEnabled = true;

  Position? currentPosition;
  ZoneModel? currentZone;

  /// Static, in-memory mirror of the latest coarse [currentZone] detected by
  /// ANY live [HomeDuaController] instance. This is the single existing
  /// source of truth for "which coarse zone is the pilgrim in" — it is NOT a
  /// second GPS/zone stream, just a process-wide read-only snapshot of the
  /// same value this controller already computes, so other screens (e.g. the
  /// assistant) can consult it without owning their own location tracking.
  /// Never holds raw coordinates — only the already-coarsened [ZoneModel].
  static ZoneModel? lastKnownZone;

  // يُستدعى عند كل تحديث موقع، لتغذية عدّاد الأشواط في الكيوبيت أيضاً
  // (تغطية إضافية فوق خط الكيوبيت المستقل). حاجز الهيستيريسيس يمنع العدّ المزدوج.
  void Function(Position position)? onPositionUpdate;

  // 1. تغيير الدعاء الواحد إلى قائمة لدعم التعدد
  //
  // هذه القائمة خام: قد تحوي إرشادات (procedural_guidance) وهي ليست أدعية
  // تُتلىٰ. كل ما تعرضه الواجهة أو يُشغَّل صوتيًّا يمرّ عبر [recitableDuas]،
  // والإرشادات تُعرض منفصلة عبر [guidanceItems].
  List<SupplicationModel> currentDuasList = [];

  /// الأدعية والأذكار فقط — بلا إرشادات. هذا هو ما يُعرض ويُشغَّل.
  List<SupplicationModel> get recitableDuas => currentDuasList
      .where((e) => e.contentKind.belongsInDuaSection)
      .toList(growable: false);

  /// ما يجوز تشغيله تلقائيًّا عند دخول المنطقة.
  ///
  /// أضيق من [recitableDuas]: الزيادة الجائزة تُعرض للحاج ويستطيع تشغيلها
  /// بنفسه، لكنها لا تُقرأ عليه دون أن يطلبها. تشغيلها تلقائيًّا بعد النص
  /// الأساسي يجعلها تُسمع امتدادًا له — وهو بالضبط ما يوهم بلزومها.
  List<SupplicationModel> get autoPlayableDuas =>
      currentDuasList.where((e) => e.isAutoPlayable).toList(growable: false);

  /// الآثار المرويّة للفائدة — بطاقة «أثر موثّق» بعزوها، بلا تشغيل.
  /// بلا هذا الجامع تختفي من الشاشة الرئيسية بالكلية، لأن [recitableDuas]
  /// يستبعدها بحق و[guidanceItems] ليست مكانها.
  List<SupplicationModel> get evidenceItems => currentDuasList
      .where((e) => e.contentKind == SupplicationContentKind.contextualEvidence)
      .toList(growable: false);

  /// الإرشادات والأحكام — تُعرض في بطاقة منفصلة، ولا تُشغَّل صوتيًّا أبدًا.
  List<SupplicationModel> get guidanceItems => currentDuasList
      .where((e) => e.contentKind == SupplicationContentKind.proceduralGuidance)
      .toList(growable: false);

  String? errorMessage;

  // يمنع استدعاء notifyListeners بعد التخلّص من الكنترولر (يحدث عند إيقاف
  // الصوت أثناء dispose) فلا يتعطّل التطبيق.
  bool _disposed = false;

  List<ZoneModel> _zones = [];
  StreamSubscription<Position>? _positionSubscription;

  String? _lastTriggeredZoneId;
  String? _lastTriggeredDuaId;
  DateTime? _lastTriggerTimestamp;
  bool _isCurrentZoneHandled = false;
  String? _lastWrittenZoneId; // آخر نطاق كتبناه في حساب المستخدم (لحساب الكثافة الحقيقي)
  String? _lastFetchedZoneId; // آخر نطاق جلبنا أدعيته — يمنع إعادة الجلب كل تحديث موقع

  String _zoneKey(String key) => '${key}_$userId';

  Future<void> init(String langCode) async {
    isLoading = true;
    notifyListeners();

    // نضمن انتهاء التحميل دائماً (finally) حتى لو فشل أي شيء — مثل تعذّر
    // الاتصال بـ Firestore أول فتحة بشبكة ضعيفة — فلا تعلق الشاشة على "جاري التحميل".
    try {
      await playbackService.init();

      playbackService.onPlayingStateChanged = (value) {
        isPlaying = value;
        notifyListeners();
      };

      await _loadSettings();
      await _loadLastHandledState();
      await _loadZones();

      if (!autoLocationEnabled) {
        return;
      }

      await _startLocationTracking(langCode);
    } catch (e) {
      _log('فشل تهيئة الشاشة الرئيسية: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSettings() async {
    final autoValue = CashHelper.getCash(key: 'auto_location_enabled');
    final voiceValue = CashHelper.getCash(key: 'voice_notifications_enabled');

    autoLocationEnabled = autoValue is bool ? autoValue : true;
    voiceNotificationsEnabled = voiceValue is bool ? voiceValue : true;
  }

  Future<void> _loadLastHandledState() async {
    _lastTriggeredZoneId = CashHelper.getCash(
      key: _zoneKey('last_triggered_zone_id'),
    )?.toString();

    _lastTriggeredDuaId = CashHelper.getCash(
      key: _zoneKey('last_triggered_dua_id'),
    )?.toString();

    final rawMillis = CashHelper.getCash(
      key: _zoneKey('last_triggered_time'),
    );

    if (rawMillis is int) {
      _lastTriggerTimestamp = DateTime.fromMillisecondsSinceEpoch(rawMillis);
    }
  }

  /// يصفّر حالة آخر دعاء تم تشغيله (في الذاكرة والكاش).
  /// نستدعيها عند الخروج من النطاق حتى تُعامَل العودة كدخول جديد فيشتغل الدعاء.
  /// نخرج مبكراً إذا كانت الحالة مصفّرة أصلاً لتفادي كتابة الكاش في كل تحديث موقع
  /// أثناء وجود المستخدم خارج النطاقات.
  Future<void> _clearLastHandledState() async {
    if (_lastTriggeredZoneId == null &&
        _lastTriggeredDuaId == null &&
        _lastTriggerTimestamp == null) {
      return;
    }

    _lastTriggeredZoneId = null;
    _lastTriggeredDuaId = null;
    _lastTriggerTimestamp = null;

    await CashHelper.removeCash(key: _zoneKey('last_triggered_zone_id'));
    await CashHelper.removeCash(key: _zoneKey('last_triggered_dua_id'));
    await CashHelper.removeCash(key: _zoneKey('last_triggered_time'));
  }

  // يكتب النطاق الحالي في مستند المستخدم بـ Firestore، عشان لوحة التحكم
  // تحسب الكثافة وألوان الخريطة بشكل حقيقي. نكتب فقط عند تغيّر النطاق
  // (zoneId جديد، أو '' عند الخروج) لتقليل عمليات الكتابة على القاعدة.
  Future<void> _writeUserCurrentZone(String zoneValue) async {
    if (_lastWrittenZoneId == zoneValue) return;
    _lastWrittenZoneId = zoneValue;

    final uid = userId;
    if (uid.isEmpty) return;

    try {
      await firestore.collection('users').doc(uid).set({
        'currentZone': zoneValue,
        'currentZoneAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _log('تعذّر تحديث currentZone: $e');
    }
  }

  Future<void> _loadZones() async {
    try {
      final query = await firestore
          .collection('zones')
          .where('isActive', isEqualTo: true)
          .get();

      _zones = query.docs.map(ZoneModel.fromFirestore).toList();
      _zones.sort((a, b) => b.priority.compareTo(a.priority));
    } catch (e) {
      // عند تعذّر الاتصال نُبقي المناطق المحمّلة سابقاً (إن وُجدت) ولا نكسر التهيئة.
      _log('تعذّر تحميل المناطق: $e');
    }
  }

  Future<void> _startLocationTracking(String langCode) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();

    final hasPermission =
        permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse;

    if (!serviceEnabled || !hasPermission) {
      errorMessage = 'location_unavailable';
      notifyListeners();
      return;
    }

    final current = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    await _handlePosition(current, langCode);

    await _positionSubscription?.cancel();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).listen((position) async {
      await _handlePosition(position, langCode);
    });
  }

  Future<void> _handlePosition(Position position, String langCode) async {
    currentPosition = position;
    onPositionUpdate?.call(position);

    final detectedZone = zoneDetectionService.detectBestZone(
      userLat: position.latitude,
      userLng: position.longitude,
      zones: _zones,
    );

    if (detectedZone == null) {
      // خرج المستخدم من كل النطاقات: نصفّر حالة "تم التشغيل" في الذاكرة والكاش
      // حتى لو رجع لنفس النطاق مرة ثانية يشتغل الدعاء من جديد.
      currentZone = null;
      lastKnownZone = null;
      currentDuasList = []; // تصفير القائمة
      _isCurrentZoneHandled = false;
      _lastFetchedZoneId = null; // العودة للنطاق لاحقاً = جلب جديد للأدعية
      await _clearLastHandledState();
      await _writeUserCurrentZone(''); // تحديث التواجد: خارج كل النطاقات
      notifyListeners();
      return;
    }

    final previousZoneId = currentZone?.zoneId;
    currentZone = detectedZone;
    lastKnownZone = detectedZone;

    // تحديث حالة التواجد في حساب المستخدم (للكثافة وألوان الخريطة الحقيقية)
    await _writeUserCurrentZone(detectedZone.zoneId);

    // 2. جلب أدعية المنطقة عند تغيّرها فقط — لا عند كل تحديث موقع داخل نفس
    // المنطقة (يصل كل بضعة أمتار)، فذلك يهدر قراءات Firestore بلا فائدة.
    if (_lastFetchedZoneId != detectedZone.zoneId) {
      currentDuasList = await supplicationService.getSupplicationsByZone(
        detectedZone.zoneId,
        // الربط المفضَّل بالمعرّف الثابت: تعديل اسم المنطقة في لوحة الإدارة
        // يجب ألا يفصل نصوصها عنها.
        zoneKey: detectedZone.zoneKey,
      );
      _lastFetchedZoneId = detectedZone.zoneId;
    }

    // الإرشادات مستبعدة هنا: لا يُشغَّل حكمٌ أو توجيه عملي على أنه دعاء.
    // والزيادة الجائزة مستبعدة كذلك: تُعرض ويُشغّلها المستخدم بنفسه إن شاء.
    final playableCandidates = autoPlayableDuas;
    if (playableCandidates.isEmpty) {
      _isCurrentZoneHandled = false;
      notifyListeners();
      return;
    }

    // نختار أول دعاء "قابل للتشغيل" (له ملف صوتي أو نص غير فارغ بهذه اللغة)
    // حتى لا يطلع الدعاء صامتاً لو كان الأول بدون صوت ولا نص بهاللغة.
    SupplicationModel selected = playableCandidates.first;
    for (final d in playableCandidates) {
      final playable = (d.audioMode == 'file' && d.audioUrl.trim().isNotEmpty) ||
          d.textByLanguage(langCode).trim().isNotEmpty;
      if (playable) {
        selected = d;
        break;
      }
    }

    final isSameZone = previousZoneId == detectedZone.zoneId;
    final isSameHandledZone = _lastTriggeredZoneId == detectedZone.zoneId;
    final isSameHandledDua = _lastTriggeredDuaId == selected.duaId;

    if (!isSameZone) {
      _isCurrentZoneHandled = false;
    }

    final shouldAutoTrigger =
        !_isCurrentZoneHandled && !(isSameHandledZone && isSameHandledDua);

    if (shouldAutoTrigger) {
      if (voiceNotificationsEnabled) {
        // إشعار فوري بدخول المنطقة — يصل للحاج حتى لو كان على تبويب آخر داخل
        // التطبيق (يبقى فعّالاً ما دام التطبيق يعمل ويستقبل تحديثات الموقع).
        final isAr = langCode == 'ar';
        final zoneName = detectedZone.displayName(langCode);
        final duaTitle = selected.titleByLanguage(langCode).trim();
        NotificationService.instance.showZoneEntry(
          title: isAr ? 'دخلت: $zoneName' : 'Entered: $zoneName',
          body: duaTitle.isNotEmpty
              ? duaTitle
              // صياغة محايدة: لا ندّعي أن الدعاء مخصوص بهذا الموضع.
              : (isAr ? 'اضغط لقراءة الدعاء' : 'Tap to read the supplication'),
        );

        // تأخير بسيط يمنح الحاج لحظة يستقر فيها قبل أن يبدأ الدعاء
        await Future.delayed(const Duration(milliseconds: 1500));
        // نتحقق أن المستخدم لا يزال في نفس المنطقة بعد التأخير
        if (currentZone?.zoneId != detectedZone.zoneId) return;
        await playbackService.play(
          dua: selected,
          langCode: langCode,
        );
      }

      _isCurrentZoneHandled = true;
      _lastTriggeredZoneId = detectedZone.zoneId;
      _lastTriggeredDuaId = selected.duaId;
      _lastTriggerTimestamp = DateTime.now();

      await CashHelper.saveCash(
        key: _zoneKey('last_triggered_zone_id'),
        value: detectedZone.zoneId,
      );

      await CashHelper.saveCash(
        key: _zoneKey('last_triggered_dua_id'),
        value: selected.duaId,
      );

      await CashHelper.saveCash(
        key: _zoneKey('last_triggered_time'),
        value: _lastTriggerTimestamp!.millisecondsSinceEpoch,
      );
    }

    notifyListeners();
  }

  Future<void> refreshSettings(String langCode) async {
    await _loadSettings();

    if (!autoLocationEnabled) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      currentZone = null;
      lastKnownZone = null;
      currentDuasList = []; // تصفير القائمة
      _isCurrentZoneHandled = false;
      await playbackService.stop();
      notifyListeners();
      return;
    }

    if (_positionSubscription == null) {
      await _startLocationTracking(langCode);
    }

    notifyListeners();
  }

  // 3. تعديل دالة الضغط لتقبل رقم الدعاء (index) وتزيد العداد في Firestore
  Future<void> onPrimaryButtonTap(String langCode, int index) async {
    final items = recitableDuas;
    if (index < 0 || index >= items.length) return;

    final dua = items[index];

    // تحديث عداد التشغيل في قاعدة البيانات
    try {
      await firestore.collection('supplications').doc(dua.duaId).update({
        'usage_count': FieldValue.increment(1)
      });
      _log('تمت زيادة عداد التشغيل للدعاء: ${dua.duaId}');
    } catch (e) {
      _log('حدث خطأ أثناء تحديث عداد الاستخدام: $e');
    }

    await playbackService.replay(
      dua: dua,
      langCode: langCode,
    );
  }

  Future<void> stopPlayback() async {
    await playbackService.stop();
  }

  String? displayedZoneName(String langCode) {
    return currentZone?.displayName(langCode);
  }

  // 4. تعديل دوال جلب النصوص لتقبل الفهرس (index)
  String? displayedDuaTitle(String langCode, int index) {
    final items = recitableDuas;
    if (index < 0 || index >= items.length) return null;
    return items[index].titleByLanguage(langCode);
  }

  String? displayedDuaText(String langCode, int index) {
    final items = recitableDuas;
    if (index < 0 || index >= items.length) return null;
    return items[index].textByLanguage(langCode);
  }

  /// تصنيف الدعاء المعروض في هذا الموضع من القائمة — تستعمله الواجهة لعرض
  /// الوسم الصريح («عام» / «وارد في هذا الموضع»).
  SupplicationContentKind? displayedDuaKind(int index) {
    final items = recitableDuas;
    if (index < 0 || index >= items.length) return null;
    return items[index].contentKind;
  }

  void _log(String message) {
    debugPrint('DHKKR_HOME => $message');
  }

  // 5. تحديث المتغيرات التي تعتمد عليها واجهة المستخدم
  bool get hasDetectedZone => currentZone != null;
  // الإرشادات لا تُحسب دعاءً ولا تدخل في العدّ ولا في hasDua.
  bool get hasDua => recitableDuas.isNotEmpty;
  int get duasCount => recitableDuas.length; // متغير جديد لجلب عدد الأدعية

  /// يصنّف نُسُك المنطقة الحالية: 'tawaf' (المطاف) أو 'sai' (الصفا/المروة/المسعى)
  /// أو null لأي منطقة أخرى. تستخدمه الواجهة لإظهار العدّاد المناسب فقط.
  String? get currentRitual {
    final z = currentZone;
    if (z == null) return null;

    final id = z.zoneId;
    final name = '${z.nameEn} ${z.nameAr}'.toLowerCase();

    if (id == 'Z_MATAF' ||
        name.contains('tawaf') ||
        name.contains('mataf') ||
        name.contains('طواف') ||
        name.contains('مطاف')) {
      return 'tawaf';
    }

    if (id == 'Z_SAFA' ||
        id == 'Z_MARWA' ||
        id == 'Z_MARWAH' ||
        id == 'Z_MASAA' ||
        name.contains('safa') ||
        name.contains('marwa') ||
        name.contains('masaa') ||
        name.contains('mas3a') ||
        name.contains('صفا') ||
        name.contains('مروة') ||
        name.contains('مروه') ||
        name.contains('مسعى') ||
        name.contains('سعي')) {
      return 'sai';
    }

    return null;
  }

  // نتجاهل أي إشعار بعد التخلّص (يُستدعى أحياناً من callback إيقاف الصوت).
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // نفصل callback الصوت قبل التخلّص حتى لا يحدّث الحالة على كنترولر متدمّر.
    playbackService.onPlayingStateChanged = null;
    _positionSubscription?.cancel();
    playbackService.dispose();
    super.dispose();
  }
}