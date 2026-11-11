import 'revelation_place.dart';
import 'surah.dart';

/// Revelation-place filters available in the Surah catalogue.
enum SurahFilter {
  all(label: 'All'),
  makki(label: 'Makki'),
  madani(label: 'Madani');

  const SurahFilter({required this.label});

  final String label;

  bool matches(Surah surah) {
    return switch (this) {
      SurahFilter.all => true,
      SurahFilter.makki => surah.revelationPlace == RevelationPlace.makki,
      SurahFilter.madani => surah.revelationPlace == RevelationPlace.madani,
    };
  }
}
