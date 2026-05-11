import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../generated/l10n.dart';
import '../../../bloc/cubit.dart';
import '../../../bloc/states.dart';
import 'controllers/home_dua_controller.dart';
import 'services/dua_playback_service.dart';
import 'services/supplication_service.dart';
import 'services/zone_detection_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _ring1;
  late final Animation<double> _ring2;
  late final Animation<double> _ring3;
  late final HomeDuaController _controller;

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
      CurvedAnimation(parent: _pulseController, curve: const Interval(0.15, 1.0, curve: Curves.easeOut)),
    );
    _ring3 = Tween<double>(begin: 0.76, end: 1.44).animate(
      CurvedAnimation(parent: _pulseController, curve: const Interval(0.30, 1.0, curve: Curves.easeOut)),
    );

    _controller = HomeDuaController(
      firestore: FirebaseFirestore.instance,
      auth: FirebaseAuth.instance,
      zoneDetectionService: const ZoneDetectionService(),
      supplicationService: SupplicationService(
        firestore: FirebaseFirestore.instance,
      ),
      playbackService: DuaPlaybackService(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final langCode = Localizations.localeOf(context).languageCode;
      await _controller.init(langCode);
    });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final palette = _DhakkerPalette.fromBrightness(isDark);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final zoneName = _controller.displayedZoneName(langCode);
        final duaTitle = _controller.displayedDuaTitle(langCode, 0);
        final duaText = _controller.displayedDuaText(langCode, 0);

        // تفعيل منطق العداد عند دخول منطقة
        if (_controller.hasDetectedZone && zoneName != null && duaText != null) {
          AppCubit.get(context).checkLapCounter(zoneName, duaText);
        }

        String statusText() {
          if (_controller.isLoading) return s.homeStatusLoading;
          if (!_controller.autoLocationEnabled) return s.homeStatusAutoLocationDisabled;
          if (_controller.errorMessage == 'location_unavailable') return s.homeStatusLocationUnavailable;
          if (!_controller.hasDetectedZone) return s.homeStatusNoZone;
          return s.homeCurrentLocation;
        }

        String primaryButtonText() {
          if (!_controller.hasDua) return s.homeNoDuaButton;
          if (_controller.voiceNotificationsEnabled) return s.homeReplayDua;
          return s.homeReadDua;
        }

        return Container(
          color: palette.screenBg,
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: palette.gold,
              backgroundColor: palette.card,
              onRefresh: () async => await _controller.refreshSettings(langCode),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                child: Column(
                  children: [
                    const SizedBox(height: 14),

                    // --- العداد بتنسيق الكبسولة الذهبية ---
                    BlocBuilder<AppCubit, AppState>(
                      builder: (context, state) {
                        var lapCount = AppCubit.get(context).lapCount;
                        return Column(
                          children: [
                            Text("الشوط الحالي", style: TextStyle(color: palette.muted, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: palette.gold.withOpacity(0.35), width: 1.2),
                              ),
                              child: Text(
                                "$lapCount / 7",
                                style: TextStyle(color: palette.gold, fontSize: 26, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    Center(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              _PulseRing(scale: _ring3.value, opacity: (1 - _pulseController.value).clamp(0.0, 1.0) * 0.14, color: palette.gold),
                              _PulseRing(scale: _ring2.value, opacity: (1 - (_pulseController.value * 1.05)).clamp(0.0, 1.0) * 0.18, color: palette.gold),
                              _PulseRing(scale: _ring1.value, opacity: (1 - (_pulseController.value * 1.10)).clamp(0.0, 1.0) * 0.22, stroke: 2, color: palette.gold),
                              Container(
                                width: 126, height: 126,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: palette.screenBg,
                                  border: Border.all(color: palette.gold.withOpacity(.42), width: 1.3),
                                  boxShadow: [BoxShadow(color: palette.gold.withOpacity(.10), blurRadius: 30, offset: const Offset(0, 18))],
                                ),
                                alignment: Alignment.center,
                                child: Image.asset('assets/images/kaaba.png', width: 68, height: 68, fit: BoxFit.contain),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(statusText(), textAlign: TextAlign.center, style: TextStyle(color: palette.muted, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Text(zoneName ?? s.homeNoZoneDetected, textAlign: TextAlign.center, style: TextStyle(color: palette.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, height: 1.12, fontFamily: 'AlamirBold')),
                    const SizedBox(height: 22),

                    // --- بطاقة الدعاء الأساسية ---
                    _DuaCard(
                      palette: palette,
                      title: duaTitle ?? s.homeRecommendedNow,
                      dua: duaText ?? s.homeNoDuaMessage,
                      buttonText: primaryButtonText(),
                      canPlay: _controller.hasDua,
                      isPlaying: _controller.isPlaying,
                      playingText: s.homePlayingNow,
                      onDone: _controller.hasDua ? () async => await _controller.onPrimaryButtonTap(langCode, 0) : null,
                    ),

                    // --- قائمة الأدعية الإضافية ---
                    if (_controller.hasDua && _controller.displayedDuaText(langCode, 1) != null) ...[
                      const SizedBox(height: 28),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text('أدعية أخرى مخصصة لهذا المكان:', style: TextStyle(color: palette.gold, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'AlamirBold')),
                      ),
                      const SizedBox(height: 12),

                      // نعرض الأدعية الإضافية المتاحة
                      for (int i = 1; i < 4; i++)
                        if (_controller.displayedDuaText(langCode, i) != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: palette.card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: palette.gold.withOpacity(0.12)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: palette.chipBg, borderRadius: BorderRadius.circular(10)),
                                  child: Text(_controller.displayedDuaTitle(langCode, i) ?? '', style: TextStyle(color: palette.gold, fontSize: 13, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 10),
                                Text(_controller.displayedDuaText(langCode, i) ?? '', style: TextStyle(color: palette.textPrimary, fontSize: 16, height: 1.6, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: InkWell(
                                    onTap: () async => await _controller.onPrimaryButtonTap(langCode, i),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(color: palette.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.play_circle_fill_rounded, color: palette.gold, size: 20),
                                          const SizedBox(width: 6),
                                          Text('تشغيل الدعاء', style: TextStyle(color: palette.gold, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
        );
      },
    );
  }
}

// --- الكلاسات المساعدة (بدون أي تعديل خارجي) ---

class _DhakkerPalette {
  final Color screenBg, card, gold, gold2, muted, textPrimary, textSecondary, chipBg, shadow;
  const _DhakkerPalette({required this.screenBg, required this.card, required this.gold, required this.gold2, required this.muted, required this.textPrimary, required this.textSecondary, required this.chipBg, required this.shadow});
  factory _DhakkerPalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _DhakkerPalette(screenBg: Color(0xFF0B0D10), card: Color(0xFF303030), gold: Color(0xFFD4AF37), gold2: Color(0xFFB98B2E), muted: Color(0xFF9AA4B2), textPrimary: Colors.white, textSecondary: Color(0xFFCBD5E1), chipBg: Color(0xFF181B20), shadow: Colors.black);
    }
    return const _DhakkerPalette(screenBg: Color(0xFFF7F7F8), card: Color(0xFFFFFFFF), gold: Color(0xFFD4AF37), gold2: Color(0xFFB98B2E), muted: Color(0xFF667085), textPrimary: Color(0xFF121316), textSecondary: Color(0xFF475467), chipBg: Color(0xFFF3F4F6), shadow: Color(0x22000000));
  }
}

class _PulseRing extends StatelessWidget {
  final double scale, opacity, stroke; final Color color;
  const _PulseRing({required this.scale, required this.opacity, required this.color, this.stroke = 1.6});
  @override
  Widget build(BuildContext context) {
    return Transform.scale(scale: scale, child: Container(width: 240, height: 240, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withOpacity(opacity), width: stroke))));
  }
}

class _DuaCard extends StatelessWidget {
  final _DhakkerPalette palette; final String title, dua, buttonText, playingText; final bool canPlay, isPlaying; final VoidCallback? onDone;
  const _DuaCard({required this.palette, required this.title, required this.dua, required this.buttonText, required this.canPlay, required this.isPlaying, required this.playingText, required this.onDone});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(color: palette.card, borderRadius: BorderRadius.circular(24), border: BorderDirectional(end: BorderSide(color: palette.gold.withOpacity(.78), width: 3.2)), boxShadow: [BoxShadow(color: palette.shadow.withOpacity(.14), blurRadius: 24, offset: const Offset(0, 16))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: AlignmentDirectional.centerEnd, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: palette.chipBg, borderRadius: BorderRadius.circular(14)), child: Text(title, style: TextStyle(color: palette.gold, fontSize: 15, fontWeight: FontWeight.w900)))),
          const SizedBox(height: 16),
          Text(dua, textAlign: TextAlign.center, style: TextStyle(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w800, height: 1.7)),
          if (isPlaying) ...[const SizedBox(height: 14), Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.graphic_eq_rounded, color: palette.gold, size: 20), const SizedBox(width: 8), Text(playingText, style: TextStyle(color: palette.gold, fontSize: 14, fontWeight: FontWeight.w800))])],
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: canPlay ? LinearGradient(colors: [palette.gold.withOpacity(.98), palette.gold2.withOpacity(.98)]) : LinearGradient(colors: [palette.muted.withOpacity(.45), palette.muted.withOpacity(.32)])),
              child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: canPlay ? onDone : null, child: Center(child: Text(buttonText, style: TextStyle(color: canPlay ? const Color(0xFF14171C) : palette.textPrimary.withOpacity(.70), fontSize: 17, fontWeight: FontWeight.w900))))),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryActionCard extends StatelessWidget {
  final _DhakkerPalette palette; final IconData icon; final String title; final VoidCallback onTap;
  const _SecondaryActionCard({required this.palette, required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.card, borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20), onTap: onTap,
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: palette.gold.withOpacity(.14)), boxShadow: [BoxShadow(color: palette.shadow.withOpacity(.08), blurRadius: 18, offset: const Offset(0, 10))]),
          child: Row(children: [Icon(icon, color: palette.gold, size: 22), const SizedBox(width: 12), Expanded(child: Text(title, style: TextStyle(color: palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)))]),
        ),
      ),
    );
  }
}