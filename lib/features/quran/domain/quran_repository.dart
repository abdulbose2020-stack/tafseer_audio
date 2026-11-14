import 'quran_surah.dart';

/// Provides the complete text of individual Surahs to the application.
abstract interface class QuranRepository {
  /// Loads one Surah by its Mushaf number.
  Future<QuranSurah> loadSurah(int number);
}
