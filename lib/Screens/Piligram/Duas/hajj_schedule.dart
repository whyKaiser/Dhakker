/// الجدول الزمني لأيام الحج (٨–١٣ ذو الحجة) — محتوى معلوماتي مبسّط.
///
/// لا يُقصد به الإفتاء؛ في المسائل المختلف فيها يُرجع لعالم أو المرشد الميداني.
library;

/// يوم واحد من أيام الحج: تسميته وأبرز أعماله بالترتيب.
class HajjDay {
  final String dayAr;
  final String dayEn;
  final String titleAr;
  final String titleEn;
  final List<String> tasksAr;
  final List<String> tasksEn;

  const HajjDay({
    required this.dayAr,
    required this.dayEn,
    required this.titleAr,
    required this.titleEn,
    required this.tasksAr,
    required this.tasksEn,
  });

  String day(String lang) => lang == 'ar' ? dayAr : dayEn;
  String title(String lang) => lang == 'ar' ? titleAr : titleEn;
  List<String> tasks(String lang) => lang == 'ar' ? tasksAr : tasksEn;
}

const List<HajjDay> hajjSchedule = [
  HajjDay(
    dayAr: '٨ ذو الحجة',
    dayEn: '8 Dhul-Hijjah',
    titleAr: 'يوم التروية',
    titleEn: 'Day of Tarwiyah',
    tasksAr: [
      'الإحرام بالحج من مكان نزولك مع التلبية.',
      'التوجّه إلى منى قبل الظهر.',
      'صلاة الظهر والعصر والمغرب والعشاء والفجر بمنى، كل صلاة في وقتها قصرًا بلا جمع.',
      'المبيت بمنى ليلة التاسع.',
    ],
    tasksEn: [
      'Enter Ihram for Hajj from your place with Talbiyah.',
      'Head to Mina before noon.',
      'Pray Dhuhr, Asr, Maghrib, Isha, and Fajr at Mina, each shortened in its own time.',
      'Spend the night at Mina.',
    ],
  ),
  HajjDay(
    dayAr: '٩ ذو الحجة',
    dayEn: '9 Dhul-Hijjah',
    titleAr: 'يوم عرفة',
    titleEn: 'Day of Arafah',
    tasksAr: [
      'التوجّه إلى عرفة بعد طلوع الشمس.',
      'الجمع بين الظهر والعصر قصرًا وقت الظهر.',
      'الإكثار من الدعاء والذكر إلى الغروب (هذا ركن الحج الأعظم).',
      'بعد الغروب: التوجّه إلى مزدلفة.',
      'بمزدلفة: الجمع بين المغرب والعشاء، والمبيت، وجمع الحصى.',
    ],
    tasksEn: [
      'Head to Arafah after sunrise.',
      'Combine Dhuhr and Asr shortened at Dhuhr time.',
      'Supplicate abundantly until sunset (the greatest pillar of Hajj).',
      'After sunset: head to Muzdalifah.',
      'At Muzdalifah: combine Maghrib and Isha, stay overnight, gather pebbles.',
    ],
  ),
  HajjDay(
    dayAr: '١٠ ذو الحجة',
    dayEn: '10 Dhul-Hijjah',
    titleAr: 'يوم النحر (العيد)',
    titleEn: 'Day of Nahr (Eid)',
    tasksAr: [
      'رمي جمرة العقبة الكبرى بسبع حصيات مع التكبير.',
      'ذبح الهدي (للمتمتّع والقارن).',
      'الحلق أو التقصير (والحلق أفضل للرجل).',
      'طواف الإفاضة ثم السعي.',
      'بهذا يتم التحلّل الأكبر.',
    ],
    tasksEn: [
      'Stone Jamrat al-Aqabah with seven pebbles, with takbir.',
      'Sacrifice the Hady (for Tamattu\' and Qiran pilgrims).',
      'Shave or trim the hair (shaving is better for men).',
      'Perform Tawaf al-Ifadah then Sa\'i.',
      'With this the major exit from Ihram is complete.',
    ],
  ),
  HajjDay(
    dayAr: '١١ ذو الحجة',
    dayEn: '11 Dhul-Hijjah',
    titleAr: 'أول أيام التشريق',
    titleEn: 'First Day of Tashreeq',
    tasksAr: [
      'رمي الجمرات الثلاث بعد الزوال (الصغرى ثم الوسطى ثم الكبرى).',
      'سبع حصيات لكل جمرة مع التكبير.',
      'المبيت بمنى.',
    ],
    tasksEn: [
      'Stone the three Jamarat after midday (small, middle, large).',
      'Seven pebbles for each, with takbir.',
      'Spend the night at Mina.',
    ],
  ),
  HajjDay(
    dayAr: '١٢ ذو الحجة',
    dayEn: '12 Dhul-Hijjah',
    titleAr: 'ثاني أيام التشريق',
    titleEn: 'Second Day of Tashreeq',
    tasksAr: [
      'رمي الجمرات الثلاث بعد الزوال.',
      'من أراد التعجّل يخرج من منى قبل الغروب.',
      'من تأخّر يبيت ليلة الثالث عشر.',
    ],
    tasksEn: [
      'Stone the three Jamarat after midday.',
      'Those hastening may leave Mina before sunset.',
      'Those staying spend the night for the 13th.',
    ],
  ),
  HajjDay(
    dayAr: '١٣ ذو الحجة',
    dayEn: '13 Dhul-Hijjah',
    titleAr: 'ثالث أيام التشريق',
    titleEn: 'Third Day of Tashreeq',
    tasksAr: [
      'رمي الجمرات الثلاث بعد الزوال (لمن تأخّر).',
      'طواف الوداع عند إرادة مغادرة مكة.',
      'يكون الوداع آخر العهد بالبيت.',
    ],
    tasksEn: [
      'Stone the three Jamarat after midday (for those who stayed).',
      'Perform the Farewell Tawaf when leaving Makkah.',
      'It should be the last act at the Sacred House.',
    ],
  ),
];
