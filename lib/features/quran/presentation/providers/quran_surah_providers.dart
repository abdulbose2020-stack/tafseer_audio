import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/asset_quran_repository.dart';
import '../../data/quran_surah_asset_data_source.dart';
import '../../data/quran_surah_data_source.dart';
import '../../domain/quran_repository.dart';
import '../../domain/quran_surah.dart';

/// Loads individual Surahs from the bundled Qur'an JSON assets.
final quranSurahDataSourceProvider = Provider<QuranSurahDataSource>((ref) {
  return const QuranSurahAssetDataSource();
});

/// Provides the Qur'an text repository to the reading feature.
final quranSurahRepositoryProvider = Provider<QuranRepository>((ref) {
  return AssetQuranRepository(ref.watch(quranSurahDataSourceProvider));
});

/// The complete text of one Surah.
///
/// This provider is lazy and keyed by Mushaf number: nothing is loaded until a
/// specific Surah is requested, and each family instance loads only its own
/// asset. Reading selection is independent from Tafseer/audio selection.
final quranSurahProvider = FutureProvider.family<QuranSurah, int>((
  ref,
  number,
) {
  return ref.watch(quranSurahRepositoryProvider).loadSurah(number);
});
