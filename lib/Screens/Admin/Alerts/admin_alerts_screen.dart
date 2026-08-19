import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../theme/dhakker_theme.dart';

/// شاشة الأدمن لإرسال تنبيهات للحجّاج وإدارتها (حذف).
/// التنبيه يظهر لكل الحجّاج أعلى الشاشة الرئيسية، ويسحبه الحاج يميناً ليُخفيه عنده.
class AdminAlertsScreen extends StatefulWidget {
  const AdminAlertsScreen({super.key});

  @override
  State<AdminAlertsScreen> createState() => _AdminAlertsScreenState();
}

class _AdminAlertsScreenState extends State<AdminAlertsScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;
  String _level = 'warning'; // info | warning | critical

  // منطقة البثّ المختارة: null = كل المناطق (تنبيه عام).
  String? _zoneId;
  String _zoneName = '';
  List<({String id, String name})> _zones = [];

  final _alerts = FirebaseFirestore.instance.collection('alerts');

  // ألوان وتسميات مستويات الخطورة.
  static const Map<String, ({String label, Color color, IconData icon})>
      _levels = {
    'info': (label: 'عادي', color: Color(0xFF3B82F6), icon: Icons.info_rounded),
    'warning': (
      label: 'تحذير',
      color: Color(0xFFE0A23C),
      icon: Icons.warning_amber_rounded
    ),
    'critical': (
      label: 'خطر',
      color: Color(0xFFE0463F),
      icon: Icons.report_rounded
    ),
  };

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('zones')
          .where('isActive', isEqualTo: true)
          .get();
      final list = snap.docs.map((d) {
        final data = d.data();
        final name = (data['nameAr'] ?? data['nameEn'] ?? d.id).toString();
        final id = (data['zoneId'] ?? d.id).toString();
        return (id: id, name: name);
      }).toList();
      if (mounted) setState(() => _zones = list);
    } catch (_) {/* تبقى القائمة فارغة = بثّ عام فقط */}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _controller.text.trim();
    if (msg.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _alerts.add({
        'message': msg,
        'level': _level,
        'zoneId': _zoneId ?? '',
        'zoneName': _zoneId == null ? '' : _zoneName,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _controller.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Color(0xFF2E7D32),
          content: Text('تم إرسال التنبيه للحجّاج'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Color(0xFFCC4B47),
          content: Text('تعذّر إرسال التنبيه، حاول مجدداً'),
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _alerts.doc(id).delete();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final textColor = isDark ? Colors.white : DhakkerColors.lightText;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: const Text('تنبيهات الحجّاج',
              style: TextStyle(
                  color: DhakkerColors.gold, fontWeight: FontWeight.w900)),
          iconTheme: const IconThemeData(color: DhakkerColors.gold),
        ),
        body: Column(
          children: [
            // --- صندوق كتابة تنبيه جديد ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: DhakkerColors.gold.withOpacity(.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _controller,
                      maxLines: 3,
                      minLines: 1,
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(
                        hintText:
                            'اكتب التنبيه... مثل: ازدحام في المسعى، استخدموا المسار البديل',
                      ),
                    ),
                    const SizedBox(height: 12),
                    // اختيار مستوى الخطورة.
                    Row(
                      children: _levels.entries.map((e) {
                        final sel = e.key == _level;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _level = e.key),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: sel
                                    ? e.value.color.withOpacity(.16)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sel ? e.value.color : Colors.white12,
                                  width: sel ? 1.4 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(e.value.icon,
                                      size: 16,
                                      color: sel
                                          ? e.value.color
                                          : DhakkerColors.muted),
                                  const SizedBox(width: 5),
                                  Text(e.value.label,
                                      style: TextStyle(
                                        color: sel
                                            ? e.value.color
                                            : DhakkerColors.muted,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    // اختيار منطقة البثّ (اختياري) — افتراضيًا لكل المناطق.
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: DhakkerColors.gold.withOpacity(.18)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.place_rounded,
                              color: DhakkerColors.gold, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _zoneId,
                                isExpanded: true,
                                dropdownColor: card,
                                hint: Text('كل المناطق (بثّ عام)',
                                    style: TextStyle(color: textColor)),
                                icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: DhakkerColors.gold),
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w700),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('كل المناطق (بثّ عام)',
                                        style: TextStyle(color: textColor)),
                                  ),
                                  ..._zones.map((z) =>
                                      DropdownMenuItem<String?>(
                                        value: z.id,
                                        child: Text(z.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: textColor)),
                                      )),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _zoneId = val;
                                    _zoneName = val == null
                                        ? ''
                                        : _zones
                                            .firstWhere((z) => z.id == val)
                                            .name;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DhakkerColors.gold,
                          foregroundColor: DhakkerColors.darkText,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: DhakkerColors.darkText),
                              )
                            : const Icon(Icons.campaign_rounded),
                        label: Text(
                            _sending ? 'جارٍ الإرسال...' : 'إرسال التنبيه',
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 10, 18, 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('التنبيهات الحالية',
                    style: TextStyle(
                        color: DhakkerColors.muted,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            // --- قائمة التنبيهات الحالية ---
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _alerts.where('isActive', isEqualTo: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: DhakkerColors.gold));
                  }
                  final docs = snapshot.data!.docs.toList()
                    ..sort((a, b) {
                      final ta = a.data()['createdAt'];
                      final tb = b.data()['createdAt'];
                      if (ta is Timestamp && tb is Timestamp)
                        return tb.compareTo(ta);
                      return 0;
                    });
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('لا توجد تنبيهات حالياً',
                          style: TextStyle(color: DhakkerColors.muted)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final d = docs[i];
                      final msg = (d.data()['message'] ?? '').toString();
                      final zoneName = (d.data()['zoneName'] ?? '').toString();
                      final lvl = _levels[
                              (d.data()['level'] ?? 'warning').toString()] ??
                          _levels['warning']!;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: lvl.color.withOpacity(.35)),
                        ),
                        child: Row(
                          children: [
                            Icon(lvl.icon, color: lvl.color, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(msg,
                                      style: TextStyle(
                                          color: textColor, height: 1.5)),
                                  if (zoneName.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.place_rounded,
                                            color: DhakkerColors.gold,
                                            size: 13),
                                        const SizedBox(width: 4),
                                        Text('يخصّ: $zoneName',
                                            style: const TextStyle(
                                                color: DhakkerColors.gold,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800)),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _delete(d.id),
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: Color(0xFFE0463F)),
                              tooltip: 'حذف',
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
