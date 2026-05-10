import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

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

  // 1. تغيير الدعاء الواحد إلى قائمة لدعم التعدد
  List<SupplicationModel> currentDuasList = [];

  String? errorMessage;

  List<ZoneModel> _zones = [];
  StreamSubscription<Position>? _positionSubscription;

  String? _lastTriggeredZoneId;
  String? _lastTriggeredDuaId;
  DateTime? _lastTriggerTimestamp;
  bool _isCurrentZoneHandled = false;

  String _zoneKey(String key) => '${key}_$userId';

  Future<void> init(String langCode) async {
    isLoading = true;
    notifyListeners();

    _log('------------------------------');
    _log('HomeDuaController init started');
    _log('Current user uid: $userId');
    _log('Current language: $langCode');

    await playbackService.init();

    playbackService.onPlayingStateChanged = (value) {
      isPlaying = value;
      notifyListeners();
    };

    await _loadSettings();

    _log('autoLocationEnabled: $autoLocationEnabled');
    _log('voiceNotificationsEnabled: $voiceNotificationsEnabled');

    await _loadLastHandledState();

    _log('lastTriggeredZoneId: $_lastTriggeredZoneId');
    _log('lastTriggeredDuaId: $_lastTriggeredDuaId');
    _log('lastTriggerTimestamp: $_lastTriggerTimestamp');

    await _loadZones();

    if (!autoLocationEnabled) {
      _log('Auto location disabled from cache. Skipping tracking.');
      isLoading = false;
      notifyListeners();
      return;
    }

    await _startLocationTracking(langCode);

    isLoading = false;
    notifyListeners();
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

  Future<void> _loadZones() async {
    final query = await firestore
        .collection('zones')
        .where('isActive', isEqualTo: true)
        .get();

    _zones = query.docs.map(ZoneModel.fromFirestore).toList();
    _zones.sort((a, b) => b.priority.compareTo(a.priority));

    _log('Loaded zones count: ${_zones.length}');
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

    final detectedZone = zoneDetectionService.detectBestZone(
      userLat: position.latitude,
      userLng: position.longitude,
      zones: _zones,
    );

    if (detectedZone == null) {
      currentZone = null;
      currentDuasList = []; // تصفير القائمة
      _isCurrentZoneHandled = false;
      notifyListeners();
      return;
    }

    final previousZoneId = currentZone?.zoneId;
    currentZone = detectedZone;

    // 2. جلب كل الأدعية الخاصة بالمنطقة وحفظها في القائمة
    final supplications = await supplicationService.getSupplicationsByZone(
      detectedZone.zoneId,
    );

    currentDuasList = supplications;

    if (currentDuasList.isEmpty) {
      _isCurrentZoneHandled = false;
      notifyListeners();
      return;
    }

    // يتم تشغيل الدعاء الأول تلقائياً (الذي يفترض أن يكون الأكثر تشغيلاً بناءً على استعلامكم)
    final selected = currentDuasList.first;

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
    if (currentDuasList.isEmpty || index >= currentDuasList.length) return;

    final dua = currentDuasList[index];

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
    if (currentDuasList.isEmpty || index >= currentDuasList.length) return null;
    return currentDuasList[index].titleByLanguage(langCode);
  }

  String? displayedDuaText(String langCode, int index) {
    if (currentDuasList.isEmpty || index >= currentDuasList.length) return null;
    return currentDuasList[index].textByLanguage(langCode);
  }

  void _log(String message) {
    debugPrint('DHKKR_HOME => $message');
  }

  // 5. تحديث المتغيرات التي تعتمد عليها واجهة المستخدم
  bool get hasDetectedZone => currentZone != null;
  bool get hasDua => currentDuasList.isNotEmpty;
  int get duasCount => currentDuasList.length; // متغير جديد لجلب عدد الأدعية

  @override
  void dispose() {
    _positionSubscription?.cancel();
    playbackService.dispose();
    super.dispose();
  }
}