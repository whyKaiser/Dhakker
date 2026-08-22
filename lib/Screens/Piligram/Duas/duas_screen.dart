import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../generated/l10n.dart';
import '../Home/models/supplication_model.dart';
import '../Home/models/zone_model.dart';
import '../Home/services/dua_playback_service.dart';
import 'services/dua_search_service.dart';
import 'widgets/content_kind_card.dart';
import 'services/voice_search_service.dart';
import 'widgets/voice_command_dialog.dart';
import 'manasik_guide.dart';
import 'hajj_schedule.dart';

class DuasScreen extends StatefulWidget {
  const DuasScreen({super.key});

  @override
  State<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends State<DuasScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  // تبويبا "الدليل": الأدعية (0) والمناسك (1).
  late final TabController _tabController;

  final DuaSearchService _searchService = const DuaSearchService();
  final VoiceSearchService _voiceSearchService = VoiceSearchService();
  final DuaPlaybackService _playbackService = DuaPlaybackService();

  bool _isLoading = true;
  bool _isPlaying = false;

  List<ZoneModel> _zones = [];
  List<DuaSearchItem> _allItems = [];
  List<DuaSearchItem> _filteredItems = [];

  String? _selectedZoneId;

  // أنميشن الدخول المتتابع لـ كروت الأدعية
  late AnimationController _listAnimationController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _playbackService.onPlayingStateChanged = (value) {
      if (!mounted) return;
      setState(() {
        _isPlaying = value;
      });
    };

    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _playbackService.dispose();
    _listAnimationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _playbackService.init();
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final zonesQuery = await FirebaseFirestore.instance
        .collection('zones')
        .where('isActive', isEqualTo: true)
        .get();

    // شاشة البحث تقرأ المجموعة كاملة، فتلزمها القيود الثلاثة نفسها التي
    // تلزم استعلامات المنطقة. بدونها يطابق الاستعلام سجلًا غير موثّق
    // فيفشل كاملًا بـ permission-denied — لا يعود بنتائج أقل.
    final duasQuery = await FirebaseFirestore.instance
        .collection('supplications')
        .where('isActive', isEqualTo: true)
        .where('verificationStatus', isEqualTo: 'verified')
        .where('revokedAt', isNull: true)
        .get();

    final zones = zonesQuery.docs.map(ZoneModel.fromFirestore).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final duas = duasQuery.docs.map(SupplicationModel.fromFirestore).toList();

    final zoneMap = <String, ZoneModel>{};
    for (final zone in zones) {
      zoneMap[zone.zoneId] = zone;
    }

    final items = duas
        .map((dua) => DuaSearchItem(dua: dua, zone: zoneMap[dua.zoneId]))
        .toList()
      ..sort((a, b) => (b.dua.usageCount).compareTo(a.dua.usageCount));

