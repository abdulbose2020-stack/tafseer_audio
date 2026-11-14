abstract final class AssetPaths {
  static const String appMark = 'assets/images/app_mark.png';
  static const String appIcon = 'assets/images/app_icon.png';
  static const String splashLogo = 'assets/images/splash_logo.png';
  static const String surahsData = 'assets/data/surahs.json';
  static const String sampleAudio = 'assets/audio/sample/sample_tafseer.mp3';
  static const String quranManifest = 'assets/data/quran/manifest.json';
  static const String quranSurahsDirectory = 'assets/data/quran/surahs';

  /// The bundled JSON asset for one Surah, using its three-digit Mushaf number.
  static String quranSurah(int number) {
    if (number < 1 || number > 114) {
      throw RangeError.range(number, 1, 114, 'number');
    }
    return '$quranSurahsDirectory/${number.toString().padLeft(3, '0')}.json';
  }
}
