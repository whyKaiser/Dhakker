import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/dhakker_theme.dart';

/// شاشة مراقبة نداءات الاستغاثة (SOS) للأدمن.
/// تعرض كل نداء وصل من مجموعة `sos_requests` بشكل لحظي:
/// الاسم، الوقت، الحالة، زر يفتح موقع المستخدم على الخريطة، وزر "تم الحل".
class AdminSosMonitorScreen extends StatelessWidget {
  const AdminSosMonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final textColor = isDark ? Colors.white : DhakkerColors.lightText;

    final query = FirebaseFirestore.instance
        .collection('sos_requests')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: textColor,
        title: Text(
          isAr ? 'مراقبة نداءات SOS' : 'SOS Monitor',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: isDark ? DhakkerColors.gold : DhakkerColors.gold2,
                ),
              );
            }

            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) {
              return _EmptyState(isAr: isAr, isDark: isDark);
            }

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final d = docs[i];
                return _SosCard(
                  docId: d.id,
                  data: d.data(),
                  isAr: isAr,
                  isDark: isDark,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

String _timeAgo(DateTime? dt, bool isAr) {
  if (dt == null) return isAr ? 'الآن' : 'just now';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return isAr ? 'الآن' : 'just now';
  if (diff.inMinutes < 60) {
    return isAr ? 'قبل ${diff.inMinutes} دقيقة' : '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return isAr ? 'قبل ${diff.inHours} ساعة' : '${diff.inHours}h ago';
  }
  return isAr ? 'قبل ${diff.inDays} يوم' : '${diff.inDays}d ago';
}

Future<void> _openMap(BuildContext context, String url, bool isAr) async {
  if (url.trim().isEmpty) return;
  final uri = Uri.parse(url.trim());
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  } catch (_) {}
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isAr ? 'تعذّر فتح الخريطة' : 'Could not open map')),
    );
  }
}

Future<void> _resolve(BuildContext context, String docId, bool isAr) async {
  try {
    await FirebaseFirestore.instance.collection('sos_requests').doc(docId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'تعذّر تحديث الحالة' : 'Update failed')),
      );
    }
  }
}

class _SosCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isAr;
  final bool isDark;

  const _SosCard({
    required this.docId,
    required this.data,
    required this.isAr,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final textColor = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    final name = (data['name'] ?? '').toString().trim();
    final displayName =
        name.isEmpty ? (isAr ? 'حاج غير معروف' : 'Unknown pilgrim') : name;

    final status = (data['status'] ?? 'active').toString();
    final isResolved = status == 'resolved';

    final lat = data['lat'];
    final lng = data['lng'];
    final hasLoc = lat != null && lng != null;
    final mapUrl = (data['mapUrl'] ??
            (hasLoc ? 'https://maps.google.com/?q=$lat,$lng' : ''))
        .toString();

    DateTime? dt;
    final ts = data['timestamp'];
    if (ts is Timestamp) dt = ts.toDate();

    final statusColor =
        isResolved ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          right: BorderSide(color: statusColor.withOpacity(.8), width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .30 : .07),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isResolved
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: statusColor,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _timeAgo(dt, isAr),
                      style: TextStyle(
                        color: muted.withOpacity(.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(isResolved: isResolved, isAr: isAr),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  label: isAr ? 'فتح الموقع' : 'Open location',
                  icon: Icons.location_on_rounded,
                  color: isDark ? DhakkerColors.gold : DhakkerColors.gold2,
                  filled: false,
                  onTap: hasLoc ? () => _openMap(context, mapUrl, isAr) : null,
                ),
              ),
              if (!isResolved) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    label: isAr ? 'تم الحل' : 'Resolve',
                    icon: Icons.check_rounded,
                    color: const Color(0xFF22C55E),
                    filled: true,
                    onTap: () => _resolve(context, docId, isAr),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isResolved;
  final bool isAr;
  const _StatusBadge({required this.isResolved, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final color =
        isResolved ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final label = isResolved
        ? (isAr ? 'محلول' : 'Resolved')
        : (isAr ? 'نشط' : 'Active');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11.5),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: Material(
        color: filled ? color : color.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: filled ? Colors.white : color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: filled ? Colors.white : color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isAr;
  final bool isDark;
  const _EmptyState({required this.isAr, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 64, color: muted.withOpacity(.5)),
          const SizedBox(height: 14),
          Text(
            isAr ? 'لا توجد نداءات استغاثة' : 'No SOS alerts',
            style: TextStyle(color: muted, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            isAr ? 'كل شيء تمام والحمدلله' : 'All clear',
            style: TextStyle(color: muted.withOpacity(.7), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