    _zones = zones;
    _allItems = items;
    _filteredItems = items;

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    _listAnimationController.forward(from: 0.0);
  }

  void _applyFilters() {
    final langCode = Localizations.localeOf(context).languageCode;
    final query = _searchController.text.trim();

    List<DuaSearchItem> items = _allItems;

    if (_selectedZoneId != null && _selectedZoneId!.isNotEmpty) {
      items = items.where((e) => e.dua.zoneId == _selectedZoneId).toList();
    }

    items = _searchService.search(
      items: items,
      query: query,
      langCode: langCode,
    );

    setState(() {
      _filteredItems = items;
    });

    _listAnimationController.forward(from: 0.0);
  }

  /// عنوان السجل المتلوّ الذي يحيل إليه الإرشاد — **عنوانه فقط**.
  ///
  /// لا تُقرأ من هنا نصوصٌ ولا تُنسخ: بطاقة المروة تدلّ على بطاقة ذكر الصفا
  /// ولا تحمل نصّه. فالنص الشرعيّ يبقىٰ في سجل واحد، ويُستمع إليه من زرّه هو.
  String? _relatedTitle(SupplicationModel dua, String langCode) {
    final target = _findRelated(dua);
    if (target == null) return null;
    final t = target.titleByLanguage(langCode).trim();
    return t.isEmpty ? null : t;
  }

  SupplicationModel? _findRelated(SupplicationModel dua) {
    // بلا دورٍ مصرَّح لا رابط. والدور الوحيد المعروف اليوم هو الإحالة إلىٰ
    // نصٍّ يُتلىٰ، فلا يُعرض «انظر: …» إلىٰ بطاقة إرشاد لا تُتلىٰ أصلًا.
    if (!dua.hasRecitationLink) return null;
    final ids = SupplicationModel.sanitizeRelatedIds(
        dua.relatedRecordIds, dua.duaId);
    for (final id in ids) {
      for (final item in _allItems) {
        if (item.dua.duaId == id && item.dua.canPlayManually) return item.dua;
      }
    }
    // إحالة لا نجد هدفها لا تُعرض أصلًا — سهمٌ إلىٰ لا شيء أسوأ من غيابه.
    return null;
  }

  /// ينقل الحاج إلىٰ البطاقة الأصلية. لا يشغّل شيئًا: الاستماع اختيارُه هو،
  /// من زرّ تلك البطاقة.
  void _openRelated(SupplicationModel dua, String langCode) {
    final target = _findRelated(dua);
    if (target == null) return;
    _searchController.text = target.titleByLanguage(langCode);
    _applyFilters();
  }

  Future<void> _playDua(SupplicationModel dua) async {
    // الحارس الأخير قبل النطق. الواجهة لا تعرض زر تشغيل لغير المتلوّ، لكن
    // البحث الصوتي يشغّل النتيجة الوحيدة دون مرور بزر — فلولا هذا الفحص
    // لنطق التطبيق أثرًا أو إرشادًا كأنه ذكر.
    //
    // المعيار هنا [canPlayManually] لا [isAutoPlayable]: منعُ القراءة على
    // الحاج بموقعه ليس منعًا له أن يقرأ. آية الصفا لا تُقرأ عليه لمجرد دخوله
    // المسعى، ويظل زرّها يعمل متى طلبها.
    if (!dua.canPlayManually) return;

    final langCode = Localizations.localeOf(context).languageCode;

    try {
      FirebaseFirestore.instance
          .collection('supplications')
          .doc(dua.duaId)
          .update({
        'usage_count': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint("Analytics Update Error: $e");
    }

    await _playbackService.play(
      dua: dua,
      langCode: langCode,
    );
  }

  Future<void> _stopPlayback() async {
    await _playbackService.stop();

    if (!mounted) return;
    setState(() {
      _isPlaying = false;
    });
  }

  Future<void> _startVoiceSearch() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }

    if (!mounted) return;

    if (!status.isGranted) {
      await _showMicDeniedDialog();
      return;
    }

    final langCode = Localizations.localeOf(context).languageCode;
    final localeId = langCode == 'ar' ? 'ar-SA' : 'en-US';

    final recognized = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VoiceCommandDialog(
        service: _voiceSearchService,
        localeId: localeId,
      ),
    );

    if (!mounted) return;

    final text = (recognized ?? '').trim();
    if (text.isEmpty) return;

    _searchController.text = text;
    _applyFilters();

    if (_filteredItems.length == 1) {
      await _playDua(_filteredItems.first.dua);
    }
  }

  Future<void> _showMicDeniedDialog() async {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF303030) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF121316);
    final muted = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF667085);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            s.duasMicPermissionTitle,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            s.duasMicPermissionMessage,
            style: TextStyle(
              color: muted,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                s.commonDone,
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = langCode == 'ar';

    final palette = _DuasPalette.fromBrightness(isDark);

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _DaleelHeader(
              palette: palette,
              controller: _tabController,
              isAr: isAr,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── تبويب الأدعية ──
                  RefreshIndicator(
                    color: palette.gold,
                    backgroundColor: palette.card,
                    onRefresh: _loadData,
                    child: ListView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                      children: [
                        Text(
                          s.duasSubtitle,
                          textAlign: isAr ? TextAlign.right : TextAlign.left,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SearchBar(
                          palette: palette,
                          controller: _searchController,
                          hint: s.duasSearchHint,
                          onChanged: (_) => _applyFilters(),
                          onMicTap: _startVoiceSearch,
                        ),
                    const SizedBox(height: 14),
                    _ZoneFilterBar(
                      palette: palette,
                      allLabel: s.duasAllZones,
                      zones: _zones,
                      selectedZoneId: _selectedZoneId,
                      langCode: langCode,
                      onChanged: (value) {
                        setState(() {
                          _selectedZoneId = value;
                        });
                        _applyFilters();
                      },
                    ),
                    const SizedBox(height: 18),
                    if (_isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: palette.gold,
                          ),
                        ),
                      )
                    else if (_filteredItems.isEmpty)
                      _EmptyDuasState(
                        palette: palette,
                        title: s.duasEmptyTitle,
                        message: s.duasEmptyMessage,
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        primary: false,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];

                          final double start = (index * 0.08).clamp(0.0, 1.0);
                          final double end = (start + 0.4).clamp(0.0, 1.0);

                          return AnimatedBuilder(
                            animation: _listAnimationController,
                            builder: (context, child) {
                              final animationCurve = CurvedAnimation(
                                parent: _listAnimationController,
                                curve: Interval(start, end, curve: Curves.easeOutCubic),
                              );

                              return Transform.translate(
                                offset: Offset(0, 36 * (1.0 - animationCurve.value)),
                                child: Opacity(
                                  opacity: animationCurve.value,
                                  child: child,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              // الإرشاد ليس دعاءً: يُعرض في بطاقة إرشادية
                              // منفصلة بلا زر تشغيل وبلا عنوان «دعاء».
                              // ثلاثة مسارات لا اثنان: الإرشاد بطاقته،
                              // والأثر المرويّ بطاقته بعزوه، وما عداهما
                              // نصّ يُتلىٰ بزر تشغيل. كان الأثر يسقط في
                              // المسار الأخير فيظهر بزر تشغيل.
                              child: item.dua.contentKind ==
                                      SupplicationContentKind.proceduralGuidance
                                  ? GuidanceCard(
                                      title: item.dua.titleByLanguage(langCode),
                                      body: item.dua.textByLanguage(langCode),
                                      attribution: item.dua.attribution,
                                      references: item.dua.sourceReferences,
                                      hasUnnamedFurtherReferences:
                                          item.dua.hasUnnamedFurtherReferences,
                                      isPropheticDirective: true,
                                      usageNoteAr: item.dua.usageNoteAr,
                                      relatedRecordTitle: _relatedTitle(
                                          item.dua, langCode),
                                      onOpenRelated: () => _openRelated(
                                          item.dua, langCode),
                                      cardColor: palette.card,
                                      textColor: palette.text,
                                    )
                                  : item.dua.contentKind ==
                                          SupplicationContentKind
                                              .contextualEvidence
                                      ? ContextualEvidenceCard(
                                          title: item.dua
                                              .titleByLanguage(langCode),
                                          body: item.dua
                                              .textByLanguage(langCode),
                                          attribution: item.dua.attribution,
                                          references:
                                              item.dua.sourceReferences,
                                          hasUnnamedFurtherReferences: item
                                              .dua.hasUnnamedFurtherReferences,
                                          cardColor: palette.card,
                                          textColor: palette.text,
                                        )
                                      : _DuaResultCard(
                                palette: palette,
                                title: item.dua.titleByLanguage(langCode),
                                text: item.dua.textByLanguage(langCode),
                                kind: item.dua.contentKind,
                                policy: item.dua.recitationPolicy,
                                usageNoteAr: item.dua.usageNoteAr,
                                zoneName: item.zone?.displayName(langCode) ?? s.duasUnknownZone,
                                buttonText: s.duasPlayButton,
                                onPlay: () async => await _playDua(item.dua),
                                onShare: () {
                                  Clipboard.setData(ClipboardData(text: item.dua.textByLanguage(langCode)));
                                  Fluttertoast.showToast(msg: 'تم نسخ الدعاء', backgroundColor: const Color(0xFFD4AF37), textColor: Colors.black);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
                  // ── تبويب المناسك ──
                  _ManasikTab(
                    palette: palette,
                    isAr: isAr,
                    langCode: langCode,
                  ),
                ],
              ),
            ),
            if (_isPlaying)
              _BottomPlaybackBar(
                palette: palette,
                text: s.homePlayingNow,
                stopText: s.homeStopPlayback,
                onStop: _stopPlayback,
              ),
          ],
        ),
      ),
    );
  }
}

