import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/features/surahs/data/json_surah_repository.dart';
import 'package:tafseer_audio/features/surahs/data/surah_data_source.dart';
import 'package:tafseer_audio/features/surahs/domain/revelation_place.dart';
import 'package:tafseer_audio/features/surahs/domain/surah.dart';

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
];

class _FakeSurahDataSource implements SurahDataSource {
  _FakeSurahDataSource(this.surahs);

  final List<Surah> surahs;
  int loadCount = 0;

  @override
  Future<List<Surah>> loadSurahs() async {
    loadCount++;
    return surahs;
  }
}

class _FailingSurahDataSource implements SurahDataSource {
  @override
  Future<List<Surah>> loadSurahs() async {
    throw StateError('The asset could not be read.');
  }
}

void main() {
  test('loads the catalogue through the data source exactly once', () async {
    final dataSource = _FakeSurahDataSource(_surahs);
    final repository = JsonSurahRepository(dataSource);

    final result = await repository.getSurahs();

    expect(result, _surahs);
    expect(dataSource.loadCount, 1);
  });

  test('returns an unmodifiable Surah list', () async {
    final repository = JsonSurahRepository(_FakeSurahDataSource(_surahs));

    final result = await repository.getSurahs();

    expect(() => result.add(_surahs.first), throwsUnsupportedError);
  });

  test('propagates data source failures', () async {
    final repository = JsonSurahRepository(_FailingSurahDataSource());

    expect(repository.getSurahs(), throwsA(isA<StateError>()));
  });
}
