import 'surah.dart';

/// Provides the complete Surah catalogue to the application.
abstract interface class SurahRepository {
  Future<List<Surah>> getSurahs();
}
