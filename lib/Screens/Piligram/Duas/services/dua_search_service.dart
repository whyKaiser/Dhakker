import '../../home/models/supplication_model.dart';
import '../../home/models/zone_model.dart';

class DuaSearchItem {
  final SupplicationModel dua;
  final ZoneModel? zone;

  const DuaSearchItem({
    required this.dua,
    required this.zone,
  });
}

class DuaSearchService {
  const DuaSearchService();

  String normalize(String value) {
    var text = value.toLowerCase().trim();

    const arabicMap = {
      'أ': 'ا',
      'إ': 'ا',
      'آ': 'ا',
      'ة': 'ه',
      'ى': 'ي',
      'ؤ': 'و',
      'ئ': 'ي',
    };

    arabicMap.forEach((key, replacement) {
      text = text.replaceAll(key, replacement);
    });

    final tashkeel = RegExp(r'[\u0617-\u061A\u064B-\u0652]');
    text = text.replaceAll(tashkeel, '');
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    return text;
  }

  List<DuaSearchItem> search({
    required List<DuaSearchItem> items,
    required String query,
    required String langCode,
  }) {
    final normalizedQuery = normalize(query);

    if (normalizedQuery.isEmpty) {
      return items;
    }

    final scored = <MapEntry<DuaSearchItem, int>>[];

    for (final item in items) {
      final title = normalize(item.dua.titleByLanguage(langCode));
      final text = normalize(item.dua.textByLanguage(langCode));
      final zoneName = normalize(item.zone?.displayName(langCode) ?? '');

      int score = 0;

      if (title.contains(normalizedQuery)) score += 5;
      if (zoneName.contains(normalizedQuery)) score += 4;
      if (text.contains(normalizedQuery)) score += 2;

      final queryWords = normalizedQuery.split(' ');
      for (final word in queryWords) {
        if (word.isEmpty) continue;
        if (title.contains(word)) score += 2;
        if (zoneName.contains(word)) score += 2;
        if (text.contains(word)) score += 1;
      }

      if (score > 0) {
        scored.add(MapEntry(item, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }
}