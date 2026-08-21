/// عرض المحتوى بحسب تصنيفه، بحيث لا يختلط الإرشاد بالدعاء ولا يُنسب دعاء
/// عام إلى موضع لم يخصّه به المصدر.
///
/// القاعدتان اللتان تفرضهما هذه الملفات:
///   1. [SupplicationContentKind.proceduralGuidance] لا يُعرض أبدًا تحت
///      عنوان «دعاء»، ولا يُعرض له زر تشغيل صوتي — فهو حكم أو إرشاد، لا نص
///      يُتلىٰ. يُعرض في [GuidanceCard] المنفصلة.
///   2. كل ما ليس [SupplicationContentKind.specificText] يحمل وسمًا ظاهرًا
///      يقول إنه عام وغير مخصوص بالموضع.
///   3. [SupplicationContentKind.contextualEvidence] أثر مرويّ يُساق
///      للفائدة لا للترديد. يُعرض في [ContextualEvidenceCard] بنسبته
///      ومصدره، بلا زر تشغيل — لا كدعاء (فيردّده الحاج) ولا كإرشاد (فيبدو
///      صياغةً إدارية لا نصًّا مرويًّا).
library;

import 'package:flutter/material.dart';

import '../../Home/models/supplication_model.dart';

/// وسم صغير يوضّح تصنيف المحتوى. لا يجوز إخفاؤه للأنواع العامة.
class ContentKindBadge extends StatelessWidget {
  const ContentKindBadge({super.key, required this.kind});

  final SupplicationContentKind kind;

  Color get _color {
    switch (kind) {
      case SupplicationContentKind.specificText:
        return const Color(0xFF2E7D32);
      case SupplicationContentKind.proceduralGuidance:
        return const Color(0xFF1565C0);
      case SupplicationContentKind.contextualEvidence:
        return const Color(0xFF5D4037);
      case SupplicationContentKind.mosqueEntry:
        return const Color(0xFF6A1B9A);
      case SupplicationContentKind.generalDua:
      case SupplicationContentKind.generalDhikr:
        return const Color(0xFF8D6E00);
    }
  }

