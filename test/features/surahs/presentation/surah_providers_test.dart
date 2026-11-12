import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/features/surahs/domain/revelation_place.dart';
import 'package:tafseer_audio/features/surahs/domain/surah.dart';
import 'package:tafseer_audio/features/surahs/domain/surah_filter.dart';
import 'package:tafseer_audio/features/surahs/presentation/providers/surah_providers.dart';

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

ProviderContainer _createContainer() {
  return ProviderContainer.test(
    overrides: [
      surahsProvider.overrideWithValue(const AsyncValue.data(_surahs)),
    ],
  );
}

void main() {
  test('exposes the complete catalogue', () {
    final container = _createContainer();

    expect(container.read(surahsProvider).value, _surahs);
    expect(container.read(filteredSurahsProvider).value, _surahs);
  });

  test('filters and searches the catalogue through controller state', () {
    final container = _createContainer();
    final controller = container.read(surahCatalogControllerProvider.notifier);

    controller.setFilter(SurahFilter.makki);
    expect(
      container
          .read(filteredSurahsProvider)
          .value
          ?.map((surah) => surah.number),
      [1, 36, 112],
    );

    controller.setQuery('yaseen');
    expect(
      container
          .read(filteredSurahsProvider)
          .value
          ?.map((surah) => surah.number),
      [36],
    );

    controller.setFilter(SurahFilter.all);
    expect(
      container
          .read(filteredSurahsProvider)
          .value
          ?.map((surah) => surah.number),
      [36],
    );

    controller.clear();
    expect(container.read(filteredSurahsProvider).value, _surahs);
  });

  test('tracks the selected Surah without playback state', () {
    final container = _createContainer();
    final controller = container.read(selectedSurahNumberProvider.notifier);

    expect(container.read(selectedSurahProvider), isNull);

    controller.toggle(36);
    expect(container.read(selectedSurahNumberProvider), 36);
    expect(container.read(selectedSurahProvider), _surahs[2]);

    controller.toggle(36);
    expect(container.read(selectedSurahNumberProvider), isNull);
    expect(container.read(selectedSurahProvider), isNull);

    controller.toggle(2);
    expect(container.read(selectedSurahProvider), _surahs[1]);

    controller.clear();
    expect(container.read(selectedSurahProvider), isNull);
  });

  test('selects a Surah and looks it up by number', () {
    final container = _createContainer();
    final controller = container.read(selectedSurahNumberProvider.notifier);

    controller.select(55);

    expect(container.read(selectedSurahNumberProvider), 55);
    expect(container.read(selectedSurahProvider), _surahs[3]);
    expect(container.read(surahByNumberProvider(55)), _surahs[3]);
    expect(container.read(surahByNumberProvider(99)), isNull);
  });
}
