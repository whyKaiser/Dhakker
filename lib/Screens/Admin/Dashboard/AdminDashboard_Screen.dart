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

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          // زدنا الـ bottom لـ 120 عشان نحل مشكلة الـ overflow نهائياً
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTitle(title: s.adminDashKpiTitle),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final isNarrow = w < 380;
                  final gap = isNarrow ? 8.0 : 12.0;
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
              const SizedBox(height: 24),
              _SectionTitle(title: s.adminDashLatestTitle),
              const SizedBox(height: 14),
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
                  return _LatestTile(
                    title: name.toString().trim().isEmpty ? '—' : name.toString(),
                    subtitle: type.isEmpty ? '—' : type,
                    isActive: data['isActive'] == true,
                    onClick: () {
                      GoToScreen(context: context, screen: AdminZoneDetailsScreen(zoneId: data['zoneId']));
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
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
    return Row(
      children: [
        Expanded(
          child: Text(title, style: TextStyle(color: isDark ? Colors.white : DhakkerColors.lightText, fontSize: 16, fontWeight: FontWeight.w900)),
        ),
        Container(width: 26, height: 3, decoration: BoxDecoration(color: (isDark ? DhakkerColors.muted : DhakkerColors.lightMuted).withOpacity(.35), borderRadius: BorderRadius.circular(99))),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  const _CountCard({required this.title, required this.icon, required this.accent, required this.stream});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: isDark ? DhakkerColors.card : DhakkerColors.lightCard, borderRadius: BorderRadius.circular(18), border: Border(right: BorderSide(color: accent.withOpacity(.75), width: 3))),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          final count = snap.data?.docs.length ?? 0;
          return Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: accent.withOpacity(isDark ? .10 : .12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: accent, size: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: (isDark ? DhakkerColors.muted : DhakkerColors.lightMuted).withOpacity(.95), fontSize: 12.8, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('$count', style: TextStyle(color: isDark ? Colors.white : DhakkerColors.lightText, fontSize: 22, fontWeight: FontWeight.w900)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = FirebaseFirestore.instance.collection('supplications').orderBy('updatedAt', descending: true).limit(5);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: isDark ? DhakkerColors.card : DhakkerColors.lightCard, borderRadius: BorderRadius.circular(18), border: Border(right: BorderSide(color: (isDark ? DhakkerColors.gold : DhakkerColors.gold2).withOpacity(.55), width: 3))),
      child: Column(
        children: [
          Row(children: [Icon(Icons.menu_book_rounded, color: isDark ? DhakkerColors.gold : DhakkerColors.gold2, size: 20), const SizedBox(width: 10), Text(S.of(context).adminDashLatestSupplications, style: TextStyle(color: isDark ? Colors.white : DhakkerColors.lightText, fontSize: 14.5, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              return Column(
                children: docs.map((d) {
                  final data = d.data();
                  final isAr = Localizations.localeOf(context).languageCode == 'ar';
                  final titleMap = (data['title'] is Map) ? data['title'] : {};
                  final title = isAr ? (titleMap['ar'] ?? titleMap['en'] ?? '') : (titleMap['en'] ?? titleMap['ar'] ?? '');
                  return _LatestTile2(title: title.toString(), isActive: data['isActive'] == true, subtitle: Text('${S.of(context).adminDashZoneLabel}: ${data['zoneId'] ?? ""}', style: TextStyle(color: isDark ? DhakkerColors.muted : DhakkerColors.lightMuted, fontSize: 12)));
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LatestTile extends StatelessWidget {
  final String title, subtitle;
  final bool isActive;
  final VoidCallback onClick;
  const _LatestTile({required this.title, required this.subtitle, required this.isActive, required this.onClick});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = isActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    return InkWell(
      onTap: onClick,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: (isDark ? Colors.white : Colors.black).withOpacity(.04)),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: isDark ? Colors.white : DhakkerColors.lightText, fontWeight: FontWeight.w900, fontSize: 13.8)), Text(subtitle, style: TextStyle(color: isDark ? DhakkerColors.muted : DhakkerColors.lightMuted, fontSize: 12.2))])),
          ],
        ),
      ),
    );
  }
}

class _LatestTile2 extends StatelessWidget {
  final String title;
  final Widget subtitle;
  final bool isActive;
  const _LatestTile2({required this.title, required this.subtitle, required this.isActive});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = isActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: (isDark ? Colors.white : Colors.black).withOpacity(.04)),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: isDark ? Colors.white : DhakkerColors.lightText, fontWeight: FontWeight.w900, fontSize: 13.8)), subtitle])),
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
  const _LatestPanel({required this.title, required this.icon, required this.query, required this.itemBuilder});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: isDark ? DhakkerColors.card : DhakkerColors.lightCard, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Row(children: [Icon(icon, color: isDark ? DhakkerColors.gold : DhakkerColors.gold2, size: 20), const SizedBox(width: 10), Text(title, style: TextStyle(color: isDark ? Colors.white : DhakkerColors.lightText, fontWeight: FontWeight.w900, fontSize: 14.5))]),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              return Column(children: docs.map((d) => itemBuilder(d.data())).toList());
            },
          ),
        ],
      ),
    );
  }
}