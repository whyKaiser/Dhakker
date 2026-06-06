import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // التحكم بالاهتزاز الحسّي
import '../../../generated/l10n.dart';
import '../../../theme/dhakker_theme.dart';

class AdminSupplicationEditScreen extends StatefulWidget {
  final String supplicationId;

  const AdminSupplicationEditScreen({
    super.key,
    required this.supplicationId,
  });

  @override
  State<AdminSupplicationEditScreen> createState() =>
      _AdminSupplicationEditScreenState();
}

class _AdminSupplicationEditScreenState
    extends State<AdminSupplicationEditScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _titleArController = TextEditingController();
  final _titleEnController = TextEditingController();
  final _textArController = TextEditingController();
  final _textEnController = TextEditingController();
  final _tagsArController = TextEditingController();
  final _tagsEnController = TextEditingController();

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _zoneDocs = [];

  bool _isLoading = true;
  bool _isSaving = false;

  String? _selectedZoneId;
  String _audioMode = 'tts';
  bool _isActive = true;

  String? _existingAudioUrl;
  Uint8List? _newAudioBytes;
  String? _newAudioFileName;

  late AnimationController _editEntranceController;
  double _saveBtnScale = 1.0;

  @override
  void initState() {
    super.initState();
    _editEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _titleArController.dispose();
    _titleEnController.dispose();
    _textArController.dispose();
    _textEnController.dispose();
    _tagsArController.dispose();
    _tagsEnController.dispose();
    _editEntranceController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('zones').get(),
        FirebaseFirestore.instance
            .collection('supplications')
            .doc(widget.supplicationId)
            .get(),
      ]);

      final zonesSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final supplicationDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;

      if (!supplicationDoc.exists) {
        if (!mounted) return;
        _showSnack(S.of(context).adminSupplicationEditNotFound, isError: true);
        Navigator.pop(context);
        return;
      }

      final data = supplicationDoc.data() ?? {};
      final titleMap = data['title'] is Map ? data['title'] as Map : {};
      final textMap = data['text'] is Map ? data['text'] as Map : {};

      _titleArController.text = (titleMap['ar'] ?? '').toString();
      _titleEnController.text = (titleMap['en'] ?? '').toString();
      _textArController.text = (textMap['ar'] ?? '').toString();
      _textEnController.text = (textMap['en'] ?? '').toString();

      final tagsAr = data['tagsAr'];
      final tagsEn = data['tagsEn'];

      _tagsArController.text = tagsAr is List ? tagsAr.join(', ') : '';
      _tagsEnController.text = tagsEn is List ? tagsEn.join(', ') : '';

      _selectedZoneId = (data['zoneId'] ?? '').toString().trim();
      _audioMode = (data['audioMode'] ?? 'tts').toString().trim();
      _existingAudioUrl = (data['audioUrl'] ?? '').toString().trim().isEmpty
          ? null
          : (data['audioUrl'] ?? '').toString().trim();
      _isActive = data['isActive'] == true;

      if (!mounted) return;
      setState(() {
        _zoneDocs = zonesSnap.docs;
        _isLoading = false;
      });
      _editEntranceController.forward();
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).adminSupplicationEditLoadError, isError: true);
      Navigator.pop(context);
    }
  }

  Future<void> _pickAudioFile() async {
    final s = S.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        _showSnack(s.adminSupplicationFilePickError, isError: true);
        return;
      }

      setState(() {
        _newAudioBytes = file.bytes;
        _newAudioFileName = file.name;
      });
    } catch (_) {
      _showSnack(s.adminSupplicationFilePickError, isError: true);
    }
  }

  Future<void> _saveSupplication() async {
    final s = S.of(context);
    if (!_formKey.currentState!.validate()) return;

    if (_selectedZoneId == null || _selectedZoneId!.trim().isEmpty) {
      _showSnack(s.adminSupplicationZoneRequired, isError: true);
      return;
    }

    if (_audioMode == 'file' &&
        _newAudioBytes == null &&
        (_existingAudioUrl == null || _existingAudioUrl!.isEmpty)) {
      _showSnack(s.adminSupplicationAudioFileRequired, isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? finalAudioUrl = _existingAudioUrl;

      if (_audioMode == 'file' && _newAudioBytes != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('audio/duas/${widget.supplicationId}.mp3');

        final metadata = SettableMetadata(contentType: 'audio/mpeg');

        await storageRef.putData(_newAudioBytes!, metadata);
        finalAudioUrl = await storageRef.getDownloadURL();
      }

      if (_audioMode == 'tts') {
        finalAudioUrl = null;
      }

      final data = {
        'duaId': widget.supplicationId,
        'zoneId': _selectedZoneId,
        'title': {
          'ar': _titleArController.text.trim(),
          'en': _titleEnController.text.trim(),
        },
        'text': {
          'ar': _textArController.text.trim(),
          'en': _textEnController.text.trim(),
        },
        'audioMode': _audioMode,
        'audioUrl': finalAudioUrl,
        'tagsAr': _splitTags(_tagsArController.text),
        'tagsEn': _splitTags(_tagsEnController.text),
        'languageCodes': ['ar', 'en'],
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('supplications')
          .doc(widget.supplicationId)
          .update(data);

      if (!mounted) return;
      _showSnack(s.adminSupplicationEditSuccess);
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(s.adminSupplicationEditError, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<String> _splitTags(String input) {
    return input
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
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
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    final List<Widget> editSections = [
      _SectionTitle(title: s.adminSupplicationAddBasicTitle),
      const SizedBox(height: 12),
      _CardBox(
        child: Column(
          children: [
            _ZoneDropdown(
              zoneDocs: _zoneDocs,
              value: _selectedZoneId,
              label: s.adminSupplicationZoneLabel,
              hint: s.adminSupplicationZoneHint,
              onChanged: (value) {
                setState(() {
                  _selectedZoneId = value;
                });
              },
            ),
            const SizedBox(height: 12),
            _AppField(
              controller: _titleArController,
              label: s.adminSupplicationTitleAr,
              hint: s.adminSupplicationTitleArHint,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return s.adminSupplicationTitleArRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _AppField(
              controller: _titleEnController,
              label: s.adminSupplicationTitleEn,
              hint: s.adminSupplicationTitleEnHint,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return s.adminSupplicationTitleEnRequired;
                }
                return null;
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _SectionTitle(title: s.adminSupplicationAddTextTitle),
      const SizedBox(height: 12),
      _CardBox(
        child: Column(
          children: [
            _AppField(
              controller: _textArController,
              label: s.adminSupplicationTextAr,
              hint: s.adminSupplicationTextArHint,
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return s.adminSupplicationTextArRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _AppField(
              controller: _textEnController,
              label: s.adminSupplicationTextEn,
              hint: s.adminSupplicationTextEnHint,
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return s.adminSupplicationTextEnRequired;
                }
                return null;
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _SectionTitle(title: s.adminSupplicationAddAudioTitle),
      const SizedBox(height: 12),
      _AudioModeSelector(
        value: _audioMode,
        onChanged: (value) {
          setState(() {
            _audioMode = value;
            if (_audioMode == 'tts') {
              _newAudioBytes = null;
              _newAudioFileName = null;
            }
          });
        },
      ),
      if (_audioMode == 'file') ...[
        const SizedBox(height: 12),
        _AudioFilePickerCard(
          fileName: _newAudioFileName ??
              (_existingAudioUrl != null ? s.adminSupplicationCurrentAudioAvailable : null),
          onPick: _pickAudioFile,
        ),
      ],
      const SizedBox(height: 18),
      _SectionTitle(title: s.adminSupplicationAddTagsTitle),
      const SizedBox(height: 12),
      _CardBox(
        child: Column(
          children: [
            _AppField(
              controller: _tagsArController,
              label: s.adminSupplicationTagsAr,
              hint: s.adminSupplicationTagsArHint,
            ),
            const SizedBox(height: 12),
            _AppField(
              controller: _tagsEnController,
              label: s.adminSupplicationTagsEn,
              hint: s.adminSupplicationTagsEnHint,
            ),
            const SizedBox(height: 12),
            _SwitchCard(
              title: s.adminSupplicationStatusTitle,
              subtitle: _isActive
                  ? s.adminSupplicationStatusActiveText
                  : s.adminSupplicationStatusInactiveText,
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      GestureDetector(
        onTapDown: (_) => setState(() => _saveBtnScale = 0.96),
        onTapUp: (_) {
          setState(() => _saveBtnScale = 1.0);
          HapticFeedback.lightImpact();
          if (!_isSaving) _saveSupplication();
        },
        onTapCancel: () => setState(() => _saveBtnScale = 1.0),
        child: AnimatedScale(
          scale: _saveBtnScale,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: isDark ? DhakkerColors.bg : Colors.white,
                disabledBackgroundColor: accent,
                disabledForegroundColor: isDark ? DhakkerColors.bg : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: null,
              icon: _isSaving
                  ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.3,
                  color: isDark ? DhakkerColors.bg : Colors.white,
                ),
              )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _isSaving ? s.adminSupplicationSaving : s.adminSupplicationEditSave,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: text,
        title: Text(
          s.adminSupplicationEditTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const _SupplicationFormLoadingView()
            : Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(editSections.length, (index) {
                final double start = (index * 0.03).clamp(0.0, 1.0);
                final double end = (start + 0.30).clamp(0.0, 1.0);

                return AnimatedBuilder(
                  animation: _editEntranceController,
                  builder: (context, child) {
                    final curve = CurvedAnimation(
                      parent: _editEntranceController,
                      curve: Interval(start, end, curve: Curves.easeOutCubic),
                    );
                    return Transform.translate(
                      offset: Offset(0, 20 * (1.0 - curve.value)),
                      child: Opacity(
                        opacity: curve.value,
                        child: child,
                      ),
                    );
                  },
                  child: editSections[index],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// الكلاسات الفرعية الداعمة والمطابقة مسبقاً
class _ZoneDropdown extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> zoneDocs;
  final String? value;
  final String label;
  final String hint;
  final ValueChanged<String?> onChanged;

  const _ZoneDropdown({
    required this.zoneDocs,
    required this.value,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: muted.withOpacity(.95), fontSize: 12.3, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          dropdownColor: isDark ? DhakkerColors.card : Colors.white,
          style: TextStyle(color: text, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: muted.withOpacity(.85), fontWeight: FontWeight.w700),
            filled: true,
            fillColor: (isDark ? Colors.white : Colors.black).withOpacity(.04),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(.08))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(.08))),
          ),
          items: zoneDocs.map((doc) {
            final data = doc.data();
            final name = isAr
                ? (data['nameAr'] ?? data['nameEn'] ?? '').toString().trim()
                : (data['nameEn'] ?? data['nameAr'] ?? '').toString().trim();
            return DropdownMenuItem<String>(value: doc.id, child: Text(name.isEmpty ? doc.id : name, overflow: TextOverflow.ellipsis));
          }).toList(),
        ),
      ],
    );
  }
}

class _AudioModeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _AudioModeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      children: [
        Expanded(child: _TypeCard(title: s.adminSupplicationAudioTts, subtitle: s.adminSupplicationAudioTtsDesc, icon: Icons.record_voice_over_rounded, isSelected: value == 'tts', onTap: () => onChanged('tts'))),
        const SizedBox(width: 10),
        Expanded(child: _TypeCard(title: s.adminSupplicationAudioFile, subtitle: s.adminSupplicationAudioFileDesc, icon: Icons.audiotrack_rounded, isSelected: value == 'file', onTap: () => onChanged('file'))),
      ],
    );
  }
}

class _AudioFilePickerCard extends StatefulWidget {
  final String? fileName;
  final VoidCallback onPick;
  const _AudioFilePickerCard({required this.fileName, required this.onPick});

  @override
  State<_AudioFilePickerCard> createState() => _AudioFilePickerCardState();
}

class _AudioFilePickerCardState extends State<_AudioFilePickerCard> {
  double _pickerScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? .30 : .07), blurRadius: 18, offset: const Offset(0, 12))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.attach_file_rounded, color: accent),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.fileName == null || widget.fileName!.trim().isEmpty ? s.adminSupplicationNoAudioSelected : widget.fileName!, style: TextStyle(color: widget.fileName == null ? muted : text, fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTapDown: (_) => setState(() => _pickerScale = 0.95),
            onTapUp: (_) {
              setState(() => _pickerScale = 1.0);
              HapticFeedback.lightImpact();
              widget.onPick();
            },
            onTapCancel: () => setState(() => _pickerScale = 1.0),
            child: AnimatedScale(
              scale: _pickerScale,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: isDark ? DhakkerColors.bg : Colors.white, disabledBackgroundColor: accent, disabledForegroundColor: isDark ? DhakkerColors.bg : Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: null,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(s.adminSupplicationPickAudio, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplicationFormLoadingView extends StatelessWidget {
  const _SupplicationFormLoadingView();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: Column(
        children: [
          _LoadingCard(card: card, height: 220),
          const SizedBox(height: 18),
          _LoadingCard(card: card, height: 240),
          const SizedBox(height: 18),
          _LoadingCard(card: card, height: 160),
          const SizedBox(height: 18),
          _LoadingCard(card: card, height: 180),
        ],
      ),
    );
  }
}

class _CardBox extends StatelessWidget {
  final Widget child;
  const _CardBox({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border(right: BorderSide(color: accent.withOpacity(.55), width: 3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? .30 : .07), blurRadius: 18, offset: const Offset(0, 12))],
      ),
      child: child,
    );
  }
}

class _AppField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final int maxLines;

  const _AppField({required this.controller, required this.label, required this.hint, this.validator, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: muted.withOpacity(.95), fontSize: 12.3, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          style: TextStyle(color: text, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: muted.withOpacity(.85), fontWeight: FontWeight.w700),
            filled: true,
            fillColor: (isDark ? Colors.white : Colors.black).withOpacity(.04),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(.08))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(.08))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: accent.withOpacity(.75), width: 1.2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.1)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.2)),
          ),
        ),
      ],
    );
  }
}

class _TypeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _TypeCard({required this.title, required this.subtitle, required this.icon, required this.isSelected, required this.onTap});

  @override
  State<_TypeCard> createState() => _TypeCardState();
}

class _TypeCardState extends State<_TypeCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: widget.isSelected ? accent.withOpacity(.75) : (isDark ? Colors.white : Colors.black).withOpacity(.07), width: widget.isSelected ? 1.4 : 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? .30 : .07), blurRadius: 18, offset: const Offset(0, 12))],
          ),
          child: Column(
            children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: accent.withOpacity(.10), borderRadius: BorderRadius.circular(16)), child: Icon(widget.icon, color: accent, size: 28)),
              const SizedBox(height: 10),
              Text(widget.title, textAlign: TextAlign.center, style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 4),
              Text(widget.subtitle, textAlign: TextAlign.center, style: TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 11.8, height: 1.45)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchCard({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: (isDark ? Colors.white : Colors.black).withOpacity(.04),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(.06),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 13.2)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 12.2, height: 1.45)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: onChanged),
        ],
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
        Expanded(child: Text(title, style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: .1))),
        Container(width: 26, height: 3, decoration: BoxDecoration(color: muted.withOpacity(.35), borderRadius: BorderRadius.circular(99))),
      ],
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