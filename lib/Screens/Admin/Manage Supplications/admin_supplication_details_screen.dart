import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../generated/l10n.dart';
import '../../../theme/dhakker_theme.dart';

class AdminSupplicationDetailsScreen extends StatefulWidget {
  final String supplicationId;

  const AdminSupplicationDetailsScreen({
    super.key,
    required this.supplicationId,
  });

  @override
  State<AdminSupplicationDetailsScreen> createState() =>
      _AdminSupplicationDetailsScreenState();
}

class _AdminSupplicationDetailsScreenState
    extends State<AdminSupplicationDetailsScreen> with SingleTickerProviderStateMixin {
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isLoading = true;
  bool _isSpeaking = false;
  bool _isPlayingFile = false;

  Map<String, dynamic>? _supplicationData;
  Map<String, dynamic>? _zoneData;

  late AnimationController _detailsEntranceController;

  @override
  void initState() {
    super.initState();
    _detailsEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _configureTts();
    _loadData();
  }

  Future<void> _configureTts() async {
    await _flutterTts.setSpeechRate(0.42);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      if (!mounted) return;
      setState(() {
        _isSpeaking = true;
      });
    });

    _flutterTts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
      });
    });

    _flutterTts.setCancelHandler(() {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
      });
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (!mounted) return;
      setState(() {
        _isPlayingFile = false;
      });
    });
  }

  Future<void> _loadData() async {
    try {
      final supplicationDoc = await FirebaseFirestore.instance
          .collection('supplications')
          .doc(widget.supplicationId)
          .get();

      if (!supplicationDoc.exists) {
        if (!mounted) return;
        _showSnack(S.of(context).adminSupplicationDetailsNotFound, isError: true);
        Navigator.pop(context);
        return;
      }

      final supplicationData = supplicationDoc.data() ?? {};
      final zoneId = (supplicationData['zoneId'] ?? '').toString().trim();

      Map<String, dynamic>? zoneData;
      if (zoneId.isNotEmpty) {
        final zoneDoc = await FirebaseFirestore.instance
            .collection('zones')
            .doc(zoneId)
            .get();
        zoneData = zoneDoc.data();
      }

      if (!mounted) return;
      setState(() {
        _supplicationData = supplicationData;
        _zoneData = zoneData;
        _isLoading = false;
      });
      _detailsEntranceController.forward();
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).adminSupplicationDetailsLoadError, isError: true);
      Navigator.pop(context);
    }
  }

  Future<void> _playTts() async {
    final s = S.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';

    final textMap = _supplicationData?['text'];
    final text = textMap is Map
        ? (isAr
        ? (textMap['ar'] ?? textMap['en'] ?? '')
        : (textMap['en'] ?? textMap['ar'] ?? ''))
        .toString()
        .trim()
        : '';

    if (text.isEmpty) {
      _showSnack(s.adminSupplicationDetailsNoTextToSpeak, isError: true);
      return;
    }

    try {
      await _audioPlayer.stop();
      setState(() {
        _isPlayingFile = false;
      });

      await _flutterTts.stop();
      await _flutterTts.setLanguage(isAr ? 'ar-SA' : 'en-US');
      await _flutterTts.speak(text);
    } catch (_) {
      _showSnack(s.adminSupplicationDetailsTtsError, isError: true);
    }
  }

  Future<void> _stopTts() async {
    await _flutterTts.stop();
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _playAudioFile() async {
    final s = S.of(context);
    final url = (_supplicationData?['audioUrl'] ?? '').toString().trim();

    if (url.isEmpty) {
      _showSnack(s.adminSupplicationDetailsNoAudioFile, isError: true);
      return;
    }

    try {
      await _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
      });

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));

      if (!mounted) return;
      setState(() {
        _isPlayingFile = true;
      });
    } catch (_) {
      _showSnack(s.adminSupplicationDetailsAudioPlayError, isError: true);
    }
  }

  Future<void> _stopAudioFile() async {
    await _audioPlayer.stop();
    if (!mounted) return;
    setState(() {
      _isPlayingFile = false;
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? const Color(0xFFDC2626) : null,
      ),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _audioPlayer.dispose();
    _detailsEntranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final text = isDark ? Colors.white : DhakkerColors.lightText;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: text,
        title: Text(
          s.adminSupplicationDetailsTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const _SupplicationDetailsLoadingView()
            : _supplicationData == null
            ? const SizedBox.shrink()
            : _SupplicationDetailsBody(
          supplicationData: _supplicationData!,
          zoneData: _zoneData,
          isSpeaking: _isSpeaking,
          isPlayingFile: _isPlayingFile,
          onPlayTts: _playTts,
          onStopTts: _stopTts,
          onPlayAudioFile: _playAudioFile,
          onStopAudioFile: _stopAudioFile,
          entranceController: _detailsEntranceController,
        ),
      ),
    );
  }
}

