import 'package:flutter/material.dart';

/// ينتقل للشاشة ويمسح كل ما قبلها من المكدس (تسجيل دخول/خروج ونحوه).
void nextWidget({
  required BuildContext context,
  required Widget screen,
}) {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => screen),
    (route) => false,
  );
}

/// ينتقل للشاشة مع إبقاء الشاشة الحالية في المكدس (رجوع طبيعي).
void goToScreen({
  required BuildContext context,
  required Widget screen,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => screen),
  );
}
