import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dhakker/bloc/states.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:dhakker/Screens/Piligram/Home/home_screen.dart';
import 'package:dhakker/Screens/Piligram/Map/map_screen.dart';
import '../Screens/Piligram/Duas/duas_screen.dart';
import '../Screens/Piligram/Settings/settings_screen.dart';
import '../Screens/Assistant/assistant_screen.dart';
import '../shared/network/local/cash_helper.dart';
import '../shared/location/location_smoother.dart';
import '../locale_controller.dart';
import '../services/group_service.dart';
import '../services/notification_service.dart';
import '../services/heat_monitor_service.dart';
import '../services/hajj_schedule_service.dart';
import '../services/broadcast_listener_service.dart';

class AppCubit extends Cubit<AppStates> {
  AppCubit() : super(AppInitialState()) {
    loadRoundState();
  }

  static AppCubit get(BuildContext context) => BlocProvider.of(context);

  int currentScreen = 0;

  final List<Widget> screens = [
    const HomeScreen(),
    const MapScreen(),
    const DuasScreen(),
    const AssistantScreen(),
    const SettingsScreen(),
  ];

  void changeScreen(int index) {
    currentScreen = index;
    emit(AppChangeBottomNavState());
  }

  // ==========================================
  // --- منطق عد الأشواط الذكي والقبلة اللحظية ---
  // ==========================================
  int roundCount = 0;

  // نقطة بداية الشوط (محاذاة الحجر الأسود افتراضياً).
  // قابلة للضبط من النطاقات المخزّنة في Firestore عبر setTawafStartPoint.
  double startLat = 21.422487;
  double startLng = 39.826206;

  bool hasExitedThreshold = true;

  // ----- عدّ السعي (الصفا ↔ المروة) -----
  // شوط السعي = عبور كامل من طرف إلى الطرف الآخر. الإجمالي 7 أشواط.
  int saiCount = 0;

  // مراكز الصفا والمروة الافتراضية (تُستبدل بقيم Firestore عند توفّرها).
  // مطابقة لإحداثيات النطاقات الحقيقية في قاعدة البيانات — لو فشل التحميل
  // (أول تشغيل بدون إنترنت) يبقى العدّ صحيحاً ولا يحتسب أشواطاً وهمية.
  double safaLat = 21.42193;
  double safaLng = 39.82754;
  double marwaLat = 21.42529;
  double marwaLng = 39.82709;

  // آخر طرف سجّلنا الوصول إليه: 'safa' أو 'marwa' أو null قبل البداية.
  String? _lastSaiEnd;

  // ----- عدّ السعي بالخطى (Dead Reckoning) — مكمّل لـ GPS في الممر المغطّى -----
  // المسعى ممر مغطّى يضعف فيه GPS؛ نقيس المسافة بالخطى: إذا مشى الحاج ما يقارب
  // طول الممر (المحسوب من مركزي الصفا والمروة) منذ آخر طرف، نستنتج وصوله للطرف
  // المقابل. يكمّل GPS ولا يكسره: لو غاب حسّاس الخطى يبقى عدّ GPS كما هو.
  static const double _stepLengthM = 0.72; // طول الخطوة (متر) — يُعاير بالتجربة
  static const double _saiStepFactor = 0.85; // نسبة من طول الممر تكفي للاحتساب
  StreamSubscription<StepCount>? _stepSubscription;
  int _currentSteps = 0; // عدد الخطى التراكمي من الحسّاس
  int _stepBaseline = 0; // الخطى عند آخر طرف مُسجّل (نقيس المسافة منه)

  // ----- GPS متكيّف مع الحركة (توفير بطارية) -----
  // عند المشي: دقة عالية للعدّ. عند الوقوف: دقة أقل وفاصل أكبر لتوفير البطارية،
  // دون التأثير على العدّ لأن الأشواط تكتمل أثناء المشي لا الوقوف.
  StreamSubscription<PedestrianStatus>? _pedestrianSubscription;
  bool _isWalking = true; // الافتراضي مشي حتى يصلنا خلاف ذلك من الحسّاس

  // نصف قطر الوصول للطرف (متر): دخول هذا النطاق حول مركز الصفا/المروة يُعتبر
  // وصولاً للطرف. موسّع قليلاً لأن المنطقتين مضلّعان أكبر من نقطة.
  static const double _saiArrivalRadiusM = 35.0;

  static const String _kSaiCountKey = 'sai_count';
  static const String _kSaiLastEndKey = 'sai_last_end';

  // مفاتيح حفظ حالة العدّاد محلياً حتى لا تضيع عند إغلاق التطبيق أو إعادة تشغيله.
  static const String _kRoundCountKey = 'tawaf_round_count';
  static const String _kHasExitedKey = 'tawaf_has_exited';

