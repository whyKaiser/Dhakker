import 'package:animations/animations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhakker/Screens/Admin/Manage%20Zones/admin_zone_details_screen.dart';
import 'package:dhakker/shared/data/hajj_zones_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../generated/l10n.dart';
import '../../../theme/dhakker_theme.dart';
import '../Manage Supplications/admin_supplication_details_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 1. إحصائيات المنظومة الذكية (SOS & Crowd) ---
              _SectionTitle(title: isAr ? "إحصائيات المنظومة الذكية" : "Smart System Analytics"),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _CountCard(
                      title: isAr ? "إجمالي الحجاج" : "Total Pilgrims",
                      icon: Icons.people_alt_rounded,
                      accent: Colors.blue,
                      stream: FirebaseFirestore.instance.collection('users').snapshots(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CountCard(
                      title: isAr ? "نداءات SOS" : "SOS Alerts",
                      icon: Icons.warning_amber_rounded,
                      accent: Colors.redAccent,
                      stream: FirebaseFirestore.instance.collection('sos_requests').where('status', isEqualTo: 'active').snapshots(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CountCard(
                title: isAr ? "المتواجدون في النطاقات الآن" : "Currently in Zones",
                icon: Icons.mosque_rounded,
                accent: DhakkerColors.gold,
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                // تواجد حيّ فقط: نطاق غير فارغ + ختم زمني خلال آخر ٥ دقائق،
                // وإلا تُحسب وثائق حجّاج أغلقوا التطبيق داخل النطاق قبل ساعات.
                countWhere: (data) {
                  final zone = (data['currentZone'] ?? '').toString();
                  if (zone.isEmpty) return false;
                  final at = data['currentZoneAt'];
                  if (at is! Timestamp) return false;
                  return DateTime.now().difference(at.toDate()) <=
                      const Duration(minutes: 5);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _CountCard(
                      title: isAr ? "نشطون آخر ساعة" : "Active (1h)",
                      icon: Icons.online_prediction_rounded,
                      accent: const Color(0xFF38C793),
                      stream: FirebaseFirestore.instance.collection('users').snapshots(),
                      countWhere: (data) {
                        final at = data['currentZoneAt'];
                        if (at is! Timestamp) return false;
                        return DateTime.now().difference(at.toDate()) <=
                            const Duration(hours: 1);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CountCard(
                      title: isAr ? "SOS محلولة" : "SOS Resolved",
                      icon: Icons.check_circle_rounded,
                      accent: const Color(0xFF22C55E),
                      stream: FirebaseFirestore.instance
                          .collection('sos_requests')
                          .where('status', isEqualTo: 'resolved')
                          .snapshots(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // --- إشعار جماعي ---
              _SectionTitle(title: isAr ? "إشعار جماعي للحجاج" : "Broadcast Notification"),
              const SizedBox(height: 12),
              _BroadcastButton(isAr: isAr, isDark: isDark),

              const SizedBox(height: 24),

              // --- 2. ميزة تحليلات الأدعية الأكثر تشغيلاً ---
              _SectionTitle(title: isAr ? "الأدعية الأكثر تشغيلاً" : "Most Played Duas"),
              const SizedBox(height: 12),

              _LatestPanel(
                title: isAr ? "تحليل الاستخدام اللحظي" : "Usage Analytics",
                icon: Icons.trending_up_rounded,
                query: FirebaseFirestore.instance
                    .collection('supplications')
                    .orderBy('usage_count', descending: true)
                    .limit(3),
                itemBuilder: (data) {
                  final titleMap = (data['title'] is Map) ? data['title'] : {};
                  final title = isAr ? (titleMap['ar'] ?? 'دعاء') : (titleMap['en'] ?? 'Dua');
                  final count = data['usage_count'] ?? 0;

                  return _OpenContainerTileWrapper(
                    duaId: (data['duaId'] ?? '').toString(),
                    child: _LatestTile(
                      title: title.toString(),
                      subtitle: isAr ? "تم التشغيل $count مرة" : "Played $count times",
                      isActive: true,
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // --- 3. الأقسام الأصلية للمشروع (KPIs) ---
              _SectionTitle(title: s.adminDashKpiTitle),
              const SizedBox(height: 12),

              LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final isNarrow = w < 380;
                  final gap = isNarrow ? 10.0 : 12.0;

                  return Row(
                    children: [
                      Expanded(
                        child: _CountCard(
                          title: s.adminDashTotalZones,
                          icon: Icons.location_on_rounded,
                          accent: isDark ? DhakkerColors.gold : DhakkerColors.gold2,
                          stream: FirebaseFirestore.instance.collection('zones').snapshots(),
                        ),
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: _CountCard(
                          title: s.adminDashTotalSupplications,
                          icon: Icons.menu_book_rounded,
                          accent: isDark ? DhakkerColors.gold : DhakkerColors.gold2,
                          stream: FirebaseFirestore.instance.collection('supplications').snapshots(),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 18),
              _SectionTitle(title: s.adminDashLatestTitle),
              const SizedBox(height: 12),

              _LatestPanel(
                title: s.adminDashLatestZones,
                icon: Icons.location_on_rounded,
                query: FirebaseFirestore.instance
                    .collection('zones')
                    .orderBy('updatedAt', descending: true)
                    .limit(5),
                itemBuilder: (data) {
                  final langCode = Localizations.localeOf(context).languageCode;
                  final isAr = langCode == 'ar';

                  final name = isAr
                      ? (data['nameAr'] ?? data['nameEn'] ?? '')
                      : (data['nameEn'] ?? data['nameAr'] ?? '');

                  final type = (data['type'] ?? '').toString();
                  final isActive = data['isActive'] == true;

                  return _OpenContainerZoneWrapper(
                    zoneId: (data['zoneId'] ?? '').toString(),
                    child: _LatestTile(
                      title: name.toString().trim().isEmpty ? '—' : name.toString(),
                      subtitle: type.isEmpty ? '—' : type,
                      isActive: isActive,
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),
              const _LatestSupplicationsPanel(),

              const SizedBox(height: 28),
              _SectionTitle(title: isAr ? 'إعداد مناطق الحج' : 'Hajj Zones Setup'),
              const SizedBox(height: 12),
              const _SeedZonesButton(),
            ],
          ),
        ),
      ),
    );
  }
}

/// زر تحميل مناطق الحج الافتراضية إلى Firestore
class _SeedZonesButton extends StatefulWidget {
  const _SeedZonesButton();

  @override
  State<_SeedZonesButton> createState() => _SeedZonesButtonState();
}

class _SeedZonesButtonState extends State<_SeedZonesButton> {
  bool _loading = false;

  Future<void> _seed() async {
    setState(() => _loading = true);
    try {
      final result = await HajjZonesSeed.seedToFirestore();
      if (!mounted) return;
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      final added = result['added'] ?? 0;
      final skipped = result['skipped'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            isAr
                ? 'تم إضافة $added منطقة ✓  (تجاوزنا $skipped موجودة)'
                : 'Added $added zones ✓  (skipped $skipped existing)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('خطأ: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _seed,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.download_rounded, color: Colors.white),
        label: Text(
          isAr ? 'تحميل مناطق الحج الافتراضية' : 'Initialize Hajj Zones',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: DhakkerColors.gold,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: .1,
            ),
          ),
        ),
        Container(
          width: 26,
          height: 3,
          decoration: BoxDecoration(
            color: muted.withOpacity(.35),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  // فلتر اختياري للعدّ على مستوى العميل (مثل استبعاد التواجد القديم).
  final bool Function(Map<String, dynamic> data)? countWhere;

  const _CountCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.stream,
    this.countWhere,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          right: BorderSide(color: accent.withOpacity(.75), width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .30 : .07),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          final loading = snap.connectionState == ConnectionState.waiting;
          final docs = snap.data?.docs ?? const [];
          final count = countWhere == null
              ? docs.length
              : docs.where((d) => countWhere!(d.data())).length;

          return Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(isDark ? .10 : .12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withOpacity(.22), width: 1),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted.withOpacity(.95),
                        fontSize: 12.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: loading
                          ? const _SkeletonBar()
                          : TweenAnimationBuilder<double>(
                        // إضافة عداد رقمي تصاعدي ذكي للإحصائيات الحية لإبهار اللجنة
                        tween: Tween<double>(begin: 0, end: count.toDouble()),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Text(
                            '${value.toInt()}',
                            key: ValueKey(count),
                            style: TextStyle(
                              color: text,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LatestSupplicationsPanel extends StatelessWidget {
  const _LatestSupplicationsPanel();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    final query = FirebaseFirestore.instance
        .collection('supplications')
        .orderBy('updatedAt', descending: true)
        .limit(5);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          right: BorderSide(color: accent.withOpacity(.55), width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .30 : .07),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.adminDashLatestSupplications,
                  style: TextStyle(
                    color: text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Column(
                  children: [
                    _SkeletonTile(),
                    _SkeletonTile(),
                    _SkeletonTile(),
                  ],
                );
              }

              final docs = snap.data?.docs ?? const [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    s.adminDashNoData,
                    style: TextStyle(
                      color: muted.withOpacity(.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              final zoneIds = <String>{
                for (final d in docs) (d.data()['zoneId'] ?? '').toString().trim()
              }..removeWhere((e) => e.isEmpty);

              return FutureBuilder<Map<String, String>>(
                future: _loadZoneNames(context, zoneIds.toList(growable: false)),
                builder: (context, zonesSnap) {
                  final zoneNameById = zonesSnap.data ?? {};

                  return Column(
                    children: docs.map((d) {
                      final data = d.data();

                      final langCode = Localizations.localeOf(context).languageCode;
                      final isAr = langCode == 'ar';

                      final titleMap = (data['title'] is Map) ? (data['title'] as Map) : {};
                      final title = isAr
                          ? (titleMap['ar'] ?? titleMap['en'] ?? '').toString().trim()
                          : (titleMap['en'] ?? titleMap['ar'] ?? '').toString().trim();

                      final zoneId = (data['zoneId'] ?? '').toString().trim();
                      final zoneName = zoneId.isEmpty ? '—' : (zoneNameById[zoneId] ?? zoneId);

                      final audioMode = (data['audioMode'] ?? '').toString().trim();
                      final isActive = data['isActive'] == true;

                      return _OpenContainerTileWrapper(
                        duaId: (data['duaId'] ?? d.id).toString(),
                        child: _LatestTile2(
                          title: title.isEmpty ? '—' : title,
                          zoneName: zoneName,
                          audioMode: audioMode,
                          isActive: isActive,
                        ),
                      );
                    }).toList(growable: false),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>> _loadZoneNames(BuildContext context, List<String> zoneIds) async {
    if (zoneIds.isEmpty) return {};

    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';

    final firestore = FirebaseFirestore.instance;
    final futures = zoneIds.map((id) => firestore.collection('zones').doc(id).get()).toList();
    final snaps = await Future.wait(futures);

    final map = <String, String>{};
    for (final doc in snaps) {
      if (!doc.exists) continue;
      final data = doc.data() ?? {};

      final name = isAr
          ? (data['nameAr'] ?? data['nameEn'] ?? '').toString().trim()
          : (data['nameEn'] ?? data['nameAr'] ?? '').toString().trim();

      if (name.isNotEmpty) map[doc.id] = name;
    }
    return map;
  }
}

class _LatestTile2 extends StatelessWidget {
  final String title;
  final String zoneName;
  final String audioMode;
  final bool isActive;

  const _LatestTile2({
    required this.title,
    required this.zoneName,
    required this.audioMode,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;
    final dotColor = isActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: (isDark ? Colors.white : Colors.black).withOpacity(.03),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withOpacity(.30),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 13.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${s.adminDashZoneLabel}: $zoneName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted.withOpacity(.92),
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (audioMode.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${s.adminDashAudioModeLabel}: $audioMode',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: muted.withOpacity(.92),
                      fontSize: 12.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: accent),
        ],
      ),
    );
  }
}

class _LatestPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Query<Map<String, dynamic>> query;
  final Widget Function(Map<String, dynamic> data) itemBuilder;

  const _LatestPanel({
    required this.title,
    required this.icon,
    required this.query,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          right: BorderSide(color: accent.withOpacity(.55), width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .30 : .07),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Column(
                  children: [
                    _SkeletonTile(),
                    _SkeletonTile(),
                    _SkeletonTile(),
                  ],
                );
              }

              final docs = snap.data?.docs ?? const [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    S.of(context).adminDashNoData,
                    style: TextStyle(
                      color: muted.withOpacity(.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              return Column(
                children: docs
                    .map((d) => itemBuilder(d.data()))
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LatestTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isActive;

  const _LatestTile({
    required this.title,
    required this.subtitle,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;
    final dotColor = isActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: (isDark ? Colors.white : Colors.black).withOpacity(.03),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withOpacity(.30),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 13.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted.withOpacity(.92),
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: accent),
        ],
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = (isDark ? Colors.white : Colors.black).withOpacity(isDark ? .06 : .05);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: base,
      ),
      child: const Row(
        children: [
          _SkeletonBar(width: 10, height: 10),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                _SkeletonBar(height: 12, width: double.infinity),
                SizedBox(height: 8),
                _SkeletonBar(height: 10, width: double.infinity),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  final double width;
  final double height;
  const _SkeletonBar({this.width = 42, this.height = 18});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// =============================================================================
// مغلفات أنميشن تمدد الحاويات الفخمة لربط الشاشات (Animations Package Wrappers)
// =============================================================================

class _OpenContainerTileWrapper extends StatelessWidget {
  final String duaId;
  final Widget child;

  const _OpenContainerTileWrapper({
    required this.duaId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;

    return OpenContainer(
      transitionDuration: const Duration(milliseconds: 550),
      transitionType: ContainerTransitionType.fadeThrough,
      closedColor: Colors.transparent,
      closedElevation: 0,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      closedBuilder: (context, action) {
        return _HapticScaleWrapper(
          onTap: () {
            HapticFeedback.lightImpact();
            action();
          },
          child: child,
        );
      },
      openColor: bg,
      openBuilder: (context, _) {
        // تم قفل وتثبيت اسم البارامتر الصحيح المتوافق مع شاشة التفاصيل عندك
        return AdminSupplicationDetailsScreen(supplicationId: duaId);
      },
    );
  }
}

class _OpenContainerZoneWrapper extends StatelessWidget {
  final String zoneId;
  final Widget child;

  const _OpenContainerZoneWrapper({
    required this.zoneId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;

    return OpenContainer(
      transitionDuration: const Duration(milliseconds: 550),
      transitionType: ContainerTransitionType.fadeThrough,
      closedColor: Colors.transparent,
      closedElevation: 0,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      closedBuilder: (context, action) {
        return _HapticScaleWrapper(
          onTap: () {
            HapticFeedback.lightImpact();
            action();
          },
          child: child,
        );
      },
      openColor: bg,
      openBuilder: (context, _) {
        // تم قفل وتثبيت اسم البارامتر الصحيح المتوافق مع شاشة التفاصيل عندك
        return AdminZoneDetailsScreen(zoneId: zoneId);
      },
    );
  }
}

class _HapticScaleWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _HapticScaleWrapper({
    required this.child,
    required this.onTap,
  });

  @override
  State<_HapticScaleWrapper> createState() => _HapticScaleWrapperState();
}

class _HapticScaleWrapperState extends State<_HapticScaleWrapper> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _scale = 0.96;
        });
      },
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
        });
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
        child: widget.child,
      ),
    );
  }
}

// ─── إشعار جماعي ─────────────────────────────────────────────────────────────
class _BroadcastButton extends StatefulWidget {
  final bool isAr;
  final bool isDark;
  const _BroadcastButton({required this.isAr, required this.isDark});

  @override
  State<_BroadcastButton> createState() => _BroadcastButtonState();
}

class _BroadcastButtonState extends State<_BroadcastButton> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final msg = _ctrl.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('broadcasts').add({
        'message': msg,
        'timestamp': FieldValue.serverTimestamp(),
        'sentBy': 'admin',
      });
      _ctrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isAr ? 'تم الإرسال بنجاح' : 'Sent successfully'),
          backgroundColor: const Color(0xFF22C55E),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isAr ? 'فشل الإرسال' : 'Send failed'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final textColor = widget.isDark ? Colors.white : DhakkerColors.lightText;
    final muted = widget.isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DhakkerColors.gold.withOpacity(.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDark ? .25 : .06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_rounded,
                  color: DhakkerColors.gold, size: 22),
              const SizedBox(width: 10),
              Text(
                widget.isAr
                    ? 'اكتب رسالة لجميع الحجاج'
                    : 'Write a message to all pilgrims',
                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            textDirection: widget.isAr ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(color: textColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: widget.isAr
                  ? 'مثال: يُرجى التوجّه نحو الباب الشمالي...'
                  : 'e.g. Please proceed to the north gate...',
              hintStyle: TextStyle(color: muted.withOpacity(.6), fontSize: 13),
              filled: true,
              fillColor: widget.isDark
                  ? Colors.white.withOpacity(.05)
                  : Colors.black.withOpacity(.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: DhakkerColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              label: Text(
                widget.isAr ? 'إرسال للجميع' : 'Send to All',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}