  IconData get _icon {
    switch (kind) {
      case SupplicationContentKind.specificText:
        return Icons.place_rounded;
      case SupplicationContentKind.proceduralGuidance:
        return Icons.info_outline_rounded;
      case SupplicationContentKind.contextualEvidence:
        return Icons.menu_book_rounded;
      case SupplicationContentKind.mosqueEntry:
        return Icons.mosque_rounded;
      case SupplicationContentKind.generalDua:
      case SupplicationContentKind.generalDhikr:
        return Icons.public_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 13, color: _color),
          const SizedBox(width: 4),
          Text(
            kind.badgeAr(),
            style: TextStyle(
                color: _color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// وسم صفة الاستعمال — يُعرض إلى جانب [ContentKindBadge]، لا بدلًا منه.
///
/// يظهر **فقط** حين يصف المصدر الاستعمال. غيابه لا يعني وجوبًا ولا يُعرض
/// له أي وصف مقابل: لا «واجب» ولا «أساسي» ولا «لازم». النص غير الموصوف
/// يُعرض كما ورد، بلا حكم لم يقله المصدر.
class UsageQualifierBadge extends StatelessWidget {
  const UsageQualifierBadge({
    super.key,
    required this.qualifier,
    this.isArabic = true,
  });

  final SupplicationUsageQualifier? qualifier;
  final bool isArabic;

  static const Color _color = Color(0xFF00695C);

  @override
  Widget build(BuildContext context) {
    final q = qualifier;
    if (q == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_circle_outline_rounded, size: 13, color: _color),
          const SizedBox(width: 4),
          Text(
            isArabic ? q.badgeAr() : q.badgeEn(),
            style: const TextStyle(
                color: _color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// أسطر «أخرجه…» أسفل بطاقة الأثر أو الإرشاد.
///
/// تُعرض في هاتين البطاقتين فقط: بطاقة الدعاء تعرض نصًّا يقوله الحاج، وسردُ
/// تخريجٍ تحته يحوّل الذكر إلى مُدخل مرجعي. ولا تُعرض `reviewNotes` أبدًا —
/// فهي ملاحظات مراجعة إدارية، لا محتوى موجّه للحاج.
class SourceReferenceList extends StatelessWidget {
  const SourceReferenceList({
    super.key,
    required this.references,
    required this.accent,
    this.textColor,
  });

  final List<SourceReference> references;
  final Color accent;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    if (references.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'عزاه المصدر إلى:',
          style: TextStyle(
              color: accent, fontSize: 11, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        for (final r in references)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '• ${r.display}',
              style: TextStyle(
                color: textColor?.withOpacity(0.8),
                fontSize: 11.5,
                height: 1.6,
              ),
            ),
          ),
      ],
    );
  }
}

/// بطاقة الإرشاد — منفصلة تمامًا عن بطاقات الأدعية.
///
/// لا تحمل زر تشغيل ولا تُسمّىٰ «دعاء»، لأن محتواها حكم أو توجيه عملي مثل
/// «لا يصح الطواف من داخل الحِجْر» أو «لا تُزاحم على الركن».
class GuidanceCard extends StatelessWidget {
  const GuidanceCard({
    super.key,
    required this.title,
    required this.body,
    this.attribution,
    this.references = const [],
    this.isPropheticDirective = false,
    this.cardColor,
    this.textColor,
  });

  final String title;
  final String body;

  /// من قاله وأين خُرِّج. يُعرض تحت النص حين يكون الإرشاد منقولًا لا مصوغًا،
  /// فلا يظهر توجيه النبي ﷺ كأنه صياغة إدارية.
  final String? attribution;

  /// ما عزا إليه المصدر. عرض فقط: لا يجعل الإرشاد نصًّا يُتلىٰ.
  final List<SourceReference> references;

  /// هل هذا الإرشاد حديث نبوي بلفظه؟ يغيّر العنوان الظاهر وحده — لا يمنحه
  /// زر تشغيل ولا يجعله ذكرًا يُتلىٰ.
  final bool isPropheticDirective;

  final Color? cardColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF1565C0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(isPropheticDirective ? 'توجيه نبوي' : 'إرشاد',
                  style: const TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          if (title.trim().isNotEmpty) ...[
            Text(title,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    height: 1.6)),
            const SizedBox(height: 6),
          ],
          Text(body, style: TextStyle(color: textColor, height: 1.9)),
          if ((attribution ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(attribution!.trim(),
                style: TextStyle(
                    color: textColor?.withOpacity(0.75),
                    fontSize: 11.5,
                    height: 1.7,
                    fontStyle: FontStyle.italic)),
          ],
          SourceReferenceList(
              references: references, accent: accent, textColor: textColor),
          const SizedBox(height: 10),
          const ContentKindBadge(
              kind: SupplicationContentKind.proceduralGuidance),
        ],
      ),
    );
  }
}

/// بطاقة الأثر الموثّق — نص مرويّ يُساق للفائدة، لا للترديد.
///
/// لا تحمل زر تشغيل، ولا تُسمّىٰ «دعاء». وتعرض النسبة والتخريج دائمًا،
/// لأن قيمة هذا النص في كونه مرويًّا بإسناد: بطاقةٌ تخفي «قاله عمر رضي الله
/// عنه، أخرجه البخاري ومسلم» تكون قد أسقطت سبب وجوده.
class ContextualEvidenceCard extends StatelessWidget {
  const ContextualEvidenceCard({
    super.key,
    required this.title,
    required this.body,
    required this.attribution,
    this.references = const [],
    this.cardColor,
    this.textColor,
  });

  final String title;
  final String body;

  /// من قاله وأين خُرِّج — إلزامي في هذه البطاقة، بخلاف [GuidanceCard].
  final String attribution;

  /// ما عزا إليه المصدر من كتب الحديث والآثار.
  final List<SourceReference> references;

  final Color? cardColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF5D4037);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 16, color: accent),
              SizedBox(width: 6),
              Text('أثر موثّق',
                  style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          if (title.trim().isNotEmpty) ...[
            Text(title,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    height: 1.6)),
            const SizedBox(height: 6),
          ],
          Text(body, style: TextStyle(color: textColor, height: 1.9)),
          const SizedBox(height: 8),
          Text(attribution.trim(),
              style: TextStyle(
                  color: textColor?.withOpacity(0.75),
                  fontSize: 11.5,
                  height: 1.7,
                  fontStyle: FontStyle.italic)),
          SourceReferenceList(
              references: references, accent: accent, textColor: textColor),
          const SizedBox(height: 10),
          const ContentKindBadge(
              kind: SupplicationContentKind.contextualEvidence),
        ],
      ),
    );
  }
}

/// يقسم قائمة سجلات إلى (أدعية/أذكار) و(إرشادات) و(آثار موثّقة)، حفاظًا على الفصل في كل
/// شاشة تعرضها. أي شاشة تعرض القائمة الخام دون هذا التقسيم تكون قد خالفت
/// القاعدة.
class SupplicationPartition {
  const SupplicationPartition({
    required this.recitable,
    required this.guidance,
    required this.evidence,
  });

  final List<SupplicationModel> recitable;
  final List<SupplicationModel> guidance;

  /// الآثار المرويّة للفائدة — بطاقتها الخاصة، ولا تُحسب دعاءً.
  final List<SupplicationModel> evidence;

  factory SupplicationPartition.of(List<SupplicationModel> items) {
    return SupplicationPartition(
      recitable: items.where((e) => e.contentKind.belongsInDuaSection).toList(),
      guidance: items
          .where((e) =>
              e.contentKind == SupplicationContentKind.proceduralGuidance)
          .toList(),
      evidence: items
          .where((e) =>
              e.contentKind == SupplicationContentKind.contextualEvidence)
          .toList(),
    );
  }
}
