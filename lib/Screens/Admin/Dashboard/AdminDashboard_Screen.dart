import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhakker/Screens/Admin/Manage%20Zones/admin_zone_details_screen.dart';
import 'package:dhakker/Screens/Components/components.dart';
import 'package:flutter/material.dart';
import '../../../generated/l10n.dart';
import '../../../theme/dhakker_theme.dart';
import '../Manage Supplications/admin_supplication_details_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;

    return Container(
      color: bg,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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

                  return _LatestTile(
                    title: name.toString().trim().isEmpty ? '—' : name.toString(),
                    subtitle: type.isEmpty ? '—' : type,
                    isActive: isActive,
                    onClick: ()
                    {
                      GoToScreen(context: context, screen: AdminZoneDetailsScreen(zoneId: data['zoneId']));
                    },
                  );
                },
              ),

              const SizedBox(height: 12),

              const _LatestSupplicationsPanel(),
            ],
          ),
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

  const _CountCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
          final count = snap.data?.docs.length ?? 0;

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
                          ? _ShimmerBar(color: muted)
                          : Text(
                        '$count',
                        key: ValueKey(count),
                        style: TextStyle(
                          color: text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                return Column(
                  children: const [
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

                      final subtitleWidget = InkWell(
                        onTap: ()
                        {
                          GoToScreen(context: context, screen: AdminSupplicationDetailsScreen(supplicationId:data['duaId'] ,));
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children:
                               [
                                 Text(
                                   '${S.of(context).adminDashZoneLabel}: $zoneName',
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
                                     '${S.of(context).adminDashAudioModeLabel}: $audioMode',
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

                            IconButton(onPressed: ()
                            {
                              GoToScreen(context: context, screen: AdminSupplicationDetailsScreen(supplicationId:data['duaId'] ,));
                            }, icon: Icon(Icons.arrow_forward_ios,size: 15,))
                          ],
                        ),
                      );

                      return _LatestTile2(
                        title: title.isEmpty ? '—' : title,
                        subtitle: subtitleWidget,
                        isActive: isActive,
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
  final Widget subtitle;
  final bool isActive;

  const _LatestTile2({
    required this.title,
    required this.subtitle,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : DhakkerColors.lightText;

    final dotColor = isActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: (isDark ? Colors.white : Colors.black).withOpacity(.04),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(.06),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withOpacity(.22),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
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
                subtitle,
              ],
            ),
          ),
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                return Column(
                  children: const [
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
  final VoidCallback onClick;

  const _LatestTile({
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    final dotColor = isActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return InkWell(
      onTap: onClick,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: (isDark ? Colors.white : Colors.black).withOpacity(.04),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withOpacity(.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withOpacity(.22),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
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
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: base,
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(.10),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(.10),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(.08),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  final Color color;
  const _ShimmerBar({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 18,
      decoration: BoxDecoration(
        color: color.withOpacity(.20),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}