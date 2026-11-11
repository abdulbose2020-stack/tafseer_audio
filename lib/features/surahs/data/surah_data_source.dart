import '../domain/surah.dart';

/// Loads raw Surah metadata from a storage mechanism.
abstract interface class SurahDataSource {
  Future<List<Surah>> loadSurahs();
}