  // أقصى دقة GPS (بالمتر) نقبلها عند العدّ. القراءات الأسوأ من هذا الحد
  // نتجاهلها حتى لا تُحتسب أشواط وهمية بسبب قفزات الإشارة في الزحام.
  static const double _roundAccuracyLimitM = 25.0;

  StreamSubscription<Position>? _roundSubscription;

  // ----- مشاركة الموقع مع المجموعة (اختيارية، بموافقة صريحة من الحاج) -----
  // نعيد استخدام نفس خط الموقع الموجود ونكتب كل ٤٥ ثانية فقط، فلا نستنزف
  // البطارية ولا نُكثر الكتابة على Firestore.
  final GroupService _groupService = GroupService();
  String? groupShareId; // معرّف المجموعة التي نشارك موقعنا معها (null = لا مشاركة)
  bool groupSharing = false;
  int _lastGroupWriteMs = 0;

  // فلتر تنعيم الموقع لتقليل اهتزاز GPS قبل احتساب الأشواط/السعي.
  final KalmanLatLong _locationFilter = KalmanLatLong(qMetresPerSecond: 3);

  bool _heatMonitorStarted = false;

  double userHeading = 0.0;
  StreamSubscription? _compassSubscription;
  double _lastEmittedHeading = -999; // لتقليل إعادة البناء على كل نبضة بوصلة

  // ===========================================================
  // --- كشف شوط الطواف بالبوصلة (دوران 360°) كمكمّل لعدّ GPS ---
  // الطواف دوران كامل حول الكعبة؛ نجمع تغيّر اتجاه البوصلة، وكل دورة
  // كاملة = شوط. يعمل حتى لو ضعف GPS، ولا يكسر عدّ GPS إن غابت البوصلة.
  // ===========================================================

  // ----- ثوابت المعايرة (تُضبط بالتجربة على جهاز حقيقي من هنا فقط) -----
  // درجات الدوران المطلوبة لاحتساب شوط. أقل قليلاً من 360 لتحمّل القراءات
  // المفقودة، وأعلى من اللازم لتفادي العدّ المبكر.
  static const double _tawafLapDegrees = 350.0;
  // أقل زمن (ثانية) بين شوطين — يمنع العدّ المزدوج من مصدرين (GPS + بوصلة).
  static const int _minLapSeconds = 12;
  // أقصى مسافة (متر) من مركز المطاف نسمح فيها بالعدّ بالبوصلة — تمنع احتساب
  // شوط لو لفّ الحاج جواله في مكان آخر بعيد عن الطواف.
  static const double _tawafProximityM = 120.0;

  // أقصى مسافة (متر) من الصفا/المروة نعتبرها "قرب منطقة سعي" لترفيع دقة GPS.
  static const double _saiProximityM = 120.0;

  double _accumulatedRotation = 0.0; // مجموع الدوران منذ آخر شوط (بالدرجات)
  double? _lastHeading; // آخر زاوية بوصلة لحساب الفرق
  // أول مرور بنقطة البداية = بداية الشوط الأول لا شوطاً مكتملاً؛ هذا العلم
  // يمنع احتساب +1 لمجرد الاقتراب الأول من النقطة قبل إكمال أي دورة.
  bool _tawafArmed = false;
  bool _nearTawaf = false; // هل آخر موقع GPS قريب من المطاف؟
  bool _nearSai = false; // هل آخر موقع GPS قريب من الصفا/المروة؟

  /// Real-time "is a Tawaf lap in progress right now" signal — based on live
  /// GPS proximity to the Tawaf start point AND an incomplete lap count, NOT
  /// merely "roundCount > 0" (which stays true for hours after Tawaf ends and
  /// would wrongly label a finished ritual as still active).
  bool get isTawafActive => _nearTawaf && roundCount < 7;

  /// Same real-time signal for Sa'i — see [isTawafActive].
  bool get isSaiActive => _nearSai && saiCount < 7;
  // وضع الدقة القصوى لـ GPS: يُفعَّل فقط قرب مناطق العدّ (طواف/سعي) لتوفير
  // البطارية في باقي الأماكن (منى/عرفات/الفندق...) دون التأثير على دقة العدّ.
  bool _highAccuracyMode = false;
  int _lastLapMs = 0; // وقت آخر شوط (للحارس الزمني)

  /// تحميل حالة العدّاد المحفوظة (يُستدعى مرة عند إنشاء الكيوبيت).
  void loadRoundState() {
    final savedCount = CashHelper.getCash(key: _kRoundCountKey);
    final savedExited = CashHelper.getCash(key: _kHasExitedKey);
    if (savedCount is int) roundCount = savedCount;
    if (savedExited is bool) hasExitedThreshold = savedExited;

    final savedSai = CashHelper.getCash(key: _kSaiCountKey);
    final savedSaiEnd = CashHelper.getCash(key: _kSaiLastEndKey);
    if (savedSai is int) saiCount = savedSai;
    if (savedSaiEnd is String) _lastSaiEnd = savedSaiEnd;
  }

