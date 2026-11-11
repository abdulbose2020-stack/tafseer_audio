import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/features/surahs/domain/revelation_place.dart';
import 'package:tafseer_audio/features/surahs/domain/surah.dart';
import 'package:tafseer_audio/features/surahs/domain/surah_filter.dart';
import 'package:tafseer_audio/features/surahs/domain/surah_search.dart';

const _surahs = [
  Surah(
    number: 1,
    arabicName: 'الفاتحة',
    transliteration: 'Al-Faatiha',
    englishMeaning: 'The Opening',
    ayahCount: 7,
    revelationPlace: RevelationPlace.makki,
  ),
  Surah(
    number: 2,
    arabicName: 'البقرة',
    transliteration: 'Al-Baqara',
    englishMeaning: 'The Cow',
    ayahCount: 286,
    revelationPlace: RevelationPlace.madani,
  ),
  Surah(
    number: 36,
    arabicName: 'يس',
    transliteration: 'Yaseen',
    englishMeaning: 'Yaseen',
    ayahCount: 83,
    revelationPlace: RevelationPlace.makki,
  ),
  Surah(
    number: 55,
    arabicName: 'الرحمن',
    transliteration: 'Ar-Rahmaan',
    englishMeaning: 'The Beneficent',
    ayahCount: 78,
    revelationPlace: RevelationPlace.madani,
  ),
  Surah(
    number: 112,
    arabicName: 'الإخلاص',
    transliteration: 'Al-Ikhlaas',
    englishMeaning: 'Sincerity',
    ayahCount: 4,
    revelationPlace: RevelationPlace.makki,
  ),
];

void main() {
  test('returns the full catalogue for an empty query and All filter', () {
    expect(searchSurahs(_surahs), _surahs);
    expect(searchSurahs(_surahs, filter: SurahFilter.all), _surahs);
  });

  test('searches by exact Surah number', () {
    expect(searchSurahs(_surahs, query: '36'), [_surahs[2]]);
    expect(searchSurahs(_surahs, query: '036'), [_surahs[2]]);
    expect(searchSurahs(_surahs, query: '1'), [_surahs[0]]);
    expect(searchSurahs(_surahs, query: '999'), isEmpty);
  });

  test('searches Arabic names with and without the definite article', () {
    expect(searchSurahs(_surahs, query: 'الفاتحة'), [_surahs[0]]);
    expect(searchSurahs(_surahs, query: 'فاتحة'), [_surahs[0]]);
    expect(searchSurahs(_surahs, query: 'الاخلاص'), [_surahs[4]]);
  });

  test(
    'searches transliterations case-insensitively and without punctuation',
    () {
      expect(searchSurahs(_surahs, query: 'yaseen'), [_surahs[2]]);
      expect(searchSurahs(_surahs, query: 'AL-FAATIHA'), [_surahs[0]]);
      expect(searchSurahs(_surahs, query: 'al fatiha'), [_surahs[0]]);
      expect(searchSurahs(_surahs, query: 'rahman'), [_surahs[3]]);
      expect(searchSurahs(_surahs, query: 'baqarah'), [_surahs[1]]);
    },
  );

  test('searches English meanings', () {
    expect(searchSurahs(_surahs, query: 'the cow'), [_surahs[1]]);
    expect(searchSurahs(_surahs, query: 'beneficent'), [_surahs[3]]);
    expect(searchSurahs(_surahs, query: 'opening'), [_surahs[0]]);
  });

  test('filters by Makki and Madani revelation place', () {
    expect(
      searchSurahs(
        _surahs,
        filter: SurahFilter.makki,
      ).map((surah) => surah.number),
      [1, 36, 112],
    );
    expect(
      searchSurahs(
        _surahs,
        filter: SurahFilter.madani,
      ).map((surah) => surah.number),
      [2, 55],
    );
  });

  test('combines search with the revelation filter', () {
    expect(searchSurahs(_surahs, query: 'cow', filter: SurahFilter.madani), [
      _surahs[1],
    ]);
    expect(
      searchSurahs(_surahs, query: 'cow', filter: SurahFilter.makki),
      isEmpty,
    );
    expect(
      searchSurahs(
        _surahs,
        query: 'a',
        filter: SurahFilter.madani,
      ).map((surah) => surah.number),
      [2, 55],
    );
  });

  test('returns an empty list when nothing matches', () {
    expect(searchSurahs(_surahs, query: 'zzzz'), isEmpty);
    expect(
      searchSurahs(_surahs, query: 'the cow', filter: SurahFilter.makki),
      isEmpty,
    );
  });

  test('normalizes Latin and Arabic search text', () {
    expect(normalizeSearchText('Al-Faatiha'), 'alfatiha');
    expect(normalizeSearchText('Baqarah'), 'baqara');
    expect(normalizeSearchText('Ar-Rahmaan'), 'arrahman');
    expect(normalizeSearchText('البقرة'), 'البقره');
    expect(normalizeSearchText('الْفَاتِحَة'), 'الفاتحه');
  });
}
