import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhakker/Screens/Components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // حزمة الاهتزاز الحسّي بالملي
import '../../../generated/l10n.dart';
import '../../../theme/dhakker_theme.dart';
import 'admin_zone_add_screen.dart';
import 'admin_zone_details_screen.dart';
import 'admin_zone_edit_screen.dart';

class AdminZonesListScreen extends StatefulWidget {
  const AdminZonesListScreen({super.key});

  @override
  State<AdminZonesListScreen> createState() => _AdminZonesListScreenState();
}

class _AdminZonesListScreenState extends State<AdminZonesListScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _search = '';
  String _selectedType = 'all';
  String _selectedStatus = 'all';

  // متغير تحكم لحركة انضغاط الزر العائم FAB
  double _fabScale = 1.0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    final query = FirebaseFirestore.instance
        .collection('zones')
        .orderBy('updatedAt', descending: true);

    // الـ Scaffold الأساسي المحيط لحل مشكلة الخطوط الصفراء تماماً من الواجهة
    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: GestureDetector(
        onTapDown: (_) => setState(() => _fabScale = 0.94),
        onTapUp: (_) {
          setState(() => _fabScale = 1.0);
          HapticFeedback.lightImpact();
          goToScreen(context: context, screen: const AdminZoneAddScreen());
        },
        onTapCancel: () => setState(() => _fabScale = 1.0),
        child: AnimatedScale(
          scale: _fabScale,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: FloatingActionButton.extended(
            backgroundColor: accent,
            foregroundColor: isDark ? DhakkerColors.bg : Colors.white,
            onPressed:
                null, // معطل لأن الـ GestureDetector يتعامل مع اللمس والأنميشن
            icon: const Icon(Icons.add_rounded),
            label: Text(
              s.adminZonesAddZone,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top:
            true, // تفعيل التغطية الآمنة لمنع تداخل النصوص مع شريط الحالات العلوية
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics:
                    const BouncingScrollPhysics(), // فيزياء ارتداد سلسة ومرنة ومطاطية للسحب
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionTitle(title: s.adminZonesTitle),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border(
                          right: BorderSide(
                            color: accent.withOpacity(.55),
                            width: 3,
                          ),
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
                          TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _search = value.trim().toLowerCase();
                              });
                            },
                            style: TextStyle(
                              color: text,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              hintText: s.adminZonesSearchHint,
                              hintStyle: TextStyle(
                                color: muted.withOpacity(.9),
                                fontWeight: FontWeight.w700,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: muted,
                              ),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _search = '';
                                        });
                                      },
                                      icon: Icon(
                                        Icons.close_rounded,
                                        color: muted,
                                      ),
                                    ),
                              filled: true,
                              fillColor: (isDark ? Colors.white : Colors.black)
                                  .withOpacity(.04),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withOpacity(.08),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withOpacity(.08),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: accent.withOpacity(.75),
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _FilterDropdown(
                                  label: s.adminZonesFilterType,
                                  value: _selectedType,
                                  items: [
                                    _FilterItem(
                                      value: 'all',
                                      label: s.adminZonesFilterAllTypes,
                                    ),
                                    _FilterItem(
                                      value: 'circle',
                                      label: s.adminZonesTypeCircle,
                                    ),
                                    _FilterItem(
                                      value: 'polygon',
                                      label: s.adminZonesTypePolygon,
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedType = value ?? 'all';
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _FilterDropdown(
                                  label: s.adminZonesFilterStatus,
                                  value: _selectedStatus,
                                  items: [
                                    _FilterItem(
                                      value: 'all',
                                      label: s.adminZonesFilterAllStatuses,
                                    ),
                                    _FilterItem(
                                      value: 'active',
                                      label: s.adminZonesStatusActive,
                                    ),
                                    _FilterItem(
                                      value: 'inactive',
                                      label: s.adminZonesStatusInactive,
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedStatus = value ?? 'all';
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: query.snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Column(
                            children: [
                              _ZoneSkeletonCard(),
                              _ZoneSkeletonCard(),
                              _ZoneSkeletonCard(),
                            ],
                          );
                        }

                        if (snap.hasError) {
                          return _StateCard(
                            icon: Icons.error_outline_rounded,
                            title: s.adminZonesLoadErrorTitle,
                            subtitle: s.adminZonesLoadErrorMessage,
                          );
                        }

                        final docs = snap.data?.docs ?? const [];
                        final filtered = docs.where(_matchesFilters).toList();

                        if (filtered.isEmpty) {
                          return _StateCard(
                            icon: Icons.location_off_rounded,
                            title: s.adminZonesEmptyTitle,
                            subtitle: s.adminZonesEmptyMessage,
                          );
                        }

                        return Column(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  '${filtered.length} ${s.adminZonesResultsLabel}',
                                  style: TextStyle(
                                    color: muted.withOpacity(.95),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.8,
                                  ),
                                ),
                              ),
                            ),
                            ...filtered.map((doc) {
                              final data = doc.data();
                              return _ZoneCard(
                                docId: doc.id,
                                data: data,
                                onView: () {
                                  goToScreen(
                                      context: context,
                                      screen: AdminZoneDetailsScreen(
                                          zoneId: doc.id));
                                },
                                onEdit: () {
                                  goToScreen(
                                      context: context,
                                      screen:
                                          AdminZoneEditScreen(zoneId: doc.id));
                                },
                                onDelete: () async {
                                  await _deleteZone(context, doc.id, data);
                                },
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesFilters(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final nameAr = (data['nameAr'] ?? '').toString().toLowerCase().trim();
    final nameEn = (data['nameEn'] ?? '').toString().toLowerCase().trim();
    final type = (data['type'] ?? '').toString().toLowerCase().trim();
    final isActive = data['isActive'] == true;

    final matchesSearch =
        _search.isEmpty || nameAr.contains(_search) || nameEn.contains(_search);

    final matchesType =
        _selectedType == 'all' || type == _selectedType.toLowerCase();

    final matchesStatus = _selectedStatus == 'all' ||
        (_selectedStatus == 'active' && isActive) ||
        (_selectedStatus == 'inactive' && !isActive);

    return matchesSearch && matchesType && matchesStatus;
  }

  Future<void> _deleteZone(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final s = S.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';

    final zoneName = isAr
        ? (data['nameAr'] ?? data['nameEn'] ?? '').toString().trim()
        : (data['nameEn'] ?? data['nameAr'] ?? '').toString().trim();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
        final text = isDark ? Colors.white : DhakkerColors.lightText;
        final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

        return AlertDialog(
          backgroundColor: card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
                18), // التعديل هنا: BorderRadius بدلاً من المكرر القديم
          ),
          title: Text(
            s.adminZonesDeleteTitle,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            '${s.adminZonesDeleteMessage}\n\n${zoneName.isEmpty ? '—' : zoneName}',
            style: TextStyle(
              color: muted,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                s.cancel,
                style: TextStyle(fontWeight: FontWeight.w800, color: muted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                s.delete,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('zones').doc(docId).delete();

      // نفحص صلاحية نفس الـ context المستخدم بعد الـ await (لا mounted العام).
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.adminZonesDeleteSuccess),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.adminZonesDeleteError),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

class _FilterItem {
  final String value;
  final String label;

  _FilterItem({
    required this.value,
    required this.label,
  });
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<_FilterItem> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: muted.withOpacity(.95),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          dropdownColor: isDark ? DhakkerColors.card : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: muted),
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: (isDark ? Colors.white : Colors.black).withOpacity(.04),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: (isDark ? Colors.white : Colors.black).withOpacity(.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: (isDark ? Colors.white : Colors.black).withOpacity(.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: (isDark ? Colors.white : Colors.black).withOpacity(.12),
              ),
            ),
          ),
          items: items
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e.value,
                  child: Text(
                    e.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ZoneCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ZoneCard({
    required this.docId,
    required this.data,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';

    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;

    final name = isAr
        ? (data['nameAr'] ?? data['nameEn'] ?? '').toString().trim()
        : (data['nameEn'] ?? data['nameAr'] ?? '').toString().trim();

    final typeRaw = (data['type'] ?? '').toString().trim().toLowerCase();
    final isActive = data['isActive'] == true;
    final priority = data['priority'];

    final typeLabel = typeRaw == 'circle'
        ? s.adminZonesTypeCircle
        : typeRaw == 'polygon'
            ? s.adminZonesTypePolygon
            : '—';

    final statusLabel =
        isActive ? s.adminZonesStatusActive : s.adminZonesStatusInactive;

    final typeColor =
        typeRaw == 'circle' ? const Color(0xFF2563EB) : const Color(0xFF7C3AED);

    final statusColor =
        isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .28 : .06),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: typeColor.withOpacity(.18),
                  ),
                ),
                child: Icon(
                  typeRaw == 'polygon'
                      ? Icons.polyline_rounded
                      : Icons.circle_outlined,
                  color: typeColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? '—' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: text,
                        fontSize: 14.6,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniBadge(
                          label: typeLabel,
                          color: typeColor,
                        ),
                        _MiniBadge(
                          label: statusLabel,
                          color: statusColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: isDark ? DhakkerColors.card : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (value) {
                  if (value == 'view') onView();
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view',
                    child: Text(
                      s.view,
                      style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(
                      s.edit,
                      style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      s.delete,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: (isDark ? Colors.white : Colors.black).withOpacity(.04),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withOpacity(.05),
              ),
            ),
            child: Column(
              children: [
                _InfoRow(
                  label: s.adminZonesPriorityLabel,
                  value: priority == null ? '—' : priority.toString(),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: s.adminZonesDocIdLabel,
                  value: docId,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.visibility_rounded,
                  label: s.view,
                  onTap: onView,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.edit_rounded,
                  label: s.edit,
                  onTap: onEdit,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: s.delete,
                  isDanger: true,
                  onTap: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: muted.withOpacity(.95),
              fontSize: 12.3,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: text,
              fontSize: 12.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// تعديل أزرار الكروت السفلية لتطبيق فيزياء الانضغاط المطاطي والاهتزاز الحسّي
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isDanger;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  double _btnScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = widget.isDanger
        ? const Color(0xFFDC2626)
        : (isDark ? DhakkerColors.gold : DhakkerColors.gold2);

    return GestureDetector(
      onTapDown: (_) => setState(() => _btnScale = 0.94),
      onTapUp: (_) {
        setState(() => _btnScale = 1.0);
        HapticFeedback.lightImpact(); // نبضة حسية تفاعلية مع النقر
        widget.onTap();
      },
      onTapCancel: () => setState(() => _btnScale = 1.0),
      child: AnimatedScale(
        scale: _btnScale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: baseColor.withOpacity(.10),
            border: Border.all(color: baseColor.withOpacity(.18)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 18, color: baseColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: baseColor,
                    fontSize: 12.2,
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

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .28 : .06),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: accent.withOpacity(.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneSkeletonCard extends StatelessWidget {
  const _ZoneSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base =
        (isDark ? Colors.white : Colors.black).withOpacity(isDark ? .06 : .05);
    final line =
        (isDark ? Colors.white : Colors.black).withOpacity(isDark ? .10 : .08);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: line,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 130,
                      decoration: BoxDecoration(
                        color: line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: line.withOpacity(.7),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                          color: line,
                          borderRadius: BorderRadius.circular(14)))),
              const SizedBox(width: 10),
              Expanded(
                  child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                          color: line,
                          borderRadius: BorderRadius.circular(14)))),
              const SizedBox(width: 10),
              Expanded(
                  child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                          color: line,
                          borderRadius: BorderRadius.circular(14)))),
            ],
          ),
        ],
      ),
    );
  }
}
