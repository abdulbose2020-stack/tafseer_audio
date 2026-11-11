import '../domain/surah.dart';
import '../domain/surah_repository.dart';
import 'surah_data_source.dart';

/// Repository backed by a JSON data source.
class JsonSurahRepository implements SurahRepository {
  const JsonSurahRepository(this._dataSource);

  final SurahDataSource _dataSource;

  @override
  Future<List<Surah>> getSurahs() async {
    final surahs = await _dataSource.loadSurahs();
    return List<Surah>.unmodifiable(surahs);
  }
}
