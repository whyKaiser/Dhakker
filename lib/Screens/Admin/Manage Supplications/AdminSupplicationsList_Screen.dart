import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // استدعاء حزمة الاهتزاز الحسّي التفاعلي بالملي
import '../../../generated/l10n.dart';
import '../../../theme/dhakker_theme.dart';
import 'admin_supplication_add_screen.dart';
import 'admin_supplication_details_screen.dart';
import 'admin_supplication_edit_screen.dart';

class AdminSupplicationsListScreen extends StatefulWidget {
  final String? initialZoneId;

  const AdminSupplicationsListScreen({
    super.key,
    this.initialZoneId,
  });

  @override
  State<AdminSupplicationsListScreen> createState() =>
      _AdminSupplicationsListScreenState();
}

class _AdminSupplicationsListScreenState
    extends State<AdminSupplicationsListScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _search = '';
  String _selectedZoneId = 'all';
  String _selectedAudioMode = 'all';
  String _selectedStatus = 'all';

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _zoneDocs = [];
  Map<String, String> _zoneNameById = {};
  bool _zonesLoading = true;

  // متغير تحكم لحركة انضغاط الزر العائم FAB
  double _fabScale = 1.0;

  @override
  void initState() {
    super.initState();

    if (widget.initialZoneId != null && widget.initialZoneId!.trim().isNotEmpty) {
      _selectedZoneId = widget.initialZoneId!.trim();
    }

    _loadZones();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadZones() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('zones').get();

      final zoneDocs = snap.docs;
      final zoneMap = <String, String>{};

      final langCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      final isAr = langCode == 'ar';

      for (final doc in zoneDocs) {
        final data = doc.data();
        final name = isAr
            ? (data['nameAr'] ?? data['nameEn'] ?? '').toString().trim()
            : (data['nameEn'] ?? data['nameAr'] ?? '').toString().trim();

        zoneMap[doc.id] = name.isEmpty ? doc.id : name;
      }

      if (!mounted) return;
      setState(() {
        _zoneDocs = zoneDocs;
        _zoneNameById = zoneMap;
        _zonesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _zoneDocs = [];
        _zoneNameById = {};
        _zonesLoading = false;
      });
    }
  }

  bool _matchesFilters(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final titleMap = data['title'];
    final titleAr = titleMap is Map
        ? (titleMap['ar'] ?? '').toString().toLowerCase().trim()
        : '';
    final titleEn = titleMap is Map
        ? (titleMap['en'] ?? '').toString().toLowerCase().trim()
        : '';

    final zoneId = (data['zoneId'] ?? '').toString().trim();
    final audioMode = (data['audioMode'] ?? '').toString().toLowerCase().trim();
    final isActive = data['isActive'] == true;

    final matchesSearch = _search.isEmpty ||
        titleAr.contains(_search) ||
        titleEn.contains(_search);

    final matchesZone = _selectedZoneId == 'all' || zoneId == _selectedZoneId;

    final matchesAudioMode =
        _selectedAudioMode == 'all' || audioMode == _selectedAudioMode;

    final matchesStatus = _selectedStatus == 'all' ||
        (_selectedStatus == 'active' && isActive) ||
        (_selectedStatus == 'inactive' && !isActive);

    return matchesSearch && matchesZone && matchesAudioMode && matchesStatus;
  }

  Future<void> _deleteSupplication(BuildContext context, String docId) async {
    final s = S.of(context);

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
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            s.adminSupplicationsDeleteTitle,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            s.adminSupplicationsDeleteMessage,
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
                style: TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w800,
                ),
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
      await FirebaseFirestore.instance
          .collection('supplications')
          .doc(docId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.adminSupplicationsDeleteSuccess),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.adminSupplicationsDeleteError),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    final supplicationsQuery = FirebaseFirestore.instance
        .collection('supplications')
        .orderBy('updatedAt', descending: true);

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: GestureDetector(
        onTapDown: (_) => setState(() => _fabScale = 0.94),
        onTapUp: (_) {
          setState(() => _fabScale = 1.0);
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminSupplicationAddScreen(
                initialZoneId: _selectedZoneId == 'all' ? null : _selectedZoneId,
              ),
            ),
          );
        },
        onTapCancel: () => setState(() => _fabScale = 1.0),
        child: AnimatedScale(
          scale: _fabScale,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: FloatingActionButton.extended(
            backgroundColor: accent,
            foregroundColor: isDark ? DhakkerColors.bg : Colors.white,
            onPressed: null, // معطل تفادياً للتداخل مع الـ GestureDetector الحركي
            icon: const Icon(Icons.add_rounded),
            label: Text(
              s.adminSupplicationsAddButton,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: true, // تفعيل الحماية من الحواف العلوية لشريط الحالات
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(), // فيزياء ارتداد مطاطية ناعمة لتمطيط القوائم عند السحب
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionTitle(title: s.adminSupplicationsTitle),
                    const SizedBox(height: 12),
                    _FilterPanel(
                      searchController: _searchController,
                      zoneDocs: _zoneDocs,
                      selectedZoneId: _selectedZoneId,
                      selectedAudioMode: _selectedAudioMode,
                      selectedStatus: _selectedStatus,
                      onSearchChanged: (value) {
                        setState(() {
                          _search = value.trim().toLowerCase();
                        });
                      },
                      onClearSearch: () {
                        _searchController.clear();
                        setState(() {
                          _search = '';
                        });
                      },
                      onZoneChanged: (value) {
                        setState(() {
                          _selectedZoneId = value ?? 'all';
                        });
                      },
                      onAudioModeChanged: (value) {
                        setState(() {
                          _selectedAudioMode = value ?? 'all';
                        });
                      },
                      onStatusChanged: (value) {
                        setState(() {
                          _selectedStatus = value ?? 'all';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_zonesLoading)
                      const Column(
                        children: [
                          _SupplicationSkeletonCard(),
                          _SupplicationSkeletonCard(),
                          _SupplicationSkeletonCard(),
                        ],
                      )
                    else
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: supplicationsQuery.snapshots(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Column(
                              children: [
                                _SupplicationSkeletonCard(),
                                _SupplicationSkeletonCard(),
                                _SupplicationSkeletonCard(),
                              ],
                            );
                          }

                          if (snap.hasError) {
                            return _StateCard(
                              icon: Icons.error_outline_rounded,
                              title: s.adminSupplicationsLoadErrorTitle,
                              subtitle: s.adminSupplicationsLoadErrorMessage,
                            );
                          }

                          final docs = snap.data?.docs ?? const [];
                          final filtered = docs.where((doc) => _matchesFilters(doc)).toList();

                          if (filtered.isEmpty) {
                            return _StateCard(
                              icon: Icons.menu_book_outlined,
                              title: s.adminSupplicationsEmptyTitle,
                              subtitle: s.adminSupplicationsEmptyMessage,
                            );
                          }

                          return Column(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    '${filtered.length} ${s.adminSupplicationsResultsLabel}',
                                    style: TextStyle(
                                      color: muted.withOpacity(.95),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.8,
                                    ),
                                  ),
                                ),
                              ),
                              // تطبيق نظام التحريك الصعودي المتتابع والناعم لكل عناصر القائمة بالملي
                              ...List.generate(filtered.length, (index) {
                                final doc = filtered[index];
                                final data = doc.data();
                                final double start = (index * 0.03).clamp(0.0, 1.0);
                                final double end = (start + 0.30).clamp(0.0, 1.0);

                                return TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Interval(start, end, curve: Curves.easeOutCubic),
                                  builder: (context, value, child) {
                                    return Transform.translate(
                                      offset: Offset(0, 24 * (1.0 - value)),
                                      child: Opacity(
                                        opacity: value,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _SupplicationCard(
                                    docId: doc.id,
                                    data: data,
                                    zoneNameById: _zoneNameById,
                                    onView: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AdminSupplicationDetailsScreen(
                                            supplicationId: doc.id,
                                          ),
                                        ),
                                      );
                                    },
                                    onEdit: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AdminSupplicationEditScreen(
                                            supplicationId: doc.id,
                                          ),
                                        ),
                                      );
                                    },
                                    onDelete: () async {
                                      await _deleteSupplication(context, doc.id);
                                    },
                                  ),
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
}

class _FilterPanel extends StatelessWidget {
  final TextEditingController searchController;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> zoneDocs;
  final String selectedZoneId;
  final String selectedAudioMode;
  final String selectedStatus;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String?> onZoneChanged;
  final ValueChanged<String?> onAudioModeChanged;
  final ValueChanged<String?> onStatusChanged;

  const _FilterPanel({
    required this.searchController,
    required this.zoneDocs,
    required this.selectedZoneId,
    required this.selectedAudioMode,
    required this.selectedStatus,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onZoneChanged,
    required this.onAudioModeChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    return Container(
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
            controller: searchController,
            onChanged: onSearchChanged,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: s.adminSupplicationsSearchHint,
              hintStyle: TextStyle(
                color: muted.withOpacity(.9),
                fontWeight: FontWeight.w700,
              ),
              prefixIcon: Icon(Icons.search_rounded, color: muted),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                onPressed: onClearSearch,
                icon: Icon(Icons.close_rounded, color: muted),
              ),
              filled: true,
              fillColor: (isDark ? Colors.white : Colors.black).withOpacity(.04),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
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
                  label: s.adminSupplicationsFilterZone,
                  value: selectedZoneId,
                  items: [
                    _FilterItem(
                      value: 'all',
                      label: s.adminSupplicationsAllZones,
                    ),
                    ...zoneDocs.map((doc) {
                      final data = doc.data();
                      final langCode = Localizations.localeOf(context).languageCode;
                      final isAr = langCode == 'ar';

                      final name = isAr
                          ? (data['nameAr'] ?? data['nameEn'] ?? '')
                          .toString()
                          .trim()
                          : (data['nameEn'] ?? data['nameAr'] ?? '')
                          .toString()
                          .trim();

                      return _FilterItem(
                        value: doc.id,
                        label: name.isEmpty ? doc.id : name,
                      );
                    }),
                  ],
                  onChanged: onZoneChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FilterDropdown(
                  label: s.adminSupplicationsFilterAudioMode,
                  value: selectedAudioMode,
                  items: [
                    _FilterItem(
                      value: 'all',
                      label: s.adminSupplicationsAllAudioModes,
                    ),
                    _FilterItem(
                      value: 'tts',
                      label: s.adminSupplicationsAudioTts,
                    ),
                    _FilterItem(
                      value: 'file',
                      label: s.adminSupplicationsAudioFile,
                    ),
                  ],
                  onChanged: onAudioModeChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FilterDropdown(
            label: s.adminSupplicationsFilterStatus,
            value: selectedStatus,
            items: [
              _FilterItem(
                value: 'all',
                label: s.adminSupplicationsAllStatuses,
              ),
              _FilterItem(
                value: 'active',
                label: s.adminSupplicationsStatusActive,
              ),
              _FilterItem(
                value: 'inactive',
                label: s.adminSupplicationsStatusInactive,
              ),
            ],
            onChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _SupplicationCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Map<String, String> zoneNameById;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplicationCard({
    required this.docId,
    required this.data,
    required this.zoneNameById,
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

    final titleMap = data['title'];
    final title = titleMap is Map
        ? (isAr
        ? (titleMap['ar'] ?? titleMap['en'] ?? '')
        : (titleMap['en'] ?? titleMap['ar'] ?? ''))
        .toString()
        .trim()
        : '';

    final zoneId = (data['zoneId'] ?? '').toString().trim();
    final zoneName = zoneId.isEmpty ? '—' : (zoneNameById[zoneId] ?? zoneId);

    final audioMode = (data['audioMode'] ?? '').toString().trim().toLowerCase();
    final isActive = data['isActive'] == true;

    final audioLabel = audioMode == 'tts'
        ? s.adminSupplicationsAudioTts
        : audioMode == 'file'
        ? s.adminSupplicationsAudioFile
        : '—';

    final statusLabel = isActive
        ? s.adminSupplicationsStatusActive
        : s.adminSupplicationsStatusInactive;

    final audioColor = audioMode == 'tts'
        ? const Color(0xFF2563EB)
        : const Color(0xFF7C3AED);

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
                  color: audioColor.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: audioColor.withOpacity(.18),
                  ),
                ),
                child: Icon(
                  audioMode == 'file'
                      ? Icons.audiotrack_rounded
                      : Icons.record_voice_over_rounded,
                  color: audioColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? '—' : title,
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
                          label: audioLabel,
                          color: audioColor,
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
                  label: s.adminSupplicationsZoneLabel,
                  value: zoneName,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: s.adminSupplicationsAudioModeLabel,
                  value: audioLabel,
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
    final langCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final isAr = langCode == 'ar';
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
          isExpanded: true, // يمنع طفح الاسم الطويل خارج الصف (RenderFlex overflow)
          dropdownColor: isDark ? DhakkerColors.card : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: muted),
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.w700,
            fontFamily: isAr ? 'AlamirReg' : 'AlamirReg',
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

// تعديل أزرار الكروت السفلية لتطبيق فيزياء الانضغاط المطاطي والاهتزاز الحسّي التفاعلي
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
        HapticFeedback.lightImpact(); // اهتزاز حسّي ناعم ومتناسق مع اللمس
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
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
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

class _SupplicationSkeletonCard extends StatelessWidget {
  const _SupplicationSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base =
    (isDark ? Colors.white : Colors.black).withOpacity(isDark ? .06 : .05);
    final line =
    (isDark ? Colors.white : Colors.black).withOpacity(isDark ? .10 : .08);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: line,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: line,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
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