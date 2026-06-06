import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../generated/l10n.dart';
import '../../../theme/dhakker_theme.dart';

class AdminZoneEditScreen extends StatefulWidget {
  final String zoneId;

  const AdminZoneEditScreen({
    super.key,
    required this.zoneId,
  });

  @override
  State<AdminZoneEditScreen> createState() => _AdminZoneEditScreenState();
}

class _AdminZoneEditScreenState extends State<AdminZoneEditScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();

  final _centerLatController = TextEditingController();
  final _centerLngController = TextEditingController();
  final _radiusController = TextEditingController();
  final _priorityController = TextEditingController();

  final _pointLatController = TextEditingController();
  final _pointLngController = TextEditingController();

  String _zoneType = 'circle';
  bool _isActive = true;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<Map<String, double>> _polygonPoints = [];

  late AnimationController _editEntranceController;
  double _saveBtnScale = 1.0;

  @override
  void initState() {
    super.initState();
    _editEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _loadZone();
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _centerLatController.dispose();
    _centerLngController.dispose();
    _radiusController.dispose();
    _priorityController.dispose();
    _pointLatController.dispose();
    _pointLngController.dispose();
    _editEntranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    final List<Widget> editSections = [
      _SectionTitle(title: s.adminZoneEditBasicInfoTitle),
      const SizedBox(height: 12),
      _CardBox(
        child: Column(
          children: [
            _AppField(
              controller: _nameArController,
              label: s.adminZoneEditNameAr,
              hint: s.adminZoneEditNameArHint,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return s.adminZoneEditNameArRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _AppField(
              controller: _nameEnController,
              label: s.adminZoneEditNameEn,
              hint: s.adminZoneEditNameEnHint,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return s.adminZoneEditNameEnRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _AppField(
              controller: _priorityController,
              label: s.adminZoneEditPriority,
              hint: s.adminZoneEditPriorityHint,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return s.adminZoneEditPriorityRequired;
                }
                final number = int.tryParse(value.trim());
                if (number == null) {
                  return s.adminZoneEditPriorityInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _SwitchCard(
              title: s.adminZoneEditStatusTitle,
              subtitle: _isActive
                  ? s.adminZoneEditStatusActiveText
                  : s.adminZoneEditStatusInactiveText,
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
      const SizedBox(height: 18),
      _SectionTitle(title: s.adminZoneEditTypeTitle),
      const SizedBox(height: 12),
      _TypeSelector(
        value: _zoneType,
        onChanged: (value) {
          setState(() {
            _zoneType = value;
          });
        },
      ),
      const SizedBox(height: 16),
      if (_zoneType == 'circle') ...[
        _ShapeIntroCard(
          icon: Icons.circle_outlined,
          title: s.adminZoneEditCircleCardTitle,
          subtitle: s.adminZoneEditCircleCardSubtitle,
        ),
        const SizedBox(height: 12),
        _CardBox(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _AppField(
                      controller: _centerLatController,
                      label: s.adminZoneEditCenterLat,
                      hint: s.adminZoneEditCenterLatHint,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (_zoneType != 'circle') return null;
                        if (value == null || value.trim().isEmpty) {
                          return s.adminZoneEditCenterLatRequired;
                        }
                        final number = double.tryParse(value.trim());
                        if (number == null || number < -90 || number > 90) {
                          return s.adminZoneEditLatitudeInvalid;
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AppField(
                      controller: _centerLngController,
                      label: s.adminZoneEditCenterLng,
                      hint: s.adminZoneEditCenterLngHint,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (_zoneType != 'circle') return null;
                        if (value == null || value.trim().isEmpty) {
                          return s.adminZoneEditCenterLngRequired;
                        }
                        final number = double.tryParse(value.trim());
                        if (number == null || number < -180 || number > 180) {
                          return s.adminZoneEditLongitudeInvalid;
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _AppField(
                controller: _radiusController,
                label: s.adminZoneEditRadius,
                hint: s.adminZoneEditRadiusHint,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (_zoneType != 'circle') return null;
                  if (value == null || value.trim().isEmpty) {
                    return s.adminZoneEditRadiusRequired;
                  }
                  final number = double.tryParse(value.trim());
                  if (number == null || number <= 0) {
                    return s.adminZoneEditRadiusInvalid;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ],
      if (_zoneType == 'polygon') ...[
        _ShapeIntroCard(
          icon: Icons.polyline_rounded,
          title: s.adminZoneEditPolygonCardTitle,
          subtitle: s.adminZoneEditPolygonCardSubtitle,
        ),
        const SizedBox(height: 12),
        _CardBox(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _AppField(
                      controller: _pointLatController,
                      label: s.adminZoneEditPointLat,
                      hint: s.adminZoneEditPointLatHint,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AppField(
                      controller: _pointLngController,
                      label: s.adminZoneEditPointLng,
                      hint: s.adminZoneEditPointLngHint,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _HapticButton(
                onTap: _addPolygonPoint,
                label: s.adminZoneEditPointButton,
                icon: Icons.add_rounded,
                color: accent,
                textColor: isDark ? DhakkerColors.bg : Colors.white,
              ),
              const SizedBox(height: 14),
              _PolygonPointsPanel(
                points: _polygonPoints,
                onDelete: (index) {
                  setState(() {
                    _polygonPoints.removeAt(index);
                  });
                },
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 22),
      GestureDetector(
        onTapDown: (_) => setState(() => _saveBtnScale = 0.96),
        onTapUp: (_) {
          setState(() => _saveBtnScale = 1.0);
          HapticFeedback.lightImpact();
          if (!_isSaving) _saveZone();
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                _isSaving ? s.adminZoneEditSaving : s.adminZoneEditSave,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
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
          s.adminZoneEditTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? _EditLoadingView(card: card)
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

  Future<void> _loadZone() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('zones')
          .doc(widget.zoneId)
          .get();

      if (!doc.exists) {
        if (!mounted) return;
        _showSnack(S.of(context).adminZoneEditNotFound, isError: true);
        Navigator.pop(context);
        return;
      }

      final data = doc.data() ?? {};

      _nameArController.text = (data['nameAr'] ?? '').toString();
      _nameEnController.text = (data['nameEn'] ?? '').toString();
      _zoneType = (data['type'] ?? 'circle').toString();
      _isActive = data['isActive'] == true;
      _priorityController.text = (data['priority'] ?? 1).toString();

      final center = data['center'];
      if (center is Map) {
        final lat = center['lat'];
        final lng = center['lng'];
        _centerLatController.text = lat == null ? '' : lat.toString();
        _centerLngController.text = lng == null ? '' : lng.toString();
      } else {
        _centerLatController.clear();
        _centerLngController.clear();
      }

      final radiusM = data['radiusM'];
      _radiusController.text = radiusM == null ? '' : radiusM.toString();

      _polygonPoints.clear();

      final rawPoints = data['points'];
      if (rawPoints is List) {
        for (final item in rawPoints) {
          if (item is Map) {
            final lat = double.tryParse('${item['lat']}');
            final lng = double.tryParse('${item['lng']}');
            if (lat != null && lng != null) {
              _polygonPoints.add({
                'lat': lat,
                'lng': lng,
              });
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _editEntranceController.forward();
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).adminZoneEditLoadError, isError: true);
      Navigator.pop(context);
    }
  }

  void _addPolygonPoint() {
    final s = S.of(context);
    final latText = _pointLatController.text.trim();
    final lngText = _pointLngController.text.trim();

    if (latText.isEmpty || lngText.isEmpty) {
      _showSnack(s.adminZoneEditPointRequired, isError: true);
      return;
    }

    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);

    if (lat == null || lat < -90 || lat > 90) {
      _showSnack(s.adminZoneEditLatitudeInvalid, isError: true);
      return;
    }

    if (lng == null || lng < -180 || lng > 180) {
      _showSnack(s.adminZoneEditLongitudeInvalid, isError: true);
      return;
    }

    setState(() {
      _polygonPoints.add({
        'lat': lat,
        'lng': lng,
      });
      _pointLatController.clear();
      _pointLngController.clear();
    });
  }

  Future<void> _saveZone() async {
    final s = S.of(context);

    if (!_formKey.currentState!.validate()) return;

    if (_zoneType == 'polygon' && _polygonPoints.length < 3) {
      _showSnack(s.adminZoneEditPolygonMinPoints, isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final data = {
        'zoneId': widget.zoneId,
        'nameAr': _nameArController.text.trim(),
        'nameEn': _nameEnController.text.trim(),
        'type': _zoneType,
        'center': _zoneType == 'circle'
            ? {
          'lat': double.parse(_centerLatController.text.trim()),
          'lng': double.parse(_centerLngController.text.trim()),
        }
            : null,
        'radiusM': _zoneType == 'circle'
            ? double.parse(_radiusController.text.trim())
            : null,
        'points': _zoneType == 'polygon'
            ? _polygonPoints
            .map(
              (e) => {
            'lat': e['lat'],
            'lng': e['lng'],
          },
        )
            .toList()
            : [],
        'priority': int.parse(_priorityController.text.trim()),
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('zones')
          .doc(widget.zoneId)
          .update(data);

      if (!mounted) return;
      _showSnack(s.adminZoneEditSuccess);
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(s.adminZoneEditError, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
}

class _HapticButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;

  const _HapticButton({
    required this.onTap,
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
  });

  @override
  State<_HapticButton> createState() => _HapticButtonState();
}

class _HapticButtonState extends State<_HapticButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
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
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              foregroundColor: widget.textColor,
              disabledBackgroundColor: widget.color,
              disabledForegroundColor: widget.textColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: null,
            icon: Icon(widget.icon),
            label: Text(
              widget.label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditLoadingView extends StatelessWidget {
  final Color card;
  const _EditLoadingView({required this.card});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: Column(
        children: [
          _LoadingCard(card: card, height: 250),
          const SizedBox(height: 18),
          _LoadingCard(card: card, height: 120),
          const SizedBox(height: 16),
          _LoadingCard(card: card, height: 230),
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
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
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
      child: child,
    );
  }
}

class _AppField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  const _AppField({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: muted.withOpacity(.95),
            fontSize: 12.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: muted.withOpacity(.85),
              fontWeight: FontWeight.w700,
            ),
            filled: true,
            fillColor: (isDark ? Colors.white : Colors.black).withOpacity(.04),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 1.1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SwitchCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.2,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _TypeSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Row(
      children: [
        Expanded(
          child: _TypeCard(
            title: s.adminZoneEditTypeCircle,
            subtitle: s.adminZoneEditTypeCircleDesc,
            icon: Icons.circle_outlined,
            isSelected: value == 'circle',
            onTap: () => onChanged('circle'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TypeCard(
            title: s.adminZoneEditTypePolygon,
            subtitle: s.adminZoneEditTypePolygonDesc,
            icon: Icons.polyline_rounded,
            isSelected: value == 'polygon',
            onTap: () => onChanged('polygon'),
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

  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

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
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isSelected
                  ? accent.withOpacity(.75)
                  : (isDark ? Colors.white : Colors.black).withOpacity(.07),
              width: widget.isSelected ? 1.4 : 1,
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
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.icon, color: accent, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: text,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.8,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShapeIntroCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ShapeIntroCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DhakkerColors.gold : DhakkerColors.gold2;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withOpacity(.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .30 : .07),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withOpacity(.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: accent, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.2,
                    height: 1.45,
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

class _PolygonPointsPanel extends StatelessWidget {
  final List<Map<String, double>> points;
  final ValueChanged<int> onDelete;

  const _PolygonPointsPanel({
    required this.points,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    if (points.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: (isDark ? Colors.white : Colors.black).withOpacity(.04),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withOpacity(.06),
          ),
        ),
        child: Text(
          s.adminZoneEditNoPointsYet,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: muted,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${points.length} ${s.adminZoneEditPointsCount}',
          style: TextStyle(
            color: muted.withOpacity(.95),
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(points.length, (index) {
          final point = points[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: (isDark ? Colors.white : Colors.black).withOpacity(.04),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withOpacity(.06),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: (isDark ? DhakkerColors.gold : DhakkerColors.gold2)
                      .withOpacity(.14),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isDark ? DhakkerColors.gold : DhakkerColors.gold2,
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lat: ${point['lat']}, Lng: ${point['lng']}',
                    style: TextStyle(
                      color: text,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.6,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => onDelete(index),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}