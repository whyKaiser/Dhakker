import 'package:flutter/material.dart';

import '../../../theme/dhakker_theme.dart';

/// شاشة «عن التطبيق وسياسة الخصوصية».
/// مطلوبة للنشر (Google Play والجهات الرسمية) لأن التطبيق يجمع بيانات موقع.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final bg = isDark ? DhakkerColors.bg : DhakkerColors.lightBg;
    final card = isDark ? DhakkerColors.card : DhakkerColors.lightCard;
    final textColor = isDark ? Colors.white : DhakkerColors.lightText;
    final muted = isDark ? DhakkerColors.muted : DhakkerColors.lightMuted;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text(isAr ? 'عن التطبيق والخصوصية' : 'About & Privacy',
              style: const TextStyle(color: DhakkerColors.gold, fontWeight: FontWeight.w900)),
          iconTheme: const IconThemeData(color: DhakkerColors.gold),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 78, height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DhakkerColors.gold.withOpacity(.12),
                        border: Border.all(color: DhakkerColors.gold.withOpacity(.4), width: 1.4),
                      ),
                      child: const Icon(Icons.mosque_rounded, color: DhakkerColors.gold, size: 38),
                    ),
                    const SizedBox(height: 12),
                    Text('ذَكِّر',
                        style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(isAr ? 'الإصدار $_appVersion' : 'Version $_appVersion',
                        style: TextStyle(color: muted, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _section(card, textColor, muted, isAr ? 'عن التطبيق' : 'About',
                  isAr
                      ? 'تطبيق «ذكّر» مرشد ذكي لحجّاج ومعتمري بيت الله الحرام. يكتشف موقعك '
                          'داخل المشاعر تلقائياً ويعرض الدعاء المناسب للمكان، ويعدّ أشواط الطواف '
                          'والسعي، ويوفّر مساعداً صوتياً بعدة لغات، مع تنبيهات سلامة من الإدارة.'
                      : '"Dhakker" is a smart companion for Hajj and Umrah pilgrims. It detects '
                          'your location within the holy sites and shows the matching supplication, '
                          'counts your Tawaf and Sa\'i rounds, offers a multilingual voice assistant, '
                          'and delivers safety alerts from the administration.'),

              _section(card, textColor, muted, isAr ? 'البيانات التي نجمعها' : 'Data We Collect',
                  isAr
                      ? '• الموقع الجغرافي: يُستخدم فقط لتحديد منطقة المناسك وعرض الدعاء وعدّ '
                          'الأشواط. تُعالَج الإحداثيات على جهازك ولا نخزّن مسار تنقّلك.\n'
                          '• بريدك الإلكتروني: لإنشاء الحساب وتسجيل الدخول.\n'
                          '• منطقتك الحالية: تُحدَّث لإدارة الحشود والسلامة (دون كشف هويتك لبقية الحجّاج).'
                      : '• Location: used only to detect the ritual zone, show supplications, and '
                          'count rounds. Coordinates are processed on your device; we do not store '
                          'your movement history.\n'
                          '• Email: for account creation and sign-in.\n'
                          '• Current zone: updated for crowd management and safety (without revealing '
                          'your identity to other pilgrims).'),

              _section(card, textColor, muted, isAr ? 'كيف نحمي بياناتك' : 'How We Protect Your Data',
                  isAr
                      ? '• تُخزَّن البيانات في خوادم Firebase الآمنة من Google.\n'
                          '• قواعد صارمة تمنع أي مستخدم من الوصول لبيانات غيره.\n'
                          '• لا نبيع بياناتك ولا نشاركها مع أطراف إعلانية.'
                      : '• Data is stored on Google\'s secure Firebase servers.\n'
                          '• Strict rules prevent any user from accessing others\' data.\n'
                          '• We never sell your data or share it with advertisers.'),

              _section(card, textColor, muted, isAr ? 'صلاحياتك' : 'Your Rights',
                  isAr
                      ? 'يمكنك إيقاف خدمة الموقع في أي وقت من الإعدادات، أو طلب حذف حسابك '
                          'وبياناتك عبر التواصل معنا.'
                      : 'You can disable location services anytime from Settings, or request '
                          'deletion of your account and data by contacting us.'),

              _section(card, textColor, muted, isAr ? 'تواصل معنا' : 'Contact Us',
                  'support@dhakker.app'),

              const SizedBox(height: 8),
              Text(
                isAr
                    ? 'باستخدامك التطبيق فإنك توافق على سياسة الخصوصية أعلاه.'
                    : 'By using the app you agree to the privacy policy above.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 12.5, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(Color card, Color textColor, Color muted, String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DhakkerColors.gold.withOpacity(.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: DhakkerColors.gold, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(body,
              style: TextStyle(color: textColor.withOpacity(.92), fontSize: 14, height: 1.7)),
        ],
      ),
    );
  }
}
