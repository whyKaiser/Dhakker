/// بيانات دليل المناسك خطوة بخطوة (عربي/إنجليزي).
///
/// محتوى تعليمي مبسّط للمناسك المتّفق عليها. في المسائل الفقهية المختلف فيها
/// يُنصح بسؤال عالم أو المرشد الميداني — لا يُقصد بهذا الدليل الإفتاء.
library;

/// منسك واحد: عنوان + وصف موجز + خطوات مرتّبة + دعاء مأثور (اختياري).
class ManasikRitual {
  final String id;
  final String titleAr;
  final String titleEn;
  final String summaryAr;
  final String summaryEn;
  final List<String> stepsAr;
  final List<String> stepsEn;
  final String? duaAr;
  final String? duaEn;
  final bool isHajjOnly; // خاص بالحج (لا يلزم في العمرة)

  const ManasikRitual({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.summaryAr,
    required this.summaryEn,
    required this.stepsAr,
    required this.stepsEn,
    this.duaAr,
    this.duaEn,
    this.isHajjOnly = false,
  });

  String title(String lang) => lang == 'ar' ? titleAr : titleEn;
  String summary(String lang) => lang == 'ar' ? summaryAr : summaryEn;
  List<String> steps(String lang) => lang == 'ar' ? stepsAr : stepsEn;
  String? dua(String lang) => lang == 'ar' ? duaAr : duaEn;
}

