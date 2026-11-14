import '../domain/quran_repository.dart';
import '../domain/quran_surah.dart';
import 'quran_surah_data_source.dart';

/// Repository backed by the bundled Qur'an Surah data source.
class AssetQuranRepository implements QuranRepository {
  const AssetQuranRepository(this._dataSource);

  final QuranSurahDataSource _dataSource;

  @override
  Future<QuranSurah> loadSurah(int number) {
    return _dataSource.loadSurah(number);
  }
}