class _DuasPalette {
  final Color bg;
  final Color card;
  final Color gold;
  final Color gold2;
  final Color muted;
  final Color text;
  final Color textSoft;
  final Color chipBg;
  final Color border;
  final Color shadow;

  const _DuasPalette({
    required this.bg,
    required this.card,
    required this.gold,
    required this.gold2,
    required this.muted,
    required this.text,
    required this.textSoft,
    required this.chipBg,
    required this.border,
    required this.shadow,
  });

  factory _DuasPalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _DuasPalette(
        bg: Color(0xFF0B0D10),
        card: Color(0xFF303030),
        gold: Color(0xFFD4AF37),
        gold2: Color(0xFFB98B2E),
        muted: Color(0xFF9AA4B2),
        text: Colors.white,
        textSoft: Color(0xFFCBD5E1),
        chipBg: Color(0xFF181B20),
        border: Color(0xFF1B1F26),
        shadow: Colors.black,
      );
    }

    return const _DuasPalette(
      bg: Color(0xFFF7F7F8),
      card: Colors.white,
      gold: Color(0xFFD4AF37),
      gold2: Color(0xFFB98B2E),
      muted: Color(0xFF667085),
      text: Color(0xFF121316),
      textSoft: Color(0xFF475467),
      chipBg: Color(0xFFF3F4F6),
      border: Color(0xFFE5E7EB),
      shadow: Color(0x22000000),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final _DuasPalette palette;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onMicTap;

  const _SearchBar({
    required this.palette,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.gold.withOpacity(.14)),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withOpacity(.10),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.search_rounded,
            color: palette.gold,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: palette.muted,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 8, right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onMicTap,
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        palette.gold.withOpacity(.98),
                        palette.gold2.withOpacity(.98),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: Color(0xFF14171C),
                    size: 22,
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

class _ZoneFilterBar extends StatelessWidget {
  final _DuasPalette palette;
  final String allLabel;
  final List<ZoneModel> zones;
  final String? selectedZoneId;
  final String langCode;
  final ValueChanged<String?> onChanged;

  const _ZoneFilterBar({
    required this.palette,
    required this.allLabel,
    required this.zones,
    required this.selectedZoneId,
    required this.langCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _ZoneFilterData(id: null, label: allLabel),
      ...zones.map((e) => _ZoneFilterData(id: e.zoneId, label: e.displayName(langCode))),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final active = selectedZoneId == item.id || (selectedZoneId == null && item.id == null);

          return GestureDetector(
            onTap: () => onChanged(item.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: active ? palette.gold.withOpacity(.15) : palette.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? palette.gold.withOpacity(.80) : palette.border,
                  width: active ? 1.3 : 1.0,
                ),
              ),
              child: Text(
                item.label,
                style: TextStyle(
                  color: active ? palette.gold : palette.textSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ZoneFilterData {
  final String? id;
  final String label;

  const _ZoneFilterData({
    required this.id,
    required this.label,
  });
}

class _DuaResultCard extends StatefulWidget {
  final _DuasPalette palette;
  final String title;
  final String text;
  final String zoneName;
  final String buttonText;
  final VoidCallback onPlay;
  final VoidCallback? onShare;

  /// تصنيف المحتوى — يُعرض كوسم ظاهر بجوار اسم الموضع، حتى لا يُفهم دعاء
  /// عام على أنه مخصوص بهذا المكان.
  final SupplicationContentKind kind;

  /// كيفية الأداء إن نصّ عليها المصدر — «مرة واحدة»، «ثلاث مرات».
  final RecitationPolicy? policy;

  /// تعليمة استعمال منقولة عن المطبوع. تُعرض ولا تدخل النطق أبدًا: نصّ
  /// التلاوة هو [text] وحده، ولا يُضمّ إليه شيء.
  final String usageNoteAr;

  const _DuaResultCard({
    required this.palette,
    required this.title,
    required this.text,
    required this.kind,
    this.policy,
    this.usageNoteAr = '',
    required this.zoneName,
    required this.buttonText,
    required this.onPlay,
    this.onShare,
  });

  @override
  State<_DuaResultCard> createState() => _DuaResultCardState();
}

class _DuaResultCardState extends State<_DuaResultCard> {
  double _buttonScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.palette.card,
        borderRadius: BorderRadius.circular(22),
        border: BorderDirectional(
          end: BorderSide(
            color: widget.palette.gold.withOpacity(.76),
            width: 3,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: widget.palette.shadow.withOpacity(.12),
            blurRadius: 20,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.palette.chipBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.zoneName,
                  style: TextStyle(color: widget.palette.gold, fontSize: 12.5, fontWeight: FontWeight.w900),
                ),
              ),
              const Spacer(),
              Text(widget.title, style: TextStyle(color: widget.palette.text, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onShare,
                child: Icon(Icons.copy_rounded, color: widget.palette.gold.withOpacity(.6), size: 19),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ContentKindBadge(kind: widget.kind),
          ),
          RecitationPolicyNote(
            policy: widget.policy,
            textColor: widget.palette.text,
          ),
          if (widget.usageNoteAr.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.usageNoteAr.trim(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.palette.text.withOpacity(0.8),
                fontSize: 12.5,
                height: 1.8,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            widget.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.palette.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 18),

          GestureDetector(
            onTapDown: (_) {
              setState(() {
                _buttonScale = 0.95;
              });
            },
            onTapUp: (_) {
              setState(() {
                _buttonScale = 1.0;
              });
            },
            onTapCancel: () {
              setState(() {
                _buttonScale = 1.0;
              });
            },
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onPlay();
            },
            child: AnimatedScale(
              scale: _buttonScale,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutCubic,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      widget.palette.gold,
                      widget.palette.gold2,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.palette.gold.withOpacity(.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.buttonText,
                    style: const TextStyle(
                      color: Color(0xFF14171C),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
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

class _EmptyDuasState extends StatelessWidget {
  final _DuasPalette palette;
  final String title;
  final String message;

  const _EmptyDuasState({
    required this.palette,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.menu_book_rounded,
            color: palette.gold,
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPlaybackBar extends StatelessWidget {
  final _DuasPalette palette;
  final String text;
  final String stopText;
  final VoidCallback onStop;

  const _BottomPlaybackBar({
    required this.palette,
    required this.text,
    required this.stopText,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(
          top: BorderSide(
            color: palette.gold.withOpacity(.14),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withOpacity(.12),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.graphic_eq_rounded,
            color: palette.gold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: palette.text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: onStop,
            child: Text(
              stopText,
              style: TextStyle(
                color: palette.gold,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// رأس شاشة "الدليل": العنوان + شريط تبويبين (الأدعية | المناسك).
class _DaleelHeader extends StatelessWidget {
  final _DuasPalette palette;
  final TabController controller;
  final bool isAr;

  const _DaleelHeader({
    required this.palette,
    required this.controller,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              isAr ? 'الدليل' : 'Guide',
              style: TextStyle(
                color: palette.gold,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: 'AlamirBold',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: palette.chipBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: controller,
              indicator: BoxDecoration(
                color: palette.gold,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              dividerColor: Colors.transparent,
              labelColor: const Color(0xFF14171C),
              unselectedLabelColor: palette.textSoft,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              tabs: [
                Tab(text: isAr ? 'الأدعية' : 'Supplications'),
                Tab(text: isAr ? 'المناسك' : 'Rituals'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// تبويب المناسك: قائمة بطاقات قابلة للتوسعة لكل منسك، مع تنبيه فقهي أسفلها.
class _ManasikTab extends StatelessWidget {
  final _DuasPalette palette;
  final bool isAr;
  final String langCode;

  const _ManasikTab({
    required this.palette,
    required this.isAr,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    // العنصر 0 = جدول الحج الزمني، ثم المناسك، وآخرها التنويه.
    return ListView.builder(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      itemCount: manasikRituals.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _HajjScheduleCard(
              palette: palette,
              langCode: langCode,
              isAr: isAr,
            ),
          );
        }
        if (index == manasikRituals.length + 1) {
          return _disclaimer();
        }
        final ritualIndex = index - 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ManasikCard(
            palette: palette,
            ritual: manasikRituals[ritualIndex],
            langCode: langCode,
            isAr: isAr,
            number: ritualIndex + 1,
          ),
        );
      },
    );
  }

  Widget _disclaimer() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.chipBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: palette.muted, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAr
                  ? 'هذا دليل تعليمي مبسّط. في المسائل المختلف فيها استشر عالمًا أو المرشد الميداني.'
                  : 'This is a simplified educational guide. For disputed matters, consult a scholar or your on-site guide.',
              style: TextStyle(
                color: palette.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة جدول الحج الزمني: رأس ثابت + أيام الحج (٨–١٣)، كل يوم قابل للتوسعة.
class _HajjScheduleCard extends StatefulWidget {
  final _DuasPalette palette;
  final String langCode;
  final bool isAr;

  const _HajjScheduleCard({
    required this.palette,
    required this.langCode,
    required this.isAr,
  });

  @override
  State<_HajjScheduleCard> createState() => _HajjScheduleCardState();
}

class _HajjScheduleCardState extends State<_HajjScheduleCard> {
  int _openDay = -1; // -1 = لا شيء مفتوح

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final lang = widget.langCode;

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: BorderDirectional(
          end: BorderSide(color: p.gold.withOpacity(.78), width: 3.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Icon(Icons.event_note_rounded, color: p.gold, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.isAr ? 'الجدول الزمني للحج' : 'Hajj Timeline',
                    style: TextStyle(
                        color: p.gold, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(hajjSchedule.length, (i) {
            final d = hajjSchedule[i];
            final open = _openDay == i;
            final tasks = d.tasks(lang);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Divider(color: p.gold.withOpacity(.08), height: 1),
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _openDay = open ? -1 : i);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.gold.withOpacity(.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            d.day(lang),
                            style: TextStyle(
                                color: p.gold, fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            d.title(lang),
                            style: TextStyle(
                                color: p.text, fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ),
                        AnimatedRotation(
                          turns: open ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.keyboard_arrow_down_rounded,
                              color: p.gold, size: 22),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeInOutCubic,
                  child: open
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: tasks
                                .map((t) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: p.gold,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              t,
                                              style: TextStyle(
                                                  color: p.textSoft,
                                                  fontSize: 13.5,
                                                  height: 1.6,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            );
          }),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// بطاقة منسك واحد قابلة للتوسعة: العنوان والملخّص، وعند الفتح الخطوات والدعاء.
class _ManasikCard extends StatefulWidget {
  final _DuasPalette palette;
  final ManasikRitual ritual;
  final String langCode;
  final bool isAr;
  final int number;

  const _ManasikCard({
    required this.palette,
    required this.ritual,
    required this.langCode,
    required this.isAr,
    required this.number,
  });

  @override
  State<_ManasikCard> createState() => _ManasikCardState();
}

class _ManasikCardState extends State<_ManasikCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final r = widget.ritual;
    final lang = widget.langCode;
    final steps = r.steps(lang);
    final dua = r.dua(lang);

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.gold.withOpacity(.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس البطاقة (قابل للضغط للفتح/الإغلاق).
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _open = !_open);
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.gold.withOpacity(.14),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${widget.number}',
                      style: TextStyle(color: p.gold, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                r.title(lang),
                                style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w900),
                              ),
                            ),
                            if (r.isHajjOnly) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: p.gold.withOpacity(.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  widget.isAr ? 'حج' : 'Hajj',
                                  style: TextStyle(color: p.gold, fontSize: 10.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          r.summary(lang),
                          style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: p.gold, size: 24),
                  ),
                ],
              ),
            ),
          ),
          // المحتوى الموسّع.
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: p.gold.withOpacity(.10), height: 18),
                        ...List.generate(steps.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${i + 1}. ',
                                  style: TextStyle(color: p.gold, fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                                Expanded(
                                  child: Text(
                                    steps[i],
                                    style: TextStyle(color: p.text, fontSize: 14, height: 1.55, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (dua != null && dua.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: p.gold.withOpacity(.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: p.gold.withOpacity(.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.isAr ? 'الدعاء' : 'Supplication',
                                  style: TextStyle(color: p.gold, fontSize: 12.5, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  dua,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: p.text, fontSize: 15, height: 1.7, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}