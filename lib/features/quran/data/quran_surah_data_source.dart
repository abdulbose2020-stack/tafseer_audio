import '../domain/quran_surah.dart';

/// Loads the revealed text of one Surah from a storage mechanism.
abstract interface class QuranSurahDataSource {
  /// Loads one Surah by its Mushaf number.
  Future<QuranSurah> loadSurah(int number);
}
