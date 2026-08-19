import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dhakker/Screens/Piligram/Map/services/map_controller_service.dart';
import 'package:dhakker/Screens/Piligram/Map/services/map_zone_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:qr_flutter/qr_flutter.dart';

import '../../../../generated/l10n.dart';
import '../../../../services/group_service.dart';
import '../../../../shared/network/local/cash_helper.dart';
import '../Home/models/zone_model.dart';
import '../Home/services/zone_detection_service.dart';
import '../../../bloc/cubit.dart';
import '../../../bloc/states.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  late final MapControllerService _mapControllerService;
  late final AnimationController _pulseController;

  final ZoneDetectionService _zoneDetectionService = const ZoneDetectionService();

  List<ZoneModel> _zones = [];
  ZoneModel? _currentZone;
  Position? _currentPosition;

  bool _isLoading = true;
  bool _didFocusOnce = false;

  StreamSubscription<Position>? _positionSubscription;

  // ----- حالة المجموعة -----
  final GroupService _groupService = GroupService();
  String? _groupId;
  String _groupName = '';
  String _groupCode = '';
  List<GroupMember> _members = [];
  StreamSubscription<List<GroupMember>>? _membersSub;
  bool _sharing = false;
  bool _groupBusy = false;
  static const String _kShareKey = 'group_share_enabled';

  @override
  void initState() {
    super.initState();
    _mapControllerService = MapControllerService(_mapController);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cubit = AppCubit.get(context);
      cubit.initCompass();
      // مؤشّر الازدحام للحاج غير مفعّل: قراءة مواقع كل المستخدمين تنتهك
      // خصوصيتهم وتُمنع بقواعد الأمان. لو أُريد لاحقاً: تجميع آمن في وثيقة
      // zone_stats يكتبها الأدمن وتُقرأ هنا.
      await _initMapFlow();
      await _loadGroup();
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _membersSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ─────────────────────────── المجموعة ───────────────────────────

  Future<void> _loadGroup() async {
    final gid = await _groupService.myGroupId();
    if (gid == null) {
      if (mounted) setState(() => _groupId = null);
      return;
    }
    final info = await _groupService.groupInfo(gid);
    final sharePref = CashHelper.getCash(key: _kShareKey);
    final sharing = sharePref is bool ? sharePref : false;

    if (!mounted) return;
    setState(() {
      _groupId = gid;
      _groupName = info?.name ?? 'مجموعتي';
      _groupCode = info?.code ?? '';
      _sharing = sharing;
    });

    _subscribeMembers(gid);
    if (mounted) AppCubit.get(context).setGroupSharing(groupId: gid, enabled: sharing);
  }

  void _subscribeMembers(String gid) {
    _membersSub?.cancel();
    _membersSub = _groupService.streamMembers(gid).listen((list) {
      if (mounted) setState(() => _members = list);
    });
  }

  Future<void> _createGroup() async {
    final name = await _promptText(
      title: 'إنشاء مجموعة',
      hint: 'اسم المجموعة (مثل: عائلة محمد)',
      action: 'إنشاء',
    );
    if (name == null) return;
    setState(() => _groupBusy = true);
    try {
      final res = await _groupService.createGroup(name);
      await _loadGroup();
      if (mounted) _showSnack('تم إنشاء المجموعة — الكود: ${res.code}');
    } catch (e) {
      if (mounted) _showSnack('تعذّر إنشاء المجموعة');
    } finally {
      if (mounted) setState(() => _groupBusy = false);
    }
  }

  Future<void> _joinGroup() async {
    final code = await _promptText(
      title: 'الانضمام لمجموعة',
      hint: 'أدخل الكود (مثل: HAJJ-4821)',
      action: 'انضمام',
    );
    if (code == null || code.trim().isEmpty) return;
    setState(() => _groupBusy = true);
    try {
      await _groupService.joinByCode(code);
      await _loadGroup();
      if (mounted) _showSnack('تم الانضمام للمجموعة');
    } catch (e) {
      if (mounted) _showSnack('لا توجد مجموعة بهذا الكود');
    } finally {
      if (mounted) setState(() => _groupBusy = false);
    }
  }

  Future<void> _leaveGroup() async {
    final gid = _groupId;
    if (gid == null) return;
    final ok = await _confirm(
      title: 'مغادرة المجموعة',
      message: 'هل تريد مغادرة المجموعة؟ لن يظهر موقعك لأفرادها بعد الآن.',
      action: 'مغادرة',
    );
    if (ok != true) return;
    await _groupService.leaveGroup(gid);
    await CashHelper.saveCash(key: _kShareKey, value: false);
    if (mounted) AppCubit.get(context).setGroupSharing(groupId: null, enabled: false);
    _membersSub?.cancel();
    if (mounted) {
      setState(() {
        _groupId = null;
        _members = [];
        _sharing = false;
      });
    }
  }

  Future<void> _toggleSharing(bool value) async {
    if (value) {
      // موافقة صريحة قبل بدء مشاركة الموقع.
      final ok = await _confirm(
        title: 'مشاركة الموقع',
        message:
            'سيُشارك موقعك الحالي مع أفراد مجموعتك ليطمئنوا عليك ويجدوك عند الضياع. '
            'يُحدّث موقعك كل دقيقة تقريبًا، وتقدر توقف المشاركة في أي وقت.',
        action: 'أوافق',
      );
      if (ok != true) return;
    }
    await CashHelper.saveCash(key: _kShareKey, value: value);
    if (mounted) {
      setState(() => _sharing = value);
      AppCubit.get(context).setGroupSharing(groupId: _groupId, enabled: value);
    }
  }

  void _showQr() {
    if (_groupCode.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final palette = _MapPalette.fromBrightness(isDark);
        return Dialog(
          backgroundColor: palette.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('كود المجموعة',
                    style: TextStyle(color: palette.gold, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: _groupCode,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  _groupCode,
                  style: TextStyle(color: palette.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'شارك الكود أو دع غيرك يصوّر الرمز',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<String?> _promptText({
    required String title,
    required String hint,
    required String action,
  }) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _MapPalette.fromBrightness(isDark);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: palette.textPrimary),
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: palette.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: palette.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(action, style: TextStyle(color: palette.gold, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String action,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _MapPalette.fromBrightness(isDark);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
        content: Text(message, style: TextStyle(color: palette.textMuted, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: palette.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: TextStyle(color: palette.gold, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Future<void> _initMapFlow() async {
    setState(() {
      _isLoading = true;
    });

    await _loadZones();
    await _startTracking();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadZones() async {
    final query = await FirebaseFirestore.instance
        .collection('zones')
        .where('isActive', isEqualTo: true)
        .get();

    final items = query.docs.map(ZoneModel.fromFirestore).toList();
    items.sort((a, b) => b.priority.compareTo(a.priority));

    _zones = items;
  }

  Future<void> _startTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();

    final hasPermission =
        permission == LocationPermission.always || permission == LocationPermission.whileInUse;

    if (!serviceEnabled || !hasPermission) {
      return;
    }

    // جلب أول موقع بدقة عالية جداً لمنع القفزات البعيدة
    final current = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );

    await _handlePosition(current);

    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best, // رفع الدقة لأعلى مستوى ممكن
        distanceFilter: 2, // تحديث الموقع فور التحرك مترين فقط لثبات الإشارة عند الخيف
      ),
    ).listen((position) async {
      await _handlePosition(position);
    });
  }

  Future<void> _handlePosition(Position position) async {
    _currentPosition = position;

    final detected = _zoneDetectionService.detectBestZone(
      userLat: position.latitude,
      userLng: position.longitude,
      zones: _zones,
    );

    // --- [التحديث المعتمد] ربط شاشة الخريطة بالكيوبيت وتصفير الصوت تلقائياً عند الخروج اللحظي ---
    if (mounted) {
      AppCubit.get(context).updateLocationAndCheckRounds(
        position,
        isInZone: detected != null, // يرسل true إذا كان داخل زون الصالة، و false إذا خرج للمنطقة المفتوحة
      );
    }
    // ----------------------------------------------------------------------------------

    _currentZone = detected;

    // التركيز الفوري والسلس على موقع المستخدم الفعلي عند مسجد الخيف
    if (!_didFocusOnce) {
      _didFocusOnce = true;
      _mapControllerService.focusOnPoint(
        LatLng(position.latitude, position.longitude),
        zoom: 18.5,
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _focusOnUser() {
    final p = _currentPosition;
    if (p == null) return;

    _mapControllerService.focusOnPoint(
      LatLng(p.latitude, p.longitude),
      zoom: 18.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = langCode == 'ar';

    final palette = _MapPalette.fromBrightness(isDark);
    final cubit = AppCubit.get(context);

    final renderer = MapZoneRenderer(
      baseGold: palette.gold,
      highlightColor: palette.active,
    );

    final activeZoneId = _currentZone?.zoneId;

    final circleZones = _zones.map((zone) {
      final color = cubit.getZoneColor(zone.zoneId, palette.gold);
      return CircleMarker(
        point: LatLng(zone.centerLat ?? 0.0, zone.centerLng ?? 0.0),
        radius: zone.radiusM ?? 0.0,
        useRadiusInMeter: true,
        color: color,
        borderColor: zone.zoneId == activeZoneId ? palette.active : palette.gold.withOpacity(0.5),
        borderStrokeWidth: zone.zoneId == activeZoneId ? 3.0 : 1.5,
      );
    }).toList();

    final polygonZones = renderer.buildPolygonZones(
      zones: _zones,
      activeZoneId: activeZoneId,
    );

    final labelMarkers = _zones
        .map((zone) => renderer.buildZoneLabelMarker(
      zone: zone,
      label: zone.displayName(langCode),
      isActive: zone.zoneId == activeZoneId,
    ))
        .whereType<Marker>()
        .toList();

    final userMarker = _buildUserMarker(palette: palette, position: _currentPosition, heading: cubit.userHeading);

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final memberMarkers = _members
        .where((m) => m.hasLocation && m.uid != myUid)
        .map((m) => _buildMemberMarker(palette, m))
        .toList();

    final allMarkers = <Marker>[
      ...labelMarkers,
      ...memberMarkers,
      if (userMarker != null) userMarker,
    ];

    return BlocBuilder<AppCubit, AppStates>(
      builder: (context, state) {
        return Container(
          color: palette.bg,
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      s.mapTitle,
                      style: TextStyle(color: palette.gold, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'AlamirBold'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(height: 1, color: palette.textMuted.withOpacity(.16)),
                  const SizedBox(height: 18),
                  _MapCard(
                    palette: palette,
                    child: Stack(
                      children: [
                        const _DotGridBackground(),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _currentPosition != null
                                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                                  : const LatLng(21.4132, 39.8711),
                              initialZoom: 18.1,
                              minZoom: 16.0,
                              maxZoom: 20.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: isDark
                                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                subdomains: const ['a', 'b', 'c', 'd'],
                                userAgentPackageName: 'dhakker',
                              ),
                              if (polygonZones.isNotEmpty) PolygonLayer(polygons: polygonZones),
                              if (circleZones.isNotEmpty) CircleLayer(circles: circleZones),
                              if (allMarkers.isNotEmpty) MarkerLayer(markers: allMarkers),
                            ],
                          ),
                        ),
                        PositionedDirectional(
                          top: 14,
                          start: 14,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _CurrentZoneChip(
                              key: ValueKey(_currentZone?.zoneId ?? 'no_zone'),
                              palette: palette,
                              text: _currentZone?.displayName(langCode) ?? s.mapNoZoneDetected,
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          bottom: 14,
                          start: 14,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _LegendRow(color: Colors.greenAccent, text: isAr ? "هادئ" : "Calm"),
                                const SizedBox(height: 4),
                                _LegendRow(color: Colors.orangeAccent, text: isAr ? "متوسط" : "Moderate"),
                                const SizedBox(height: 4),
                                _LegendRow(color: Colors.redAccent, text: isAr ? "مزدحم" : "Crowded"),
                              ],
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          end: 14,
                          bottom: 14,
                          child: _MiniBtn(palette: palette, icon: Icons.my_location_rounded, onTap: _focusOnUser),
                        ),
                        if (_isLoading)
                          Positioned.fill(
                            child: Container(color: Colors.black.withOpacity(.12), child: Center(child: CircularProgressIndicator(color: palette.gold))),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      isAr ? "تتبُّع الأشواط واتجاه القبلة" : "Rounds & Qibla Tracking",
                      style: TextStyle(color: palette.active, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'AlamirBold'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAr
                        ? "يدور مؤشّر القبلة تلقائيًا مع اتجاه جهازك ليدلّك على القبلة نحو الكعبة المشرفة, وتظهر مناطق المناسك على الخريطة فيُحتسب طوافك وسعيك تلقائيًا كلما تحرّكت بينها."
                        : "The Qibla pointer rotates automatically with your phone to guide you toward the Holy Kaaba, while the ritual zones appear on the map so your Tawaf and Sa'i rounds are counted automatically as you move through them.",
                    style: TextStyle(color: palette.textMuted, fontSize: 14, fontWeight: FontWeight.w600, height: 1.6),
                  ),
                  const SizedBox(height: 22),
                  Container(height: 1, color: palette.textMuted.withOpacity(.16)),
                  const SizedBox(height: 18),
                  _buildGroupSection(palette, isAr),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Marker? _buildUserMarker({required _MapPalette palette, required Position? position, required double heading}) {
    if (position == null) return null;
    return Marker(
      point: LatLng(position.latitude, position.longitude),
      width: 70,
      height: 70,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final o = (1 - _pulseController.value).clamp(0.0, 1.0);
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 0.9 + (0.55 * _pulseController.value),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: palette.active.withOpacity(0.10 + o * 0.10), border: Border.all(color: palette.active.withOpacity(0.22 + o * 0.12), width: 2)),
                ),
              ),
              Transform.rotate(
                angle: (heading * pi / 180) * -1,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.active,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [BoxShadow(color: palette.active.withOpacity(.4), blurRadius: 10)],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      child: Icon(Icons.navigation_rounded, size: 13, color: palette.active),
                    )
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // نقطة فرد المجموعة على الخريطة: دائرة بالحرف الأول واسمه الأول تحتها.
  Marker _buildMemberMarker(_MapPalette palette, GroupMember m) {
    final trimmed = m.name.trim();
    final initial = trimmed.isNotEmpty ? trimmed.substring(0, 1) : '؟';
    final firstName = trimmed.isNotEmpty ? trimmed.split(' ').first : '';
    return Marker(
      point: LatLng(m.lat!, m.lng!),
      width: 70,
      height: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: palette.gold,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.3), blurRadius: 6)],
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(color: Color(0xFF14171C), fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
          if (firstName.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                firstName,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtDistance(GroupMember m) {
    final p = _currentPosition;
    if (p == null || !m.hasLocation) return '—';
    final d = Geolocator.distanceBetween(p.latitude, p.longitude, m.lat!, m.lng!);
    if (d < 1000) return '${d.round()} م';
    return '${(d / 1000).toStringAsFixed(1)} كم';
  }

  // ─────────────────── واجهة قسم المجموعة ───────────────────

  Widget _buildGroupSection(_MapPalette palette, bool isAr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_rounded, color: palette.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                isAr ? 'مجموعتي' : 'My Group',
                style: TextStyle(color: palette.gold, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'AlamirBold'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_groupId == null) _buildNoGroup(palette, isAr) else _buildGroupCard(palette, isAr),
      ],
    );
  }

  Widget _buildNoGroup(_MapPalette palette, bool isAr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Text(
            isAr
                ? 'أنشئ مجموعة لعائلتك أو انضم بكود، لتشوفوا مواقع بعض على الخريطة وتتجنّبوا الضياع.'
                : 'Create a family group or join with a code to see each other on the map and avoid getting lost.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 13.5, height: 1.6, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _GroupButton(
                  label: isAr ? 'إنشاء مجموعة' : 'Create',
                  icon: Icons.add_rounded,
                  filled: true,
                  palette: palette,
                  onTap: _groupBusy ? null : _createGroup,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GroupButton(
                  label: isAr ? 'انضمام بكود' : 'Join',
                  icon: Icons.login_rounded,
                  filled: false,
                  palette: palette,
                  onTap: _groupBusy ? null : _joinGroup,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(_MapPalette palette, bool isAr) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final others = _members.where((m) => m.uid != myUid).toList()
      ..sort((a, b) {
        final p = _currentPosition;
        if (p == null) return 0;
        if (!a.hasLocation) return 1;
        if (!b.hasLocation) return -1;
        final da = Geolocator.distanceBetween(p.latitude, p.longitude, a.lat!, a.lng!);
        final db = Geolocator.distanceBetween(p.latitude, p.longitude, b.lat!, b.lng!);
        return da.compareTo(db);
      });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.gold.withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_groupName,
                        style: TextStyle(color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(_groupCode,
                        style: TextStyle(color: palette.gold, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showQr,
                icon: Icon(Icons.qr_code_2_rounded, color: palette.gold),
                tooltip: isAr ? 'عرض الكود' : 'Show code',
              ),
            ],
          ),
          const SizedBox(height: 8),
          // مفتاح مشاركة الموقع (بموافقة صريحة).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: palette.bg.withOpacity(.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(_sharing ? Icons.location_on_rounded : Icons.location_off_rounded,
                    color: _sharing ? palette.active : palette.textMuted, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAr ? 'مشاركة موقعي مع المجموعة' : 'Share my location',
                    style: TextStyle(color: palette.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ),
                Switch(
                  value: _sharing,
                  activeColor: palette.active,
                  onChanged: _toggleSharing,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (others.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                isAr ? 'لا يوجد أفراد آخرون بعد — شارك الكود لينضمّوا.' : 'No other members yet — share the code.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textMuted, fontSize: 13),
              ),
            )
          else
            ...others.map((m) => _memberRow(palette, isAr, m)),
          const SizedBox(height: 8),
          Align(
            alignment: isAr ? Alignment.centerLeft : Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _leaveGroup,
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFE0463F), size: 18),
              label: Text(isAr ? 'مغادرة المجموعة' : 'Leave group',
                  style: const TextStyle(color: Color(0xFFE0463F), fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberRow(_MapPalette palette, bool isAr, GroupMember m) {
    final trimmed = m.name.trim();
    final initial = trimmed.isNotEmpty ? trimmed.substring(0, 1) : '؟';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: palette.gold.withOpacity(.16), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(initial, style: TextStyle(color: palette.gold, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              trimmed.isEmpty ? (isAr ? 'حاج' : 'Pilgrim') : trimmed,
              style: TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            m.hasLocation ? _fmtDistance(m) : (isAr ? 'لم يشارك موقعه' : 'No location'),
            style: TextStyle(
              color: m.hasLocation ? palette.active : palette.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final _MapPalette palette;
  final VoidCallback? onTap;

  const _GroupButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? palette.gold : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: filled ? null : Border.all(color: palette.gold.withOpacity(.6), width: 1.3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: filled ? const Color(0xFF14171C) : palette.gold),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: filled ? const Color(0xFF14171C) : palette.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendRow({required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _MapPalette {
  final Color bg;
  final Color gold;
  final Color textPrimary;
  final Color textMuted;
  final Color card;
  final Color border;
  final Color shadow;
  final Color active;

  const _MapPalette({
    required this.bg,
    required this.gold,
    required this.textPrimary,
    required this.textMuted,
    required this.card,
    required this.border,
    required this.shadow,
    required this.active,
  });

  factory _MapPalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _MapPalette(
        bg: Color(0xFF0B0D10),
        gold: Color(0xFFD4AF37),
        textPrimary: Colors.white,
        textMuted: Color(0xFF9AA4B2),
        card: Color(0xFF303030),
        border: Color(0xFF1B1F26),
        shadow: Colors.black,
        active: Color(0xFF38C793),
      );
    }
    return const _MapPalette(
      bg: Color(0xFFF7F7F8),
      gold: Color(0xFFD4AF37),
      textPrimary: Color(0xFF121316),
      textMuted: Color(0xFF667085),
      card: Color(0xFFFFFFFF),
      border: Color(0xFFE5E7EB),
      shadow: Color(0x22000000),
      active: Color(0xFF2BAE7F),
    );
  }
}

class _MapCard extends StatelessWidget {
  final Widget child;
  final _MapPalette palette;
  const _MapCard({required this.child, required this.palette});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.border.withOpacity(.95), width: 1.2),
        boxShadow: [BoxShadow(color: palette.shadow.withOpacity(.16), blurRadius: 28, offset: const Offset(0, 18))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(26), child: child),
    );
  }
}

class _CurrentZoneChip extends StatelessWidget {
  final _MapPalette palette;
  final String text;
  const _CurrentZoneChip({super.key, required this.palette, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.black.withOpacity(.62), borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
    );
  }
}

class _DotGridBackground extends StatelessWidget {
  const _DotGridBackground();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DotGridPainter(), size: Size.infinite);
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(.06);
    const step = 22.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x + 8, y + 8), 1.2, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniBtn extends StatefulWidget {
  final _MapPalette palette;
  final IconData icon;
  final VoidCallback onTap;
  const _MiniBtn({required this.palette, required this.icon, required this.onTap});

  @override
  State<_MiniBtn> createState() => _MiniBtnState();
}

class _MiniBtnState extends State<_MiniBtn> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _scale = 0.92;
        });
      },
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
        });
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() {
          _scale = 1.0;
        });
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(.62),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.palette.gold.withOpacity(.22))
          ),
          child: Icon(widget.icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}