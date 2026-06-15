import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../shared/network/local/cash_helper.dart';

/// شريط تنبيهات الحجّاج: يعرض التنبيهات النشطة التي يرسلها الأدمن من Firestore.
/// الحاج يسحب التنبيه يميناً ليُخفيه **عنده فقط** (يُحفظ محلياً)، دون حذفه للبقية.
class AlertsBanner extends StatefulWidget {
  const AlertsBanner({super.key});

  @override
  State<AlertsBanner> createState() => _AlertsBannerState();
}

class _AlertsBannerState extends State<AlertsBanner> {
  static const String _dismissKey = 'dismissed_alerts';
  Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    final raw = CashHelper.getCash(key: _dismissKey);
    if (raw is String && raw.isNotEmpty) {
      _dismissed = raw.split(',').where((e) => e.isNotEmpty).toSet();
    }
  }

  Future<void> _dismiss(String id) async {
    _dismissed.add(id);
    await CashHelper.saveCash(key: _dismissKey, value: _dismissed.join(','));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        // نستبعد ما أخفاه الحاج محلياً، ونرتّب الأحدث أولاً (بدون فهرس مركّب).
        final docs = snapshot.data!.docs
            .where((d) => !_dismissed.contains(d.id))
            .toList()
          ..sort((a, b) {
            final ta = a.data()['createdAt'];
            final tb = b.data()['createdAt'];
            if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
            return 0;
          });

        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          children: docs.map((d) {
            final msg = (d.data()['message'] ?? '').toString();
            if (msg.trim().isEmpty) return const SizedBox.shrink();
            final level = (d.data()['level'] ?? 'warning').toString();
            final zoneName = (d.data()['zoneName'] ?? '').toString();
            return Dismissible(
              key: ValueKey(d.id),
              direction: DismissDirection.horizontal,
              onDismissed: (_) => _dismiss(d.id),
              child: _AlertCard(
                  message: msg, level: level, isAr: isAr, zoneName: zoneName),
            );
          }).toList(),
        );
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String message;
  final String level;
  final bool isAr;
  final String zoneName;
  const _AlertCard({
    required this.message,
    required this.level,
    required this.isAr,
    this.zoneName = '',
  });

  // لون وأيقونة حسب مستوى الخطورة.
  ({Color color, IconData icon}) get _style {
    switch (level) {
      case 'critical':
        return (color: const Color(0xFFE0463F), icon: Icons.report_rounded);
      case 'info':
        return (color: const Color(0xFF3B82F6), icon: Icons.info_rounded);
      default:
        return (color: const Color(0xFFE0A23C), icon: Icons.warning_amber_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    final color = s.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.55), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(s.icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (zoneName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.place_rounded, color: color, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        isAr ? 'يخصّ منطقة: $zoneName' : 'Zone: $zoneName',
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  isAr ? 'اسحب يميناً لإخفاء التنبيه' : 'Swipe to dismiss',
                  style: TextStyle(color: color.withOpacity(.85), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
