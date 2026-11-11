import 'surah.dart';
import 'surah_filter.dart';

/// Searches and filters the catalogue without any UI or storage dependency.
///
/// A numeric query matches the Surah number exactly. Text queries are matched
/// against the Arabic name, transliteration, and English meaning.
List<Surah> searchSurahs(
  Iterable<Surah> surahs, {
  String query = '',
  SurahFilter filter = SurahFilter.all,
}) {
  final trimmedQuery = query.trim();
  final numericQuery = int.tryParse(trimmedQuery);
  final normalizedQuery = normalizeSearchText(trimmedQuery);

  return surahs
      .where((surah) {
        if (!filter.matches(surah)) {
          return false;
        }
        if (trimmedQuery.isEmpty) {
          return true;
        }
        if (numericQuery != null) {
          return surah.number == numericQuery;
        }
        if (normalizedQuery.isEmpty) {
          return true;
        }

        final searchableText = normalizeSearchText(
          '${surah.transliteration} ${surah.englishMeaning} ${surah.arabicName}',
        );
        return searchableText.contains(normalizedQuery);
      })
      .toList(growable: false);
}

/// Normalizes text for forgiving search across Arabic and Latin spellings.
String normalizeSearchText(String value) {
  var text = value.toLowerCase().trim();

  // Remove Arabic diacritics and tatweel.
  text = text.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '');
  text = text.replaceAll('\u0640', '');

  // Fold common Arabic letter variants.
  text = text
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ٱ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ء', '');

  // Keep only letters and digits, so spaces and punctuation do not matter.
  text = text.replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]'), '');

  // Fold common transliteration long vowels.
  text = text
      .replaceAll('aa', 'a')
      .replaceAll('ee', 'i')
      .replaceAll('ii', 'i')
      .replaceAll('oo', 'u')
      .replaceAll('uu', 'u');

  // Common transliterations often add a trailing "h" (Fatihah/Baqarah/Nuh).
  if (text.endsWith('h')) {
    text = text.substring(0, text.length - 1);
  }

  return text;
}