class _SupplicationDetailsBody extends StatelessWidget {
  final Map<String, dynamic> supplicationData;
  final Map<String, dynamic>? zoneData;
  final bool isSpeaking;
  final bool isPlayingFile;
  final VoidCallback onPlayTts;
  final VoidCallback onStopTts;
  final VoidCallback onPlayAudioFile;
  final VoidCallback onStopAudioFile;
  final AnimationController entranceController;

  const _SupplicationDetailsBody({
    required this.supplicationData,
    required this.zoneData,
    required this.isSpeaking,
    required this.isPlayingFile,
    required this.onPlayTts,
    required this.onStopTts,
    required this.onPlayAudioFile,
    required this.onStopAudioFile,
    required this.entranceController,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';

    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;

    final titleMap = supplicationData['title'] is Map ? supplicationData['title'] as Map : {};
    final textMap = supplicationData['text'] is Map ? supplicationData['text'] as Map : {};

    final currentTitle = isAr
        ? (titleMap['ar'] ?? titleMap['en'] ?? '').toString().trim()
        : (titleMap['en'] ?? titleMap['ar'] ?? '').toString().trim();

    final textAr = (textMap['ar'] ?? '').toString().trim();
    final textEn = (textMap['en'] ?? '').toString().trim();

    final audioMode = (supplicationData['audioMode'] ?? '').toString().trim();
    final isActive = supplicationData['isActive'] == true;
    final audioUrl = (supplicationData['audioUrl'] ?? '').toString().trim();

    final zoneName = _zoneName(context, zoneData);

    final List<Widget> detailElements = [
      _SectionTitle(title: s.adminSupplicationDetailsOverviewTitle),
      const SizedBox(height: 12),
      _HeroCard(
        title: currentTitle.isEmpty ? '—' : currentTitle,
        zoneName: zoneName,
        audioMode: audioMode,
        isActive: isActive,
      ),
      const SizedBox(height: 18),
      _SectionTitle(title: s.adminSupplicationDetailsZoneInfoTitle),
      const SizedBox(height: 12),
      _DetailsCard(
        children: [
          _InfoRow(
            label: s.adminSupplicationDetailsZoneNameLabel,
            value: zoneName,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: s.adminSupplicationDetailsAudioModeLabel,
            value: audioMode == 'file' ? s.adminSupplicationAudioFile : s.adminSupplicationAudioTts,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: s.adminSupplicationDetailsStatusLabel,
            value: isActive ? s.adminSupplicationStatusActiveText : s.adminSupplicationStatusInactiveText,
          ),
        ],
      ),
      const SizedBox(height: 18),
      _SectionTitle(title: s.adminSupplicationDetailsTextTitle),
      const SizedBox(height: 12),
      _TextCard(
        title: s.adminSupplicationDetailsArabicTextTitle,
        text: textAr,
      ),
      const SizedBox(height: 12),
      _TextCard(
        title: s.adminSupplicationDetailsEnglishTextTitle,
        text: textEn,
      ),
      const SizedBox(height: 18),
      _SectionTitle(title: s.adminSupplicationDetailsAudioSectionTitle),
      const SizedBox(height: 12),
      if (audioMode == 'tts')
        _AudioActionCard(
          title: s.adminSupplicationDetailsTtsCardTitle,
          subtitle: s.adminSupplicationDetailsTtsCardSubtitle,
          buttonLabel: isSpeaking ? s.adminSupplicationDetailsStopButton : s.adminSupplicationDetailsPlayTtsButton,
          icon: isSpeaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
          isActive: isSpeaking,
          onTap: isSpeaking ? onStopTts : onPlayTts,
        ),
      if (audioMode == 'file')
        _AudioActionCard(
          title: s.adminSupplicationDetailsFileCardTitle,
          subtitle: audioUrl.isEmpty ? s.adminSupplicationDetailsNoAudioFile : s.adminSupplicationDetailsFileCardSubtitle,
          buttonLabel: isPlayingFile ? s.adminSupplicationDetailsStopButton : s.adminSupplicationDetailsPlayFileButton,
          icon: isPlayingFile ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
          isActive: isPlayingFile,
          onTap: isPlayingFile ? onStopAudioFile : onPlayAudioFile,
        ),
    ];

    return Container(
      color: bg,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(detailElements.length, (index) {
            final double start = (index * 0.04).clamp(0.0, 1.0);
            final double end = (start + 0.35).clamp(0.0, 1.0);

            return AnimatedBuilder(
              animation: entranceController,
              builder: (context, child) {
                final curve = CurvedAnimation(
                  parent: entranceController,
                  curve: Interval(start, end, curve: Curves.easeOutCubic),
                );
                return Transform.translate(
                  offset: Offset(0, 24 * (1.0 - curve.value)),
                  child: Opacity(
                    opacity: curve.value,
                    child: child,
                  ),
                );
              },
              child: detailElements[index],
            );
          }),
        ),
      ),
    );
  }

  String _zoneName(BuildContext context, Map<String, dynamic>? zoneData) {
    if (zoneData == null) return '—';
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final name = isAr
        ? (zoneData['nameAr'] ?? zoneData['nameEn'] ?? '').toString().trim()
        : (zoneData['nameEn'] ?? zoneData['nameAr'] ?? '').toString().trim();
    return name.isEmpty ? '—' : name;
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String zoneName;
  final String audioMode;
  final bool isActive;

  const _HeroCard({
    required this.title,
    required this.zoneName,
    required this.audioMode,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    final statusColor = isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final audioColor = audioMode == 'file' ? const Color(0xFF7C3AED) : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
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
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.menu_book_rounded, color: accent, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _MiniBadge(label: zoneName, color: accent)),
              const SizedBox(width: 10),
              Expanded(child: _MiniBadge(label: audioMode == 'file' ? s.adminSupplicationAudioFile : s.adminSupplicationAudioTts, color: audioColor)),
            ],
          ),
          const SizedBox(height: 10),
          _MiniBadge(label: isActive ? s.adminSupplicationStatusActiveText : s.adminSupplicationStatusInactiveText, color: statusColor),
        ],
      ),
    );
  }
}