  /// ضبط نقطة بداية الطواف من مركز نطاق مخزّن (مثل نطاق المطاف/الكعبة)
  /// بدلاً من الاعتماد على إحداثيات ثابتة في الكود.
  void setTawafStartPoint(double lat, double lng) {
    startLat = lat;
    startLng = lng;
  }

  /// يحمّل مركز نطاق المطاف من Firestore ويضبط نقطة بداية الطواف عليه،
  /// بدلاً من الاعتماد على إحداثيات ثابتة. يبقى الافتراضي إذا لم يوجد النطاق
  /// أو تعذّر الاتصال، فلا ينكسر العدّ في وضع عدم الاتصال.
  // يستخرج (lat,lng) لمركز المنطقة: من حقل center للدوائر، أو من مركز
  // المضلّع (centroid) المحسوب من نقاطه للمناطق من نوع polygon.
  List<double>? _centerOf(Map<String, dynamic> data) {
    final c = data['center'];
    if (c is Map) {
      final lat = (c['lat'] is num) ? (c['lat'] as num).toDouble() : null;
      final lng = (c['lng'] is num) ? (c['lng'] as num).toDouble() : null;
      if (lat != null && lng != null) return [lat, lng];
    }

    // مضلّع: نحسب متوسّط النقاط كمركز تقريبي.
    final pts = data['points'];
    if (pts is List && pts.isNotEmpty) {
      double sumLat = 0, sumLng = 0;
      int n = 0;
      for (final p in pts) {
        if (p is Map && p['lat'] is num && p['lng'] is num) {
          sumLat += (p['lat'] as num).toDouble();
          sumLng += (p['lng'] as num).toDouble();
          n++;
        }
      }
      if (n > 0) return [sumLat / n, sumLng / n];
    }

    return null;
  }

  Future<void> loadTawafStartFromFirestore() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('zones')
          .where('isActive', isEqualTo: true)
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? mataf;

      // 1) مطابقة بالمعرّف المعروف لنطاق المطاف.
      for (final d in snap.docs) {
        final id = (d.data()['zoneId'] ?? d.id).toString();
        if (id == 'Z_MATAF') {
          mataf = d;
          break;
        }
      }

      // 2) وإلا: أول نطاق دائري اسمه يدل على الطواف/المطاف.
      if (mataf == null) {
        for (final d in snap.docs) {
          final data = d.data();
          if ((data['type'] ?? 'circle').toString() != 'circle') continue;
          final name = '${data['nameEn'] ?? ''} ${data['nameAr'] ?? ''}'.toLowerCase();
          if (name.contains('tawaf') ||
              name.contains('mataf') ||
              name.contains('طواف') ||
              name.contains('مطاف')) {
            mataf = d;
            break;
          }
        }
      }

