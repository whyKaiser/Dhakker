import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../bloc/cubit.dart';
import '../../../bloc/states.dart';
import '../../../generated/l10n.dart';
import '../../../services/prayer_times_service.dart';
import '../../../services/weather_service.dart';
import '../Duas/widgets/content_kind_card.dart';
import 'controllers/home_dua_controller.dart';
import 'models/supplication_model.dart';
import 'services/dua_playback_service.dart';
import 'services/supplication_service.dart';
import 'services/zone_detection_service.dart';
import '../widgets/alerts_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _ring1;
  late final Animation<double> _ring2;
  late final Animation<double> _ring3;
  late final HomeDuaController _controller;

  // متغير للتحكم في أنميشن ارتداد كبسولة العداد عند الضغط
  double _roundButtonScale = 1.0;
  // نفس التأثير لكبسولة عدّاد السعي
  double _saiButtonScale = 1.0;

  String? _userName;
  bool _showWelcome = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();

    _ring1 = Tween<double>(begin: 0.92, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _ring2 = Tween<double>(begin: 0.84, end: 1.30).animate(
      CurvedAnimation(
          parent: _pulseController,
          curve: const Interval(0.15, 1.0, curve: Curves.easeOut)),
    );
    _ring3 = Tween<double>(begin: 0.76, end: 1.44).animate(
      CurvedAnimation(
          parent: _pulseController,
          curve: const Interval(0.30, 1.0, curve: Curves.easeOut)),
    );

    _loadUserName();
    // أظهر بطاقة الترحيب 5 ثوانٍ فقط
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showWelcome = true);
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showWelcome = false);
    });

    _controller = HomeDuaController(
      firestore: FirebaseFirestore.instance,
      auth: FirebaseAuth.instance,
      zoneDetectionService: const ZoneDetectionService(),
      supplicationService: SupplicationService(
        firestore: FirebaseFirestore.instance,
      ),
      playbackService: DuaPlaybackService(),
    );

    // تغذية عدّاد الأشواط من ستريم موقع الشاشة الرئيسية أيضاً (تغطية إضافية).
    _controller.onPositionUpdate = (pos) {
      if (mounted) {
        AppCubit.get(context).updateLocationAndCheckRounds(pos);
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final langCode = Localizations.localeOf(context).languageCode;
      await _controller.init(langCode);
    });
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String? name = user.displayName;
    if (name == null || name.trim().isEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = doc.data();
        name = (data?['fullName'] ?? data?['name'])?.toString();
      } catch (_) {}
    }
    if (mounted && name != null && name.trim().isNotEmpty) {
      setState(() => _userName = name!.split(' ').first);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final langCode = Localizations.localeOf(context).languageCode;
    _controller.refreshSettings(langCode);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final palette = _DhakkerPalette.fromBrightness(isDark);

    return BlocBuilder<AppCubit, AppStates>(
      builder: (context, state) {
        final appCubit = AppCubit.get(context);

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final zoneName = _controller.displayedZoneName(langCode);
            final duaTitle = _controller.displayedDuaTitle(langCode, 0);
            final duaText = _controller.displayedDuaText(langCode, 0);
            // نُسُك المنطقة الحالية: نُظهر عدّاد الطواف داخل المطاف، وعدّاد
            // السعي داخل المسعى فقط، فتبقى الشاشة الرئيسية مرتّبة.
            final ritual = _controller.currentRitual;

            String statusText() {
              if (_controller.isLoading) return s.homeStatusLoading;
              if (!_controller.autoLocationEnabled)
                return s.homeStatusAutoLocationDisabled;
              if (_controller.errorMessage == 'location_unavailable')
                return s.homeStatusLocationUnavailable;
              if (!_controller.hasDetectedZone) return s.homeStatusNoZone;
              return s.homeCurrentLocation;
            }

            String primaryButtonText() {
              if (!_controller.hasDua) return s.homeNoDuaButton;
              if (_controller.voiceNotificationsEnabled) return s.homeReplayDua;
              return s.homeReadDua;
            }

            return _entranceWrap(Container(
              color: palette.screenBg,
              child: SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  color: palette.gold,
                  backgroundColor: palette.card,
                  onRefresh: () async =>
                      await _controller.refreshSettings(langCode),
                  child: SingleChildScrollView(
                    // تفعيل فيزياء الارتداد والتمطيط عند السحب لأعلى وأسفل (iOS Feel)
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                    child: Column(
                      children: [
                        const SizedBox(height: 14),
                        // --- بطاقة ترحيب تظهر 5 ثوانٍ فقط عند الدخول ---
                        if (_userName != null && _showWelcome)
                          _WelcomeCard(
                            name: _userName!,
                            palette: palette,
                            isAr: isAr,
                          ),
                        // --- شريط تنبيهات الإدارة (سحب يميناً لإخفائه) ---
                        const AlertsBanner(),
                        // --- مواقيت الصلاة + تحذير ضربة الشمس ---
                        _TopInfoSection(palette: palette, isAr: isAr),
                        // --- تصميم الكعبة والنبضات ---
                        Center(
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  _PulseRing(
                                      scale: _ring3.value,
                                      opacity: (1 - _pulseController.value)
                                              .clamp(0.0, 1.0) *
                                          0.14,
                                      color: palette.gold),
                                  _PulseRing(
                                      scale: _ring2.value,
                                      opacity:
                                          (1 - (_pulseController.value * 1.05))
                                                  .clamp(0.0, 1.0) *
                                              0.18,
                                      color: palette.gold),
                                  _PulseRing(
                                      scale: _ring1.value,
                                      opacity:
                                          (1 - (_pulseController.value * 1.10))
                                                  .clamp(0.0, 1.0) *
                                              0.22,
                                      stroke: 2,
                                      color: palette.gold),
                                  Container(
                                    width: 126,
                                    height: 126,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: palette.screenBg,
                                      border: Border.all(
                                          color: palette.gold.withOpacity(.42),
                                          width: 1.3),
                                      boxShadow: [
                                        BoxShadow(
                                            color:
                                                palette.gold.withOpacity(.10),
                                            blurRadius: 30,
                                            offset: const Offset(0, 18))
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Image.asset(
                                        'assets/images/kaaba.png',
                                        width: 68,
                                        height: 68,
                                        fit: BoxFit.contain),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        // عدّاد الطواف يظهر فقط داخل منطقة المطاف.
                        if (ritual == 'tawaf') ...[
                          const SizedBox(height: 24),

                          // --- كبسولة عداد الأشواط التفاعلية مع أنميشن ارتداد مرن (Scale Animation) ---
                          GestureDetector(
                            onTapDown: (_) {
                              setState(() {
                                _roundButtonScale =
                                    0.94; // تصغير خفيف عند لمس الزر
                              });
                            },
                            onTapUp: (_) {
                              setState(() {
                                _roundButtonScale =
                                    1.0; // رجوع الحجم الطبيعي عند رفع الإصبع
                              });
                            },
                            onTapCancel: () {
                              setState(() {
                                _roundButtonScale = 1.0;
                              });
                            },
                            onTap: () {
                              // الاهتزاز يصدر من الكيوبت نفسه (نقطة العدّ الموحّدة
                              // للمصادر الثلاثة: زر/GPS/بوصلة) فلا نكرره هنا.
                              appCubit.incrementRound();
                            },
                            child: AnimatedScale(
                              scale: _roundButtonScale,
                              duration: const Duration(milliseconds: 120),
                              curve: Curves.easeOutCubic,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [palette.gold, palette.gold2],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: palette.gold.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isAr ? "الشوط الحالي" : "Current Round",
                                      style: const TextStyle(
                                          color: Color(0xFF14171C),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF14171C)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 550),
                                        transitionBuilder: (child, anim) {
                                          final bounce = Tween<double>(
                                                  begin: 0.0, end: 1.0)
                                              .animate(
                                            CurvedAnimation(
                                                parent: anim,
                                                curve: Curves.elasticOut),
                                          );
                                          final slide = Tween<Offset>(
                                                  begin: const Offset(0, -0.8),
                                                  end: Offset.zero)
                                              .animate(
                                            CurvedAnimation(
                                                parent: anim,
                                                curve: Curves.easeOutCubic),
                                          );
                                          return SlideTransition(
                                            position: slide,
                                            child: ScaleTransition(
                                                scale: bounce, child: child),
                                          );
                                        },
                                        child: Text(
                                          "${appCubit.roundCount} / 7",
                                          key: ValueKey(appCubit.roundCount),
                                          style: const TextStyle(
                                              color: Color(0xFF14171C),
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              fontFamily: 'AlamirBold'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],

                        // عدّاد السعي يظهر فقط داخل منطقة السعي (الصفا/المروة/المسعى).
                        if (ritual == 'sai') ...[
                          const SizedBox(height: 24),

                          // --- كبسولة عدّاد السعي (الصفا ↔ المروة) بحدّ ذهبي مفرّغ لتمييزها عن الطواف ---
                          GestureDetector(
                            onTapDown: (_) =>
                                setState(() => _saiButtonScale = 0.94),
                            onTapUp: (_) =>
                                setState(() => _saiButtonScale = 1.0),
                            onTapCancel: () =>
                                setState(() => _saiButtonScale = 1.0),
                            onTap: () {
                              // الاهتزاز من الكيوبت (نقطة العدّ الموحّدة) — لا تكرار هنا.
                              appCubit.incrementSai();
                            },
                            child: AnimatedScale(
                              scale: _saiButtonScale,
                              duration: const Duration(milliseconds: 120),
                              curve: Curves.easeOutCubic,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 10),
                                decoration: BoxDecoration(
                                  color: palette.gold.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                      color: palette.gold.withOpacity(0.55),
                                      width: 1.4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isAr ? "شوط السعي" : "Sa'i Round",
                                      style: TextStyle(
                                          color: palette.gold,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: palette.gold.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 550),
                                        transitionBuilder: (child, anim) {
                                          final bounce = Tween<double>(
                                                  begin: 0.0, end: 1.0)
                                              .animate(
                                            CurvedAnimation(
                                                parent: anim,
                                                curve: Curves.elasticOut),
                                          );
                                          final slide = Tween<Offset>(
                                                  begin: const Offset(0, -0.8),
                                                  end: Offset.zero)
                                              .animate(
                                            CurvedAnimation(
                                                parent: anim,
                                                curve: Curves.easeOutCubic),
                                          );
                                          return SlideTransition(
                                            position: slide,
                                            child: ScaleTransition(
                                                scale: bounce, child: child),
                                          );
                                        },
                                        child: Text(
                                          "${appCubit.saiCount} / 7",
                                          key: ValueKey(appCubit.saiCount),
                                          style: TextStyle(
                                              color: palette.gold,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              fontFamily: 'AlamirBold'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),
                        Text(statusText(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: palette.muted,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        Text(zoneName ?? s.homeNoZoneDetected,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                height: 1.12,
                                fontFamily: 'AlamirBold')),
                        const SizedBox(height: 22),

                        // --- بطاقة الدعاء الأساسي ---
                        _DuaCard(
                          palette: palette,
                          title: duaTitle ?? s.homeRecommendedNow,
                          dua: duaText ?? s.homeNoDuaMessage,
                          kind: _controller.displayedDuaKind(0),
                          policy: _controller.displayedDuaPolicy(0),
                          buttonText: primaryButtonText(),
                          canPlay: _controller.hasDua,
                          isPlaying: _controller.isPlaying,
                          playingText: s.homePlayingNow,
                          onDone: _controller.hasDua
                              ? () async {
                                  await _controller.onPrimaryButtonTap(
                                      langCode, 0);
                                }
                              : null,
                        ),

                        // --- قائمة الأدعية الأخرى المحسنة للأداء عالي السلاسة ---
                        if (_controller.hasDua &&
                            _controller.duasCount > 1) ...[
                          const SizedBox(height: 28),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              // لا نقول «مخصصة لهذا المكان»: التخصيص يُنسب
                              // للمصدر، وهو يظهر في وسم كل بطاقة على حدة.
                              isAr
                                  ? 'أدعية أخرى تناسب هذا الموضع:'
                                  : 'More supplications you may say here:',
                              style: TextStyle(
                                  color: palette.gold,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'AlamirBold'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListView.builder(
                            shrinkWrap: true,
                            primary: false,
                            physics:
                                const NeverScrollableScrollPhysics(), // منع تعارض الاسكرول لثبات الفريمات
                            itemCount: _controller.duasCount - 1,
                            itemBuilder: (context, index) {
                              final realIndex = index + 1;
                              final otherTitle = _controller.displayedDuaTitle(
                                      langCode, realIndex) ??
                                  '';
                              final otherText = _controller.displayedDuaText(
                                      langCode, realIndex) ??
                                  '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: palette.card,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: palette.gold.withOpacity(0.12)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: palette.chipBg,
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Text(otherTitle,
                                          style: TextStyle(
                                              color: palette.gold,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    if (_controller
                                            .displayedDuaKind(realIndex) !=
                                        null) ...[
                                      const SizedBox(height: 8),
                                      ContentKindBadge(
                                          kind: _controller
                                              .displayedDuaKind(realIndex)!),
                                    ],
                                    const SizedBox(height: 10),
                                    Text(otherText,
                                        style: TextStyle(
                                            color: palette.textPrimary,
                                            fontSize: 16,
                                            height: 1.6,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: AlignmentDirectional.centerEnd,
                                      child: InkWell(
                                        onTap: () async => await _controller
                                            .onPrimaryButtonTap(
                                                langCode, realIndex),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                              color:
                                                  palette.gold.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                  Icons
                                                      .play_circle_fill_rounded,
                                                  color: palette.gold,
                                                  size: 20),
                                              const SizedBox(width: 6),
                                              Text(
                                                  isAr
                                                      ? 'تشغيل الدعاء'
                                                      : 'Play Dua',
                                                  style: TextStyle(
                                                      color: palette.gold,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],

                        // --- الإرشادات: قسم منفصل تمامًا عن الأدعية ---
                        // نصوص مثل «لا يصح الطواف من داخل الحِجْر» أحكام
                        // وتوجيهات، لا تُعرض تحت عنوان «دعاء» ولا تُشغَّل.
                        // الآثار المرويّة: بطاقتها الخاصة بعزوها. بلا هذا
                        // القسم كانت تختفي من الشاشة تمامًا — إذ يستبعدها
                        // recitableDuas بحق، ولا يلتقطها قسم الإرشادات.
                        if (_controller.evidenceItems.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              isAr
                                  ? 'آثار موثّقة (للفائدة لا للترديد):'
                                  : 'Recorded narrations (for benefit, not recitation):',
                              style: TextStyle(
                                  color: palette.gold,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'AlamirBold'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final item in _controller.evidenceItems)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: ContextualEvidenceCard(
                                title: item.titleByLanguage(langCode),
                                body: item.textByLanguage(langCode),
                                attribution: item.attribution,
                                references: item.sourceReferences,
                                cardColor: palette.card,
                                textColor: palette.textPrimary,
                              ),
                            ),
                        ],
                        if (_controller.guidanceItems.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              isAr
                                  ? 'إرشادات هذا الموضع (ليست أدعية):'
                                  : 'Guidance for this place (not supplications):',
                              style: TextStyle(
                                  color: palette.gold,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'AlamirBold'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final item in _controller.guidanceItems)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: GuidanceCard(
                                title: item.titleByLanguage(langCode),
                                body: item.textByLanguage(langCode),
                                attribution: item.attribution,
                                references: item.sourceReferences,
                                isPropheticDirective: true,
                                cardColor: palette.card,
                                textColor: palette.textPrimary,
                              ),
                            ),
                        ],

                        const SizedBox(height: 16),
                        if (_controller.hasDua && _controller.isPlaying)
                          _SecondaryActionCard(
                            palette: palette,
                            icon: Icons.stop_rounded,
                            title: s.homeStopPlayback,
                            onTap: () async => await _controller.stopPlayback(),
                          ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ));
          },
        );
      },
    );
  }
}

/// يلفّ محتوى الشاشة بأنميشن دخول ناعم (تلاشٍ + انزلاق خفيف للأعلى) يُشغَّل
/// مرة عند ظهور الشاشة — يعطي إحساساً حيّاً بإلهام iOS. يستخدم TweenAnimationBuilder
/// فلا يتكرّر مع إعادة بناء الحالة لأن حالته تبقى ثابتة في الشجرة.
Widget _entranceWrap(Widget child) {
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: const Duration(milliseconds: 600),
    curve: Curves.easeOutCubic,
    builder: (context, t, c) => Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(0, (1 - t) * 22), child: c),
    ),
    child: child,
  );
}

class _DhakkerPalette {
  final Color screenBg;
  final Color card;
  final Color gold;
  final Color gold2;
  final Color muted;
  final Color textPrimary;
  final Color textSecondary;
  final Color chipBg;
  final Color shadow;

  const _DhakkerPalette({
    required this.screenBg,
    required this.card,
    required this.gold,
    required this.gold2,
    required this.muted,
    required this.textPrimary,
    required this.textSecondary,
    required this.chipBg,
    required this.shadow,
  });

  factory _DhakkerPalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _DhakkerPalette(
        screenBg: Color(0xFF0B0D10),
        card: Color(0xFF303030),
        gold: Color(0xFFD4AF37),
        gold2: Color(0xFFB98B2E),
        muted: Color(0xFF9AA4B2),
        textPrimary: Colors.white,
        textSecondary: Color(0xFFCBD5E1),
        chipBg: Color(0xFF181B20),
        shadow: Colors.black,
      );
    }

    return const _DhakkerPalette(
      screenBg: Color(0xFFF7F7F8),
      card: Color(0xFFFFFFFF),
      gold: Color(0xFFD4AF37),
      gold2: Color(0xFFB98B2E),
      muted: Color(0xFF667085),
      textPrimary: Color(0xFF121316),
      textSecondary: Color(0xFF475467),
      chipBg: Color(0xFFF3F4F6),
      shadow: Color(0x22000000),
    );
  }
}

class _PulseRing extends StatelessWidget {
  final double scale;
  final double opacity;
  final double stroke;
  final Color color;

  const _PulseRing({
    required this.scale,
    required this.opacity,
    required this.color,
    this.stroke = 1.6,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withOpacity(opacity),
            width: stroke,
          ),
        ),
      ),
    );
  }
}

class _DuaCard extends StatelessWidget {
  final _DhakkerPalette palette;
  final String title;
  final String dua;
  final String buttonText;
  final bool canPlay;
  final bool isPlaying;
  final String playingText;
  final VoidCallback? onDone;

  /// تصنيف المحتوى — يُعرض كوسم ظاهر حتى لا يُفهم الدعاء العام على أنه
  /// مخصوص بهذا الموضع. null عندما لا يوجد دعاء معروض أصلاً.
  final SupplicationContentKind? kind;

  /// كيفية الأداء إن نصّ عليها المصدر.
  final RecitationPolicy? policy;

  const _DuaCard({
    this.policy,
    required this.palette,
    required this.title,
    required this.dua,
    required this.buttonText,
    required this.canPlay,
    required this.isPlaying,
    required this.playingText,
    required this.onDone,
    this.kind,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(24),
        border: BorderDirectional(
          end: BorderSide(
            color: palette.gold.withOpacity(.78),
            width: 3.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withOpacity(.14),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: palette.chipBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                title,
                style: TextStyle(
                  color: palette.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (kind != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ContentKindBadge(kind: kind!),
            ),
            if (policy != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: RecitationPolicyNote(
                    policy: policy, textColor: palette.textPrimary),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            dua,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.7,
            ),
          ),
          if (isPlaying) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.graphic_eq_rounded,
                  color: palette.gold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  playingText,
                  style: TextStyle(
                    color: palette.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: canPlay
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          palette.gold.withOpacity(.98),
                          palette.gold2.withOpacity(.98),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          palette.muted.withOpacity(.45),
                          palette.muted.withOpacity(.32),
                        ],
                      ),
                boxShadow: [
                  BoxShadow(
                    color: palette.gold.withOpacity(.16),
                    blurRadius: 22,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: canPlay ? onDone : null,
                  child: Center(
                    child: Text(
                      buttonText,
                      style: TextStyle(
                        color: canPlay
                            ? const Color(0xFF14171C)
                            : palette.textPrimary.withOpacity(.70),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة ترحيب تظهر بتلاشٍ ناعم عند فتح الشاشة ثم تنزوي تلقائياً بعد ٤ ثوانٍ
/// (تلاشٍ + انكماش) حتى لا تبقى ثابتة وتزاحم محتوى الشاشة.
class _WelcomeCard extends StatelessWidget {
  final String name;
  final _DhakkerPalette palette;
  final bool isAr;

  const _WelcomeCard({
    required this.name,
    required this.palette,
    required this.isAr,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (isAr) {
      if (h < 12) return 'صباح الخير';
      if (h < 17) return 'مساء الخير';
      return 'أهلاً وسهلاً';
    } else {
      if (h < 12) return 'Good morning';
      if (h < 17) return 'Good afternoon';
      return 'Welcome';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.gold.withOpacity(.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: palette.gold.withOpacity(.12)),
            child: Icon(Icons.person_rounded, color: palette.gold, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting(),
                  style: TextStyle(
                      color: palette.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              Text(name,
                  style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const Spacer(),
          Icon(Icons.favorite_rounded,
              color: palette.gold.withOpacity(.6), size: 18),
        ],
      ),
    );
  }
}

class _SecondaryActionCard extends StatelessWidget {
  final _DhakkerPalette palette;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SecondaryActionCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.gold.withOpacity(.14)),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withOpacity(.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: palette.gold,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// قسم أعلى الرئيسية: بطاقة مواقيت الصلاة (محسوبة محلياً بأم القرى) مع عدّ
/// تنازلي للصلاة القادمة، وبانر تحذير ضربة الشمس عند ارتفاع الحرارة.
class _TopInfoSection extends StatefulWidget {
  final _DhakkerPalette palette;
  final bool isAr;
  const _TopInfoSection({required this.palette, required this.isAr});

  @override
  State<_TopInfoSection> createState() => _TopInfoSectionState();
}

class _TopInfoSectionState extends State<_TopInfoSection> {
  final PrayerTimesService _prayerService = PrayerTimesService();
  final WeatherService _weatherService = WeatherService();

  PrayerTimesResult? _prayer;
  HeatAdvice? _heat;
  Timer? _ticker;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _load();
    // تحديث العدّ التنازلي والصلاة القادمة كل دقيقة.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => _recompute());
  }

  Future<void> _load() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      _lat = pos?.latitude;
      _lng = pos?.longitude;
    } catch (_) {/* نستخدم مكة افتراضياً */}
    _recompute();
    // الطقس عبر الشبكة (قد يتأخّر أو يفشل بلا نت — فيُستخدم تقدير الوقت).
    final advice = await _weatherService.currentAdvice(
      lat: _lat ?? 21.4225,
      lng: _lng ?? 39.8262,
    );
    if (mounted) setState(() => _heat = advice);
  }

  void _recompute() {
    final result = _prayerService.compute(lat: _lat, lng: _lng);
    if (mounted) setState(() => _prayer = result);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _fmtTime(DateTime t) {
    final m = t.minute.toString().padLeft(2, '0');
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final period =
        t.hour < 12 ? (widget.isAr ? 'ص' : 'AM') : (widget.isAr ? 'م' : 'PM');
    return '$h12:$m $period';
  }

  String _fmtCountdown(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) {
      return widget.isAr ? 'بعد $hس $mد' : 'in ${h}h ${m}m';
    }
    return widget.isAr ? 'بعد $m دقيقة' : 'in $m min';
  }

  @override
  Widget build(BuildContext context) {
    final p = _prayer;
    return Column(
      children: [
        if (p != null) _prayerCard(p),
        if (_heat != null && _heat!.level != HeatLevel.none)
          _heatBanner(_heat!),
      ],
    );
  }

  Widget _prayerCard(PrayerTimesResult p) {
    final palette = widget.palette;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.gold.withOpacity(.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // سطر 1: الصلاة القادمة + العدّ التنازلي
          Row(
            children: [
              Icon(Icons.access_time_rounded, color: palette.gold, size: 14),
              const SizedBox(width: 5),
              Text(
                widget.isAr ? p.next.nameAr : p.next.nameEn,
                style: TextStyle(
                  color: palette.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _fmtCountdown(p.untilNext),
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // سطر 2: جميع الأوقات موزّعة بالتساوي
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: p.all.map((pr) {
              final isNext = pr.nameEn == p.next.nameEn;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pr.nameAr,
                    style: TextStyle(
                      color: isNext ? palette.gold : palette.muted,
                      fontSize: 10,
                      fontWeight: isNext ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmtTime(pr.time),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: isNext ? palette.gold : palette.textSecondary,
                      fontSize: 10,
                      fontWeight: isNext ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _heatBanner(HeatAdvice h) {
    final danger = h.level == HeatLevel.danger;
    final color = danger ? const Color(0xFFE0463F) : const Color(0xFFE08A2E);
    final tempStr = h.temperature != null ? '${h.temperature!.round()}° ' : '';
    final String msg;
    if (danger) {
      msg = widget.isAr
          ? '🔥 خطر ضربة شمس ($tempStr) — ابتعد عن الشمس واحمل مظلّة وأكثر من الماء'
          : '🔥 Heat stroke risk ($tempStr) — avoid the sun, carry an umbrella, hydrate';
    } else {
      msg = widget.isAr
          ? '⚠️ حر شديد ($tempStr) — أكثر من شرب الماء واستظل قدر الإمكان'
          : '⚠️ Severe heat ($tempStr) — drink water often and seek shade';
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.55), width: 1.3),
      ),
      child: Row(
        children: [
          Icon(Icons.wb_sunny_rounded, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