class _AudioActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _AudioActionCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_AudioActionCard> createState() => _AudioActionCardState();
}

class _AudioActionCardState extends State<_AudioActionCard> {
  double _btnScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final accent = widget.isActive ? const Color(0xFFDC2626) : (isDark ? DhakkerColors.gold : DhakkerColors.gold2);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
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
              Icon(widget.icon, color: accent, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.title, style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 14.4)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.subtitle, style: TextStyle(color: muted, fontWeight: FontWeight.w700, height: 1.5)),
          const SizedBox(height: 14),
          GestureDetector(
            onTapDown: (_) => setState(() => _btnScale = 0.95),
            onTapUp: (_) {
              setState(() => _btnScale = 1.0);
              HapticFeedback.lightImpact();
              widget.onTap();
            },
            onTapCancel: () => setState(() => _btnScale = 1.0),
            child: AnimatedScale(
              scale: _btnScale,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: accent,
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: null,
                  icon: Icon(widget.icon),
                  label: Text(widget.buttonLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  final String title;
  final String text;
  const _TextCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final textColor = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .30 : .07),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: muted.withOpacity(.95), fontSize: 12.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(text.isEmpty ? '—' : text, style: TextStyle(color: textColor, fontSize: 14.2, fontWeight: FontWeight.w700, height: 1.75)),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .30 : .07),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(color: muted.withOpacity(.95), fontSize: 12.4, fontWeight: FontWeight.w800))),
        const SizedBox(width: 12),
        Expanded(child: Text(value, textAlign: TextAlign.end, style: TextStyle(color: text, fontSize: 12.8, fontWeight: FontWeight.w800, height: 1.45))),
      ],
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
        Expanded(child: Text(title, style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: .1))),
        Container(width: 26, height: 3, decoration: BoxDecoration(color: muted.withOpacity(.35), borderRadius: BorderRadius.circular(99))),
      ],
    );
  }
}

class _SupplicationDetailsLoadingView extends StatelessWidget {
  const _SupplicationDetailsLoadingView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: Column(
        children: [
          _LoadingCard(card: card, height: 160),
          const SizedBox(height: 18),
          _LoadingCard(card: card, height: 140),
          const SizedBox(height: 18),
          _LoadingCard(card: card, height: 180),
          const SizedBox(height: 12),
          _LoadingCard(card: card, height: 180),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final Color card;
  final double height;
  const _LoadingCard({required this.card, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18)),
    );
  }
}