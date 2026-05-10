import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../generated/l10n.dart';
import '../../locale_controller.dart';
import '../../theme/dhakker_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final s = S.of(context);
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );

      final uid = cred.user?.uid;
      if (uid == null) {
        _showSnack(s.authUnknownError, isError: true);
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'fullName': _name.text.trim(),
        'email': _email.text.trim(),
        'role': 'pilgrim',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showSnack(s.authRegisterSuccess, isError: false);

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _showSnack(_mapAuthError(e.code, s), isError: true);
    } catch (_) {
      _showSnack(s.authUnknownError, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapAuthError(String code, S s) {
    switch (code) {
      case 'email-already-in-use':
        return s.authEmailAlreadyInUse;
      case 'invalid-email':
        return s.authInvalidEmail;
      case 'weak-password':
        return s.authWeakPassword;
      case 'network-request-failed':
        return s.authNetworkError;
      default:
        return s.authUnknownError;
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : DhakkerColors.gold2,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final gold = isDark ? DhakkerColors.gold : DhakkerColors.gold2;
    final gold2 = DhakkerColors.gold2;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final textColor = isDark ? Colors.white : DhakkerColors.lightText;
    final fieldFill = isDark ? DhakkerColors.bg.withOpacity(.72) : Colors.white;
    final borderColor = (isDark ? Colors.white : Colors.black).withOpacity(isDark ? .08 : .06);

    return Scaffold(
      backgroundColor: bg,
      appBar: _HomeTopBar(
        onLanguageTap: LocaleController.toggle,
      ),
      body: Container(
        color: bg,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 14),
                _TopBrand(
                  muted: muted,
                  textColor: textColor,
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? .35 : .10),
                        blurRadius: 26,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          s.authRegisterTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'AlamirBold',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.authRegisterSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted.withOpacity(.95),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _name,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            labelText: s.authFullNameLabel,
                            hintText: s.authFullNameHint,
                            labelStyle: TextStyle(
                              color: muted.withOpacity(.95),
                              fontWeight: FontWeight.w700,
                            ),
                            hintStyle: TextStyle(
                              color: muted.withOpacity(.72),
                              fontWeight: FontWeight.w600,
                            ),
                            prefixIcon: Icon(
                              Icons.person_rounded,
                              color: gold2.withOpacity(.92),
                            ),
                            filled: true,
                            fillColor: fieldFill,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: borderColor,
                                width: 1.1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: gold.withOpacity(.85),
                                width: 1.4,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.redAccent.withOpacity(.8),
                                width: 1.2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.redAccent.withOpacity(.95),
                                width: 1.3,
                              ),
                            ),
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return s.authFullNameRequired;
                            if (value.length < 3) return s.authFullNameMin;
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            labelText: s.authEmailLabel,
                            hintText: s.authEmailHint,
                            labelStyle: TextStyle(
                              color: muted.withOpacity(.95),
                              fontWeight: FontWeight.w700,
                            ),
                            hintStyle: TextStyle(
                              color: muted.withOpacity(.72),
                              fontWeight: FontWeight.w600,
                            ),
                            prefixIcon: Icon(
                              Icons.email_rounded,
                              color: gold2.withOpacity(.92),
                            ),
                            filled: true,
                            fillColor: fieldFill,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: borderColor,
                                width: 1.1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: gold.withOpacity(.85),
                                width: 1.4,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.redAccent.withOpacity(.8),
                                width: 1.2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.redAccent.withOpacity(.95),
                                width: 1.3,
                              ),
                            ),
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return s.authEmailRequired;
                            final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
                            if (!ok) return s.authInvalidEmail;
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pass,
                          obscureText: _obscure1,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            labelText: s.authPasswordLabel,
                            hintText: s.authPasswordHint,
                            labelStyle: TextStyle(
                              color: muted.withOpacity(.95),
                              fontWeight: FontWeight.w700,
                            ),
                            hintStyle: TextStyle(
                              color: muted.withOpacity(.72),
                              fontWeight: FontWeight.w600,
                            ),
                            prefixIcon: Icon(
                              Icons.lock_rounded,
                              color: gold2.withOpacity(.92),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure1 = !_obscure1),
                              icon: Icon(
                                _obscure1 ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: muted.withOpacity(.9),
                              ),
                            ),
                            filled: true,
                            fillColor: fieldFill,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: borderColor,
                                width: 1.1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: gold.withOpacity(.85),
                                width: 1.4,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.redAccent.withOpacity(.8),
                                width: 1.2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.redAccent.withOpacity(.95),
                                width: 1.3,
                              ),
                            ),
                          ),
                          validator: (v) {
                            final value = v ?? '';
                            if (value.isEmpty) return s.authPasswordRequired;
                            if (value.length < 6) return s.authPasswordMin;
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirm,
                          obscureText: _obscure2,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _register(),
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            labelText: s.authConfirmPasswordLabel,
                            hintText: s.authPasswordHint,
                            labelStyle: TextStyle(
                              color: muted.withOpacity(.95),
                              fontWeight: FontWeight.w700,
                            ),
                            hintStyle: TextStyle(
                              color: muted.withOpacity(.72),
                              fontWeight: FontWeight.w600,
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              color: gold2.withOpacity(.92),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure2 = !_obscure2),
                              icon: Icon(
                                _obscure2 ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: muted.withOpacity(.9),
                              ),
                            ),
                            filled: true,
                            fillColor: fieldFill,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: borderColor,
                                width: 1.1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: gold.withOpacity(.85),
                                width: 1.4,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.redAccent.withOpacity(.8),
                                width: 1.2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.redAccent.withOpacity(.95),
                                width: 1.3,
                              ),
                            ),
                          ),
                          validator: (v) {
                            final value = v ?? '';
                            if (value.isEmpty) return s.authConfirmPasswordRequired;
                            if (value != _pass.text) return s.authPasswordsNotMatch;
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _PrimaryButton(
                          text: _loading ? s.authCreatingAccount : s.authRegisterButton,
                          enabled: !_loading,
                          onTap: _register,
                        ),
                        const SizedBox(height: 14),
                        _BackToLoginRow(
                          muted: muted,
                          onBack: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
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

class _HomeTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onLanguageTap;

  const _HomeTopBar({required this.onLanguageTap});

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = S.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';

    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final titleColor = isDark ? DhakkerColors.gold : DhakkerColors.gold2;
    final divider = titleColor.withOpacity(isDark ? .10 : .08);

    return AppBar(
      backgroundColor: bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 76,
      automaticallyImplyLeading: false,
      title: Text(
        s.appTitle,
        style: TextStyle(
          color: titleColor,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            children: [
              _LangPill(
                label: isAr ? s.langEnglish : s.langArabic,
                onTap: onLanguageTap,
              ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: divider,
        ),
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LangPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final border = isDark ? DhakkerColors.gold.withOpacity(.65) : DhakkerColors.gold2.withOpacity(.55);
    final text = isDark ? DhakkerColors.gold : DhakkerColors.gold2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: text.withOpacity(.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBrand extends StatelessWidget {
  final Color muted;
  final Color textColor;

  const _TopBrand({required this.muted, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? DhakkerColors.bg : DhakkerColors.lightBg,
            border: Border.all(
              color: DhakkerColors.gold.withOpacity(.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: DhakkerColors.gold.withOpacity(isDark ? .10 : .14),
                blurRadius: 26,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Image.asset(
            'assets/images/kaaba.png',
            width: 44,
            height: 44,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          s.appTitle,
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: 'AlamirBold',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.authWelcomeHint,
          style: TextStyle(
            color: muted.withOpacity(.95),
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final bool enabled;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.text,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 56,
      child: Opacity(
        opacity: enabled ? 1 : .65,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                DhakkerColors.gold.withOpacity(.98),
                DhakkerColors.gold2.withOpacity(.98),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: DhakkerColors.gold.withOpacity(isDark ? .18 : .14),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: enabled ? onTap : null,
              child: Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: DhakkerColors.darkText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackToLoginRow extends StatelessWidget {
  final Color muted;
  final VoidCallback onBack;

  const _BackToLoginRow({
    required this.muted,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          s.authHaveAccount,
          style: TextStyle(
            color: muted.withOpacity(.95),
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: onBack,
          style: TextButton.styleFrom(
            foregroundColor: DhakkerColors.gold,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          child: Text(
            s.authBackToLogin,
            style: const TextStyle(
              fontSize: 13.8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}