/// قائمة المناسك بالترتيب الزمني للعمرة ثم الحج.
const List<ManasikRitual> manasikRituals = [
  ManasikRitual(
    id: 'ihram',
    titleAr: 'الإحرام',
    titleEn: 'Ihram',
    summaryAr: 'نيّة الدخول في النسك من الميقات مع التلبية.',
    summaryEn: 'Entering the state of pilgrimage from the Miqat with Talbiyah.',
    stepsAr: [
      'الاغتسال والتطيّب في البدن قبل الإحرام (لا في ثوب الإحرام).',
      'لبس ثوبي الإحرام للرجل (إزار ورداء أبيضين)، والمرأة تُحرم بثيابها الساترة.',
      'النية بالقلب عند الميقات: عمرة أو حج، والتلفظ: «لبيك عمرة» أو «لبيك حجًّا».',
      'الإكثار من التلبية ورفع الصوت بها للرجال.',
      'اجتناب محظورات الإحرام: الطيب، حلق الشعر، تقليم الأظافر، الجدال.',
    ],
    stepsEn: [
      'Perform ghusl (ritual bath) and apply scent to the body before Ihram (not on the garments).',
      'Men wear two white unstitched cloths; women wear modest ordinary clothing.',
      'Make the intention at the Miqat and say: "Labbayk Umrah" or "Labbayk Hajj".',
      'Recite the Talbiyah frequently (men aloud).',
      'Avoid the prohibitions of Ihram: perfume, cutting hair/nails, arguing.',
    ],
    duaAr:
        'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لا شَرِيكَ لَكَ لَبَّيْكَ، إِنَّ الحَمْدَ وَالنِّعْمَةَ لَكَ وَالمُلْكَ، لا شَرِيكَ لَكَ.',
    duaEn:
        'Labbayk Allahumma labbayk, labbayk la sharika laka labbayk, innal-hamda wan-ni\'mata laka wal-mulk, la sharika lak.',
  ),
  ManasikRitual(
    id: 'tawaf',
    titleAr: 'الطواف',
    titleEn: 'Tawaf',
    summaryAr: 'سبعة أشواط حول الكعبة تبدأ وتنتهي عند الحجر الأسود.',
    summaryEn:
        'Seven circuits around the Kaaba, starting and ending at the Black Stone.',
    stepsAr: [
      'البدء من محاذاة الحجر الأسود، وجعل الكعبة عن يسارك.',
      'استلام الحجر الأسود أو الإشارة إليه مع التكبير عند بداية كل شوط.',
      'الاضطباع للرجل (كشف الكتف الأيمن) طوال الطواف، والرَّمَل في الأشواط الثلاثة الأولى.',
      'الدعاء بما تيسّر؛ لا يلزم دعاء محدّد لكل شوط.',
      'بعد سبعة أشواط: صلاة ركعتين خلف مقام إبراهيم إن تيسّر.',
    ],
    stepsEn: [
      'Begin in line with the Black Stone, keeping the Kaaba on your left.',
      'Touch or point to the Black Stone saying "Allahu Akbar" at the start of each circuit.',
      'Men uncover the right shoulder (idtiba\') and walk briskly (raml) in the first three circuits.',
      'Supplicate freely; no specific dua is required for each circuit.',
      'After seven circuits, pray two rak\'ahs behind Maqam Ibrahim if possible.',
    ],
    duaAr:
        'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ.',
    duaEn:
        'Rabbana atina fid-dunya hasanah wa fil-akhirati hasanah wa qina \'adhab an-nar.',
  ),
  ManasikRitual(
    id: 'sai',
    titleAr: 'السعي',
    titleEn: "Sa'i",
    summaryAr: 'سبعة أشواط بين الصفا والمروة تبدأ بالصفا.',
    summaryEn: 'Seven trips between Safa and Marwah, starting at Safa.',
    stepsAr: [
      'الصعود على الصفا واستقبال القبلة والتكبير والدعاء.',
      'المشي إلى المروة، ويُسرع الرجل بين العَلَمين الأخضرين.',
      'كل ذهاب أو إياب يُحسب شوطًا واحدًا؛ المجموع سبعة.',
      'يبدأ العدّ من الصفا وينتهي بالمروة.',
      'الدعاء بما تيسّر أثناء السعي.',
    ],
    stepsEn: [
      'Ascend Safa, face the Qibla, say takbir and supplicate.',
      'Walk to Marwah; men jog between the two green markers.',
      'Each one-way trip counts as one round; seven in total.',
      'Counting starts at Safa and ends at Marwah.',
      'Supplicate freely during the Sa\'i.',
    ],
    duaAr:
        'إِنَّ الصَّفَا وَالمَرْوَةَ مِنْ شَعَائِرِ اللَّهِ، أَبْدَأُ بِمَا بَدَأَ اللَّهُ بِهِ.',
    duaEn:
        'Inna as-Safa wal-Marwata min sha\'a\'irillah. Abda\'u bima bada\'allahu bih.',
  ),
  ManasikRitual(
    id: 'halq',
    titleAr: 'الحلق أو التقصير',
    titleEn: 'Halq or Taqsir',
    summaryAr: 'حلق الشعر أو تقصيره للتحلّل من النسك.',
    summaryEn: 'Shaving or trimming the hair to exit the state of Ihram.',
    stepsAr: [
      'الرجل يحلق رأسه كاملًا (أفضل) أو يقصّر من جميع جوانبه.',
      'المرأة تقصّر قدر أُنملة من أطراف شعرها فقط.',
      'بهذا تتم العمرة ويحلّ المُعتمر من إحرامه.',
    ],
    stepsEn: [
      'Men shave the entire head (preferred) or trim from all sides.',
      'Women trim about a fingertip\'s length from the ends of the hair.',
      'With this the Umrah is complete and Ihram ends.',
    ],
  ),
  ManasikRitual(
    id: 'arafah',
    titleAr: 'الوقوف بعرفة',
    titleEn: 'Standing at Arafah',
    summaryAr: 'ركن الحج الأعظم في اليوم التاسع من ذي الحجة.',
    summaryEn: 'The greatest pillar of Hajj, on the 9th of Dhul-Hijjah.',
    isHajjOnly: true,
    stepsAr: [
      'الوقوف بعرفة من زوال شمس يوم التاسع إلى غروبها.',
      'الجمع بين الظهر والعصر قصرًا في وقت الظهر.',
      'الإكثار من الدعاء والذكر مستقبلًا القبلة رافعًا يديك.',
      'عدم مغادرة عرفة قبل غروب الشمس.',
    ],
    stepsEn: [
      'Remain at Arafah from midday on the 9th until sunset.',
      'Combine and shorten Dhuhr and Asr at the time of Dhuhr.',
      'Supplicate and remember Allah abundantly, facing the Qibla.',
      'Do not leave Arafah before sunset.',
    ],
    duaAr:
        'لا إِلَهَ إِلّا اللَّهُ وَحْدَهُ لا شَرِيكَ لَهُ، لَهُ المُلْكُ وَلَهُ الحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
    duaEn:
        'La ilaha illallahu wahdahu la sharika lah, lahul-mulku wa lahul-hamd, wa huwa \'ala kulli shay\'in qadir.',
  ),
  ManasikRitual(
    id: 'muzdalifah',
    titleAr: 'المبيت بمزدلفة',
    titleEn: 'Muzdalifah',
    summaryAr: 'المبيت بمزدلفة ليلة العيد وجمع الحصى.',
    summaryEn: 'Spending the night at Muzdalifah and gathering pebbles.',
    isHajjOnly: true,
    stepsAr: [
      'الانتقال من عرفة إلى مزدلفة بعد الغروب.',
      'الجمع بين المغرب والعشاء قصرًا عند الوصول.',
      'المبيت بمزدلفة حتى صلاة الفجر.',
      'جمع حصى الجمرات (يكفي جمعها من أي مكان طاهر).',
    ],
    stepsEn: [
      'Move from Arafah to Muzdalifah after sunset.',
      'Combine and shorten Maghrib and Isha upon arrival.',
      'Spend the night until the Fajr prayer.',
      'Gather pebbles for the stoning (from any clean place).',
    ],
  ),
  ManasikRitual(
    id: 'jamarat',
    titleAr: 'رمي الجمرات',
    titleEn: 'Stoning the Jamarat',
    summaryAr: 'رمي الجمرات أيام التشريق بدءًا بجمرة العقبة يوم العيد.',
    summaryEn: 'Stoning the pillars during the days of Tashreeq.',
    isHajjOnly: true,
    stepsAr: [
      'يوم العيد: رمي جمرة العقبة الكبرى بسبع حصيات مع التكبير مع كل حصاة.',
      'أيام التشريق: رمي الجمرات الثلاث (الصغرى ثم الوسطى ثم الكبرى) بسبع حصيات لكلٍّ.',
      'يكون الرمي بعد الزوال في أيام التشريق.',
      'الترتيب والدعاء بعد الصغرى والوسطى مستحب.',
    ],
    stepsEn: [
      'On Eid day: stone Jamrat al-Aqabah with seven pebbles, saying takbir with each.',
      'Days of Tashreeq: stone all three (small, middle, large) with seven pebbles each.',
      'Stoning is after midday during the days of Tashreeq.',
      'Keep the order; supplication after the small and middle pillars is recommended.',
    ],
  ),
  ManasikRitual(
    id: 'tawaf_ifadah',
    titleAr: 'طواف الإفاضة',
    titleEn: 'Tawaf al-Ifadah',
    summaryAr: 'ركن من أركان الحج يُؤدّى بعد الوقوف بعرفة.',
    summaryEn: 'A pillar of Hajj performed after standing at Arafah.',
    isHajjOnly: true,
    stepsAr: [
      'طواف سبعة أشواط حول الكعبة كطواف العمرة.',
      'يكون يوم العيد أو بعده من أيام التشريق.',
      'يتبعه سعي الحج لمن لم يسعَ، أو لمن كان متمتعًا.',
    ],
    stepsEn: [
      'Seven circuits around the Kaaba, like the Umrah Tawaf.',
      'Performed on Eid day or during the days of Tashreeq.',
      'Followed by the Sa\'i of Hajj for those who have not done it.',
    ],
  ),
  ManasikRitual(
    id: 'tawaf_wada',
    titleAr: 'طواف الوداع',
    titleEn: 'Farewell Tawaf',
    summaryAr: 'آخر ما يفعله الحاج قبل مغادرة مكة.',
    summaryEn: 'The last act before leaving Makkah.',
    stepsAr: [
      'طواف سبعة أشواط حول الكعبة عند إرادة السفر.',
      'يكون آخر العهد بالبيت.',
      'يسقط عن الحائض والنفساء.',
    ],
    stepsEn: [
      'Seven circuits around the Kaaba when about to travel.',
      'It should be the last act at the Sacred House.',
      'Waived for menstruating and postpartum women.',
    ],
  ),
];