      if (mataf != null) {
        final center = _centerOf(mataf.data());
        if (center != null) setTawafStartPoint(center[0], center[1]);
      }
    } catch (e) {
      debugPrint('تعذّر تحميل نقطة بداية الطواف من Firestore: $e');
    }
  }

  void initCompass() {
    _compassSubscription?.cancel();
    _compassSubscription = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading == null) return;
      userHeading = heading;
      _accumulateRotation(heading); // عدّ دوران الطواف لا يحتاج إعادة بناء

      // نعيد بناء الواجهة فقط عند تغيّر ملموس في الاتجاه (≥2°) لتفادي
      // إعادة بناء التطبيق عشرات المرات في الثانية وتعطّل اللمس.
      if ((heading - _lastEmittedHeading).abs() >= 2) {
        _lastEmittedHeading = heading;
        emit(AppQiblaDirectionUpdateState());
      }
    });
  }

  /// يجمع تغيّر اتجاه البوصلة لاكتشاف دورة طواف كاملة.
  /// يعمل فقط قرب المطاف (بوابة القرب) لتفادي العدّ الخاطئ في أماكن أخرى.
  void _accumulateRotation(double heading) {
    final prev = _lastHeading;
    _lastHeading = heading;

    // نعدّ بالبوصلة فقط عندما يؤكّد GPS أننا قرب المطاف.
    if (!_nearTawaf) {
      _accumulatedRotation = 0.0;
      return;
    }
    if (prev == null) return;

    // أقصر فرق زاوي بين القراءتين مع معالجة الالتفاف عند 360/0.
    double delta = heading - prev;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;

    _accumulatedRotation += delta;

    // الطواف عكس عقارب الساعة فقط، فالتقدّم الصحيح يجعل المجموع سالباً.
    // مجموع موجب بلغ الحد = لفّ باتجاه الساعة (ليس طوافاً) — نصفّره بلا عدّ.
    if (_accumulatedRotation >= _tawafLapDegrees) {
      _accumulatedRotation = 0.0;
      return;
    }
    if (_accumulatedRotation <= -_tawafLapDegrees) {
      _registerTawafLap();
      _accumulatedRotation = 0.0;
    }
  }

  /// نقطة موحّدة لاحتساب شوط طواف من أي مصدر (GPS أو بوصلة) مع حارس زمني
  /// يمنع احتساب نفس الشوط مرّتين. الزر اليدوي يستدعي incrementRound مباشرة.
  void _registerTawafLap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastLapMs < _minLapSeconds * 1000) return; // حارس مزدوج
    _lastLapMs = now;
    _accumulatedRotation = 0.0;
    incrementRound();
  }

  /// خط موقع مستقل يملكه الكيوبيت لعدّ الأشواط في كل تبويبات التطبيق
  /// (وليس شاشة الخريطة فقط). يبدأ من واجهة الحاج ويتوقف عند الخروج منها.
  Future<void> startRoundTracking() async {
    // نشغّل البوصلة لكشف دوران الطواف، وعدّاد الخطى لمسافة السعي (مكمّلان لـ GPS).
    initCompass();
    startStepTracking();

    // نضبط نقاط الطواف والسعي من النطاقات في Firestore (مع إبقاء الافتراضي).
    await loadTawafStartFromFirestore();
    await loadSaiPointsFromFirestore();

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    final allowed = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    if (!serviceEnabled || !allowed) return;

    _locationFilter.reset();
    await _startPositionStream();
  }

  /// يبني إعدادات الموقع للمنصة: على أندرويد نطلب خدمة أمامية
  /// (foreground service) بإشعار دائم حتى يستمر عدّ الأشواط والشاشة مطفأة
  /// أو الجوال في الجيب — بدونها يقتل النظام خط GPS عند إطفاء الشاشة.
  LocationSettings _buildLocationSettings({
    required LocationAccuracy accuracy,
    required int distanceFilter,
  }) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final isAr = LocaleController.locale.value.languageCode == 'ar';
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle:
              isAr ? 'ذِكّر — عدّ الأشواط يعمل' : 'Dhakker — lap counting active',
          notificationText: isAr
              ? 'نتابع موقعك لعدّ الطواف والسعي حتى مع إطفاء الشاشة'
              : "Tracking your location to count Tawaf/Sa'i even with the screen off",
          enableWakeLock: true,
        ),
      );
    }
    return LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
  }

  /// يبدأ (أو يعيد بدء) خط الموقع بإعدادات تتكيّف مع القرب من مناطق العدّ
  /// وحالة الحركة معاً، لتوفير البطارية:
  /// • قرب الطواف/السعي: دقة قصوى (bestForNavigation) لعدّ دقيق.
  /// • بعيد عنها: دقة high بفاصل أكبر — تكفي لكشف الاقتراب وأخفّ على البطارية،
  ///   فلا يشتغل أقوى وضع GPS طوال اليوم في منى/عرفات/الفندق.
  Future<void> _startPositionStream() async {
    await _roundSubscription?.cancel();
    final LocationSettings settings;
    if (_highAccuracyMode) {
      settings = _isWalking
          ? _buildLocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 3,
            )
          : _buildLocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 8,
            );
    } else {
      settings = _isWalking
          ? _buildLocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 15,
            )
          : _buildLocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 30,
            );
    }
    _roundSubscription =
        Geolocator.getPositionStream(locationSettings: settings)
            .listen(_onTrackingPosition);
  }

  // مُعالج موحّد: يمرّر القراءة على فلتر التنعيم ثم يغذّي عدّ الطواف والسعي
  // بالإحداثيات الناعمة لتقليل اهتزاز GPS.
  void _onTrackingPosition(Position position) {
    // نحدّث القرب من مناطق العدّ من القراءة الخام أولاً (قبل بوابة الدقة)، حتى
    // القراءات الأضعف بعيداً عن العدّ تكفي لكشف الاقتراب ورفع الدقة عند الحاجة.
    final wasHigh = _highAccuracyMode;
    final rawTawaf =
        Geolocator.distanceBetween(position.latitude, position.longitude, startLat, startLng) <= _tawafProximityM;
    final rawSai =
        Geolocator.distanceBetween(position.latitude, position.longitude, safaLat, safaLng) <= _saiProximityM ||
            Geolocator.distanceBetween(position.latitude, position.longitude, marwaLat, marwaLng) <= _saiProximityM;
    _nearSai = rawSai;
    _highAccuracyMode = rawTawaf || _nearSai;
    // عند الانتقال بين قرب/بعيد نعيد ضبط خط الموقع بالدقة المناسبة.
    if (_highAccuracyMode != wasHigh && _roundSubscription != null) {
      _startPositionStream();
    }

    // مشاركة الموقع مع المجموعة (إن فُعّلت) — من القراءة الخام وكل ٤٥ ثانية،
    // فتعمل حتى بعيداً عن مناطق العدّ ولا ترهق البطارية أو القاعدة.
    _maybeShareGroupLocation(position.latitude, position.longitude);

    // أول قراءة GPS — ابدأ مراقبة الحرارة بالموقع الحقيقي للحاج
    final isAr = LocaleController.locale.value.languageCode == 'ar';
    if (!_heatMonitorStarted) {
      _heatMonitorStarted = true;
      HeatMonitorService.instance.start(
        lat: position.latitude,
        lng: position.longitude,
        isAr: isAr,
      );
      // حمّل جدول الحج من الذاكرة وابدأ التذكيرات
      HajjScheduleService.instance.loadDay8Date().then((_) {
        HajjScheduleService.instance.start();
      });
      BroadcastListenerService.instance.start(isAr: isAr);
    } else {
      // نمرّر أحدث موقع لمراقب الحرارة حتى لا يظل الفحص معلّقاً على أول قراءة
      // (الحاج ينتقل مكة ↔ عرفات ↔ مزدلفة والطقس يختلف بينها).
      HeatMonitorService.instance.updateLocation(
        position.latitude,
        position.longitude,
      );
    }

    // نتجاهل القراءة الخام ضعيفة الدقة قبل أن تلوّث الفلتر والعدّ.
    if (position.accuracy > _roundAccuracyLimitM) return;

    _locationFilter.process(
      position.latitude,
      position.longitude,
      position.accuracy,
      position.timestamp.millisecondsSinceEpoch,
    );

    final lat = _locationFilter.lat ?? position.latitude;
    final lng = _locationFilter.lng ?? position.longitude;
    final acc = _locationFilter.accuracy;

    // بوابة القرب: نسمح بعدّ البوصلة فقط عندما نكون قرب المطاف فعلاً.
    _nearTawaf =
        Geolocator.distanceBetween(lat, lng, startLat, startLng) <= _tawafProximityM;

    _evaluateRound(lat, lng, acc);
    _evaluateSai(lat, lng, acc);
  }

  Future<void> stopRoundTracking() async {
    await _roundSubscription?.cancel();
    _roundSubscription = null;
    await _stepSubscription?.cancel();
    _stepSubscription = null;
    await _pedestrianSubscription?.cancel();
    _pedestrianSubscription = null;
  }

  /// يفعّل/يوقف مشاركة الموقع مع المجموعة. يُستدعى بعد موافقة الحاج الصريحة.
  void setGroupSharing({required String? groupId, required bool enabled}) {
    groupShareId = groupId;
    groupSharing = enabled && groupId != null;
    _lastGroupWriteMs = 0; // اسمح بكتابة فورية عند التفعيل
  }

  /// يكتب موقع الحاج في مجموعته كل ٤٥ ثانية كحدّ أقصى (إن فُعّلت المشاركة).
  void _maybeShareGroupLocation(double lat, double lng) {
    if (!groupSharing || groupShareId == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastGroupWriteMs < 45000) return;
    _lastGroupWriteMs = now;
    _groupService.updateMyLocation(groupId: groupShareId!, lat: lat, lng: lng);
  }

  /// منطق احتساب الشوط: نحسب المسافة لنقطة البداية مع حاجز هيستيريسيس
  /// (لازم يبتعد >20م ثم يقترب <8م لاحتساب شوط) ونتجاهل القراءات ضعيفة الدقة.
  void _evaluateRound(double lat, double lng, double accuracy) {
    // تجاهل القراءات ضعيفة الدقة لمنع احتساب أشواط وهمية.
    if (accuracy > _roundAccuracyLimitM) return;

    final distance = Geolocator.distanceBetween(lat, lng, startLat, startLng);

    if (distance < 8 && hasExitedThreshold) {
      if (_tawafArmed) {
        _registerTawafLap(); // عبر الحارس الموحّد لتفادي العدّ المزدوج مع البوصلة
      } else {
        _tawafArmed = true; // أول مرور بالنقطة: تهيئة فقط، الدورة لم تكتمل بعد
      }
      hasExitedThreshold = false;
      CashHelper.saveCash(key: _kHasExitedKey, value: false);
    }
    if (distance > 20 && !hasExitedThreshold) {
      hasExitedThreshold = true;
      CashHelper.saveCash(key: _kHasExitedKey, value: true);
    }
  }

  // تبقى للتوافق مع شاشة الخريطة، لكنها لم تعد تقود العدّ: خط الكيوبيت
  // المنعّم (_onTrackingPosition) صار يملك احتساب الأشواط/السعي في كل التبويبات،
  // فنترك هذه فارغة لتفادي تلويث فلتر التنعيم بمصدر موقع ثانٍ.
  void updateLocationAndCheckRounds(Position position, {bool isInZone = false}) {}

  void incrementRound() {
    if (roundCount < 7) {
      roundCount++;
      // اهتزاز ملموس مع كل شوط (حتى والجوال في الجيب أثناء العدّ التلقائي)،
      // واهتزاز أقوى عند اكتمال السابع — الحاج يحسّ بالعدّ دون النظر للشاشة.
      if (roundCount >= 7) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
      CashHelper.saveCash(key: _kRoundCountKey, value: roundCount);
      // بدء تذكير الماء مع أول شوط — بلغة الواجهة الحالية.
      if (roundCount == 1) {
        NotificationService.instance.startWaterReminder(
          isAr: LocaleController.locale.value.languageCode == 'ar',
        );
      }
      // إيقاف التذكير بعد اكتمال الطواف.
      if (roundCount >= 7) {
        NotificationService.instance.stopWaterReminder();
      }
      emit(AppRoundIncrementState());
    }
  }

  void resetRounds() {
    roundCount = 0;
    hasExitedThreshold = true;
    _tawafArmed = false;
    _accumulatedRotation = 0.0;
    _lastHeading = null;
    _lastLapMs = 0;
    NotificationService.instance.stopWaterReminder();
    CashHelper.saveCash(key: _kRoundCountKey, value: 0);
    CashHelper.saveCash(key: _kHasExitedKey, value: true);
    emit(AppRoundResetState());
  }

  /// منطق احتساب شوط السعي: نرصد الوصول إلى الصفا أو المروة بالتناوب.
  /// كل وصول لطرف مختلف عن آخر طرف مُسجّل = شوط مكتمل. أول وصول يهيّئ البداية فقط.
  void _evaluateSai(double lat, double lng, double accuracy) {
    if (accuracy > _roundAccuracyLimitM) return;

    final dSafa = Geolocator.distanceBetween(lat, lng, safaLat, safaLng);
    final dMarwa = Geolocator.distanceBetween(lat, lng, marwaLat, marwaLng);

    String? arrivedEnd;
    if (dSafa < _saiArrivalRadiusM && dSafa <= dMarwa) {
      arrivedEnd = 'safa';
    } else if (dMarwa < _saiArrivalRadiusM && dMarwa < dSafa) {
      arrivedEnd = 'marwa';
    }

    if (arrivedEnd == null) return;
    _registerSaiArrival(arrivedEnd);
  }

  /// يسجّل الوصول إلى طرف (صفا/مروة) من أي مصدر (GPS أو خطى) بمنطق التناوب:
  /// أول طرف يهيّئ البداية فقط، والوصول لطرف مختلف عنه = شوط مكتمل.
  void _registerSaiArrival(String end) {
    if (end == _lastSaiEnd) return; // ما زلنا عند نفس الطرف

    final wasNull = _lastSaiEnd == null;
    _lastSaiEnd = end;
    _stepBaseline = _currentSteps; // نعيد قياس مسافة الخطى من هذا الطرف
    CashHelper.saveCash(key: _kSaiLastEndKey, value: end);

    if (!wasNull) {
      incrementSai(); // وصلنا للطرف المقابل: شوط مكتمل
    }
  }

  /// معالج حسّاس الخطى: يستنتج الوصول للطرف المقابل عندما تبلغ مسافة الخطى
  /// منذ آخر طرف ما يقارب طول الممر — مفيد داخل المسعى حيث يضعف GPS.
  void _onStep(StepCount event) {
    _currentSteps = event.steps;

    // نحتاج طرفاً مرجعياً بدأ منه السعي (يُضبط أول مرة عبر GPS).
    if (_lastSaiEnd == null) return;

    final corridor =
        Geolocator.distanceBetween(safaLat, safaLng, marwaLat, marwaLng);
    if (corridor < 50) return; // حماية من نقاط غير صالحة

    final walked = (_currentSteps - _stepBaseline) * _stepLengthM;
    if (walked >= corridor * _saiStepFactor) {
      final opposite = _lastSaiEnd == 'safa' ? 'marwa' : 'safa';
      _registerSaiArrival(opposite);
    }
  }

  /// يبدأ قراءة عدّاد الخطى (بعد إذن النشاط البدني). آمن: عند الرفض أو غياب
  /// الحسّاس يبقى عدّ السعي معتمداً على GPS دون أي تأثير.
  Future<void> startStepTracking() async {
    try {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) return;

      await _stepSubscription?.cancel();
      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStep,
        onError: (e) => debugPrint('تعذّر قراءة عدّاد الخطى: $e'),
        cancelOnError: false,
      );

      // حالة المشي/الوقوف لتكييف دقة GPS وتوفير البطارية.
      await _pedestrianSubscription?.cancel();
      _pedestrianSubscription = Pedometer.pedestrianStatusStream.listen(
        _onPedestrianStatus,
        onError: (e) => debugPrint('تعذّر قراءة حالة الحركة: $e'),
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('تعذّر بدء عدّاد الخطى: $e');
    }
  }

  /// عند تغيّر حالة الحركة (مشي/وقوف) نعيد ضبط خط الموقع بالدقة المناسبة
  /// لتوفير البطارية أثناء الوقوف. آمن: لو الحسّاس غاب يبقى الوضع مشي (دقة قصوى).
  void _onPedestrianStatus(PedestrianStatus event) {
    final walking = event.status == 'walking';
    if (walking == _isWalking) return; // لا تغيير
    _isWalking = walking;
    if (_roundSubscription != null) {
      _startPositionStream(); // إعادة البدء بالإعدادات الجديدة
    }
  }

  void incrementSai() {
    if (saiCount < 7) {
      saiCount++;
      // نفس نمط اهتزاز الطواف: ملموس لكل شوط وقوي عند اكتمال السعي.
      if (saiCount >= 7) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
      CashHelper.saveCash(key: _kSaiCountKey, value: saiCount);
      if (saiCount == 1) {
        NotificationService.instance.startWaterReminder(
          isAr: LocaleController.locale.value.languageCode == 'ar',
        );
      }
      if (saiCount >= 7) {
        NotificationService.instance.stopWaterReminder();
      }
      emit(AppSaiIncrementState());
    }
  }

  void resetSai() {
    saiCount = 0;
    _lastSaiEnd = null;
    _stepBaseline = _currentSteps; // نبدأ قياس الخطى من جديد لسعي جديد
    NotificationService.instance.stopWaterReminder();
    CashHelper.saveCash(key: _kSaiCountKey, value: 0);
    CashHelper.removeCash(key: _kSaiLastEndKey);
    emit(AppSaiResetState());
  }

  /// يحمّل مركزي الصفا والمروة من Firestore (مع إبقاء الافتراضي عند التعذّر).
  Future<void> loadSaiPointsFromFirestore() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('zones')
          .where('isActive', isEqualTo: true)
          .get();

      List<double>? findEnd(String id, List<String> keywords) {
        for (final d in snap.docs) {
          final zid = (d.data()['zoneId'] ?? d.id).toString();
          if (zid == id) return _centerOf(d.data());
        }
        for (final d in snap.docs) {
          final data = d.data();
          final name = '${data['nameEn'] ?? ''} ${data['nameAr'] ?? ''}'.toLowerCase();
          if (keywords.any(name.contains)) return _centerOf(data);
        }
        return null;
      }

      final safa = findEnd('Z_SAFA', ['safa', 'صفا']);
      final marwa = findEnd('Z_MARWAH', ['marwah', 'marwa', 'مروة', 'مروه']);

      if (safa != null) {
        safaLat = safa[0];
        safaLng = safa[1];
      }
      if (marwa != null) {
        marwaLat = marwa[0];
        marwaLng = marwa[1];
      }
    } catch (e) {
      debugPrint('تعذّر تحميل نقاط السعي من Firestore: $e');
    }
  }

  // ==========================================
  // --- منطق التحكم بالصوت والجيوفنسينغ الذكي ---
  // ==========================================
  bool isAudioPlayed = false;

  /// تصفير حالة تشغيل الصوت يدوياً أو عند الحاجة
  void resetAudioTrigger() {
    isAudioPlayed = false;
    debugPrint('DHKKR_CUBIT => تم تصفير الـ Audio Trigger بنجاح.');
    try {
      emit(AppMapCrowdDensityUpdateState());
    } catch (_) {}
  }

  // ==========================================
  // --- منطق مؤشر الازدحام اللحظي للمناطق ---
  // ==========================================
  // ملاحظة: قواعد Firestore تمنع الحاج من قراءة وثائق المستخدمين الآخرين
  // (خصوصية)، لذا لا يوجد مستمع ازدحام في واجهة الحاج — تبقى الخريطة بالألوان
  // الافتراضية. شاشة الازدحام الحقيقية للأدمن فقط (admin_crowd_screen).
  Map<String, int> zoneUserCount = {};

  Color getZoneColor(String zoneId, Color defaultGold) {
    final count = zoneUserCount[zoneId] ?? 0;
    if (count == 0) return defaultGold.withOpacity(0.20);
    if (count > 50) return Colors.redAccent.withOpacity(0.40);
    if (count > 20) return Colors.orangeAccent.withOpacity(0.30);
    return Colors.greenAccent.withOpacity(0.25);
  }

  // ==========================================
  // --- منطق الـ SOS ---
  // ==========================================
  // رقم طوارئ احتياطي يُستخدم فقط إذا لم يُضبط رقم في إعدادات Firestore.
  // الأفضل أن تضبط الجهة المشغّلة الرقم الرسمي في الوثيقة config/sos.
  static const String _fallbackSosPhone = "+966500000000";

  /// يقرأ رقم واتساب الطوارئ من الوثيقة config/sos (الحقل whatsappPhone)،
  /// فيمكن للأدمن/الجهة تغييره دون إعادة بناء التطبيق. يرجع الاحتياطي عند التعذّر.
  Future<String> _resolveSosPhone() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('sos')
          .get();
      final phone = doc.data()?['whatsappPhone']?.toString().trim();
      if (phone != null && phone.isNotEmpty) return phone;
    } catch (e) {
      debugPrint('تعذّر قراءة رقم الطوارئ من config/sos: $e');
    }
    return _fallbackSosPhone;
  }

  void sendWhatsAppSOS() async {
    final String phoneNumber = await _resolveSosPhone();

    // 1) نجيب الموقع الحقيقي للمستخدم (مع بدائل احتياطية)
    Position? pos;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final allowed = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (serviceEnabled && allowed) {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
      }
    } catch (_) {}
    pos ??= await Geolocator.getLastKnownPosition();

    final bool hasLoc = pos != null;
    final double? lat = pos?.latitude;
    final double? lng = pos?.longitude;
    final String mapUrl = hasLoc ? "https://maps.google.com/?q=$lat,$lng" : "";

    // نجيب اسم المستخدم من ملفه الشخصي عشان يظهر للأدمن في شاشة المراقبة
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    String? userName = FirebaseAuth.instance.currentUser?.displayName;
    try {
      if (uid != null) {
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final n = userDoc.data()?['fullName'];
        if (n != null && n.toString().trim().isNotEmpty) userName = n.toString();
      }
    } catch (_) {}

    // 2) نسجّل النداء في قاعدة البيانات عشان لوحة التحكم تشوفه فعلاً
    try {
      await FirebaseFirestore.instance.collection('sos_requests').add({
        'uid': uid,
        'name': userName,
        'lat': lat,
        'lng': lng,
        'mapUrl': hasLoc ? mapUrl : null,
        'status': 'active',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("SOS log error: $e");
    }

    // 3) نفتح واتساب برسالة فيها الموقع الحقيقي
    final String message = hasLoc
        ? "🆘 نداء استغاثة SOS! موقعي الحالي: $mapUrl"
        : "🆘 نداء استغاثة SOS! (تعذّر تحديد الموقع تلقائياً)";
    final Uri url =
        Uri.parse("https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      emit(AppSOSSuccessState());
    } else {
      emit(AppSOSErrorState());
    }
  }

  // ======================================================
  // --- منطق لوحة الإحصائيات (Admin Logic) ---
  // ======================================================
  Map<String, dynamic> adminStats = {
    'totalUsers': 0,
    'sosActive': 0,
    'haramCrowd': 0
  };

  List<Map<String, dynamic>> sosRequests = [];

  // نحفظ اشتراكات الأدمن ونلغي القديمة قبل كل إعادة استماع، حتى لا تتراكم
  // المستمعات (وتتضاعف القراءات) مع كل فتح لشاشات لوحة التحكم.
  StreamSubscription? _adminStatsSubscription;
  StreamSubscription? _sosRequestsSubscription;

  void getAdminStats() {
    emit(AppAdminLoadingStatsState());
    _adminStatsSubscription?.cancel();
    _adminStatsSubscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((event) {
      adminStats['totalUsers'] = event.docs.length;
      try {
        adminStats['haramCrowd'] = event.docs.where((doc) {
          final data = doc.data();
          return data.containsKey('currentZone') && data['currentZone'] == 'Al-Haram';
        }).length;
      } catch (e) {
        debugPrint("Error counting crowd: $e");
      }
      emit(AppAdminGetStatsSuccessState());
    }, onError: (error) {
      emit(AppAdminGetStatsErrorState(error.toString()));
    });
  }

  void getSOSRequests() {
    _sosRequestsSubscription?.cancel();
    _sosRequestsSubscription = FirebaseFirestore.instance
        .collection('sos_requests')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((event) {
      sosRequests = event.docs.map((doc) => doc.data()).toList();
      adminStats['sosActive'] = sosRequests.length;
      emit(AppAdminGetSOSRequestsSuccessState());
    }, onError: (error) {
      emit(AppAdminGetSOSRequestsErrorState(error.toString()));
    });
  }

  @override
  Future<void> close() {
    _compassSubscription?.cancel();
    _roundSubscription?.cancel();
    _stepSubscription?.cancel();
    _pedestrianSubscription?.cancel();
    _adminStatsSubscription?.cancel();
    _sosRequestsSubscription?.cancel();
    return super.close();
  }
}