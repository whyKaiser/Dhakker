import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhakker/Screens/Admin/layout/admin_home_layout.dart';
import 'package:dhakker/shared/network/local/cash_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../generated/l10n.dart';
import '../../locale_controller.dart';
import '../../theme/dhakker_theme.dart';
import '../Piligram/layout/Home_Layout.dart';
import 'Register_Screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final s = S.of(context);
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );

      final uid = cred.user?.uid;
      if (uid == null) {
        _showSnack(s.authUnknownError, isError: true);
        return;
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        _showSnack(s.authNoProfileDoc, isError: true);
        return;
      }

      final data = userDoc.data() ?? {};
      final isActive = data['isActive'] == true;
      final role = (data['role'] ?? 'pilgrim').toString().toLowerCase();

      if (!isActive) {
        await FirebaseAuth.instance.signOut();
        _showSnack(s.authAccountDisabled, isError: true);
        return;
      }

      _showSnack(s.authLoginSuccess, isError: false);

      if (!mounted) return;

      CashHelper.saveCash(key: 'uid', value: uid);
      if (role == 'admin') {
        CashHelper.saveCash(key: 'userTypeIndex', value: 1);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminHomeLayout()),
        );
      } else {
        CashHelper.saveCash(key: 'userTypeIndex', value: 2);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppHomeLayout()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_mapAuthError(e.code, s), isError: true);
    } catch (_) {
      _showSnack(s.authUnknownError, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showForgotPasswordSheet() async {
    final s = S.of(context);
    final controller = TextEditingController(text: _email.text.trim());
    final key = GlobalKey<FormState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final textColor = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final fieldFill = isDark ? DhakkerColors.bg.withOpacity(.72) : Colors.white;
    final borderColor = (isDark ? Colors.white : Colors.black).withOpacity(isDark ? .08 : .06);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? .45 : .12),
                  blurRadius: 28,
                  offset: const Offset(0, -12),
                ),
              ],
            ),
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: muted.withOpacity(.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          DhakkerColors.gold.withOpacity(.22),
                          DhakkerColors.gold2.withOpacity(.10),
                        ],
                      ),
                      border: Border.all(color: DhakkerColors.gold.withOpacity(.28)),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: DhakkerColors.gold,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.authForgotPasswordTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'AlamirBold',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.authForgotPasswordMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: muted.withOpacity(.95),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      labelText: s.authEmailLabel,
                      hintText: s.authEmailHint,
                      labelStyle: TextStyle(color: muted, fontWeight: FontWeight.w700),
                      hintStyle: TextStyle(color: muted.withOpacity(.7), fontWeight: FontWeight.w600),
                      prefixIcon: Icon(Icons.email_rounded, color: DhakkerColors.gold2.withOpacity(.92)),
                      filled: true,
                      fillColor: fieldFill,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: borderColor, width: 1.1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: DhakkerColors.gold.withOpacity(.85), width: 1.4),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.redAccent.withOpacity(.8), width: 1.2),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.redAccent.withOpacity(.95), width: 1.3),
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
                  const SizedBox(height: 18),
                  _PrimaryButton(
                    text: s.authSendResetLink,
                    enabled: true,
                    onTap: () async {
                      if (!(key.currentState?.validate() ?? false)) return;

                      final email = controller.text.trim();
                      Navigator.pop(context);

                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        await _sendResetPassword(email);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      s.commonCancel,
                      style: const TextStyle(
                        color: DhakkerColors.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );


  }

  Future<void> _sendResetPassword(String email) async {
    final s = S.of(context);

    _showLoadingDialog();

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      Navigator.pop(context);
      await _showResetSuccessDialog(email);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnack(_mapResetError(e.code, s), isError: true);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnack(s.authResetPasswordFailed, isError: true);
    }
  }

  void _showLoadingDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final textColor = isDark ? Colors.white : DhakkerColors.lightText;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: DhakkerColors.gold),
                const SizedBox(height: 18),
                Text(
                  S.of(context).authSendingResetLink,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showResetSuccessDialog(String email) async {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final textColor = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: DhakkerColors.gold.withOpacity(.22)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? .40 : .12),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF38C793).withOpacity(.24),
                        DhakkerColors.gold.withOpacity(.10),
                      ],
                    ),
                    border: Border.all(color: const Color(0xFF38C793).withOpacity(.35)),
                  ),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    color: Color(0xFF38C793),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  s.authResetPasswordSuccessTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'AlamirBold',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s.authResetPasswordSuccessMessage(email),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted.withOpacity(.95),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 22),
                _PrimaryButton(
                  text: s.commonDone,
                  enabled: true,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _mapAuthError(String code, S s) {
    switch (code) {
      case 'invalid-email':
        return s.authInvalidEmail;
      case 'user-not-found':
        return s.authUserNotFound;
      case 'wrong-password':
        return s.authWrongPassword;
      case 'invalid-credential':
        return s.authInvalidCredential;
      case 'user-disabled':
        return s.authUserDisabled;
      case 'too-many-requests':
        return s.authTooManyRequests;
      case 'network-request-failed':
        return s.authNetworkError;
      default:
        return s.authUnknownError;
    }
  }

  String _mapResetError(String code, S s) {
    switch (code) {
      case 'invalid-email':
        return s.authInvalidEmail;
      case 'user-not-found':
        return s.authUserNotFound;
      case 'too-many-requests':
        return s.authTooManyRequests;
      case 'network-request-failed':
        return s.authNetworkError;
      default:
        return s.authResetPasswordFailed;
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
    const gold2 = DhakkerColors.gold2;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;
    final textColor = isDark ? Colors.white : DhakkerColors.lightText;
    final fieldFill = isDark ? DhakkerColors.bg.withOpacity(.72) : Colors.white;
    final borderColor = (isDark ? Colors.white : Colors.black).withOpacity(isDark ? .08 : .06);

    return Scaffold(
      backgroundColor: bg,
      appBar: const _HomeTopBar(onLanguageTap: LocaleController.toggle),
      body: Container(
        color: bg,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 14),
                _TopBrand(muted: muted, textColor: textColor),
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
                          s.authLoginTitle,
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
                          s.authLoginSubtitle,
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
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                          decoration: _inputDecoration(
                            context: context,
                            label: s.authEmailLabel,
                            hint: s.authEmailHint,
                            icon: Icons.email_rounded,
                            fieldFill: fieldFill,
                            borderColor: borderColor,
                            muted: muted,
                            gold: gold,
                            gold2: gold2,
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
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                          decoration: _inputDecoration(
                            context: context,
                            label: s.authPasswordLabel,
                            hint: s.authPasswordHint,
                            icon: Icons.lock_rounded,
                            fieldFill: fieldFill,
                            borderColor: borderColor,
                            muted: muted,
                            gold: gold,
                            gold2: gold2,
                            suffix: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: muted.withOpacity(.9),
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
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: _loading ? null : _showForgotPasswordSheet,
                            child: Text(
                              s.authForgotPassword,
                              style: const TextStyle(
                                color: DhakkerColors.gold,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _PrimaryButton(
                          text: _loading ? s.authLoading : s.authLoginButton,
                          enabled: !_loading,
                          onTap: _login,
                        ),
                        const SizedBox(height: 14),
                        _CreateAccountRow(
                          muted: muted,
                          textColor: textColor,
                          onCreate: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String label,
    required String hint,
    required IconData icon,
    required Color fieldFill,
    required Color borderColor,
    required Color muted,
    required Color gold,
    required Color gold2,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: muted.withOpacity(.95), fontWeight: FontWeight.w700),
      hintStyle: TextStyle(color: muted.withOpacity(.72), fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, color: gold2.withOpacity(.92)),
      suffixIcon: suffix,
      filled: true,
      fillColor: fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor, width: 1.1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: gold.withOpacity(.85), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.redAccent.withOpacity(.8), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.redAccent.withOpacity(.95), width: 1.3),
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
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';
    final s = S.of(context);

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

  const _LangPill({
    required this.label,
    required this.onTap,
  });

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

  const _TopBrand({
    required this.muted,
    required this.textColor,
  });

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

class _CreateAccountRow extends StatelessWidget {
  final Color muted;
  final Color textColor;
  final VoidCallback onCreate;

  const _CreateAccountRow({
    required this.muted,
    required this.textColor,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          s.authNoAccount,
          style: TextStyle(
            color: muted.withOpacity(.95),
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: onCreate,
          style: TextButton.styleFrom(
            foregroundColor: DhakkerColors.gold,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          child: Text(
            s.authCreateAccount,
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