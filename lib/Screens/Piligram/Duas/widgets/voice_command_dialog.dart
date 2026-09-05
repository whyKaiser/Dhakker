import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../generated/l10n.dart';
import '../services/voice_search_service.dart';

class VoiceCommandDialog extends StatefulWidget {
  final VoiceSearchService service;
  final String localeId;

  const VoiceCommandDialog({
    super.key,
    required this.service,
    required this.localeId,
  });

  @override
  State<VoiceCommandDialog> createState() => _VoiceCommandDialogState();
}

class _VoiceCommandDialogState extends State<VoiceCommandDialog> {
  String _recognizedText = '';
  bool _isListening = false;
  double _animationScale = 1.0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final available = await widget.service.initialize(
      onStatus: (status) async {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
            _animationScale = 1.0;
          });
        }
      },
      onError: (error) async {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _animationScale = 1.0;
        });
      },
    );

    if (!available) {
      if (!mounted) return;
      Navigator.pop(context, '');
      return;
    }

    _isInitialized = true;

    await widget.service.startListening(
      localeId: widget.localeId,
      onResult: (words, isFinal) {
        if (!mounted) return;

        setState(() {
          _recognizedText = words;
        });

        if (isFinal && words.trim().isNotEmpty) {
          Navigator.pop(context, words.trim());
        }
      },
      onSoundLevelChange: (level) {
        if (!mounted) return;
        final cleanLevel = level < 0 ? 0 : level;
        final scale = 1.0 + (cleanLevel / 20).clamp(0.0, 0.45);
        setState(() {
          _animationScale = scale;
        });
      },
    );

    if (!mounted) return;

    setState(() {
      _isListening = true;
    });
  }

  @override
  void dispose() {
    if (_isInitialized) {
      widget.service.stopListening();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF303030) : Colors.white;
    final border = isDark
        ? const Color(0xFFD4AF37).withOpacity(.18)
        : const Color(0xFFD4AF37).withOpacity(.24);
    final text = isDark ? Colors.white : const Color(0xFF121316);
    final muted = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF667085);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.24),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.duasVoiceDialogTitle,
              style: TextStyle(
                color: text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFamily: 'AlamirBold',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _recognizedText.trim().isEmpty
                  ? s.duasVoiceDialogHint
                  : _recognizedText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _recognizedText.trim().isEmpty ? muted : text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            AnimatedScale(
              scale: _animationScale,
              duration: const Duration(milliseconds: 180),
              child: Lottie.asset(
                'assets/animations/siri2.json',
                height: 150,
                repeat: true,
                animate: true,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _VoiceDialogButton(
                    text: s.commonCancel,
                    isPrimary: false,
                    onTap: () {
                      Navigator.pop(context, '');
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _VoiceDialogButton(
                    text: _isListening ? s.duasListening : s.duasTapToRetry,
                    isPrimary: true,
                    onTap: () async {
                      if (_isListening) return;
                      await _start();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceDialogButton extends StatelessWidget {
  final String text;
  final bool isPrimary;
  final VoidCallback onTap;

  const _VoiceDialogButton({
    required this.text,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isPrimary
                  ? const LinearGradient(
                      colors: [
                        Color(0xFFD4AF37),
                        Color(0xFFB98B2E),
                      ],
                    )
                  : null,
              color: isPrimary
                  ? null
                  : (isDark
                      ? const Color(0xFF0B0D10)
                      : const Color(0xFFF3F4F6)),
              border: Border.all(
                color: isPrimary
                    ? Colors.transparent
                    : const Color(0xFFD4AF37).withOpacity(.18),
              ),
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: isPrimary
                      ? const Color(0xFF14171C)
                      : (isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF475467)),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
