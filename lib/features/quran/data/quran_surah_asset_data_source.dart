import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/constants/asset_paths.dart';
import '../domain/quran_surah.dart';
import 'quran_surah_data_source.dart';

/// Loads one Surah from its bundled, offline JSON asset.
///
/// Only the requested Surah file is read. The manifest is not consulted and
/// the Surah directory is never enumerated.
class QuranSurahAssetDataSource implements QuranSurahDataSource {
  const QuranSurahAssetDataSource({this.bundle});

  final AssetBundle? bundle;

  @override
  Future<QuranSurah> loadSurah(int number) async {
    // AssetPaths validates the number before any asset access.
    final assetPath = AssetPaths.quranSurah(number);
    final assetBundle = bundle ?? rootBundle;
    final rawJson = await assetBundle.loadString(assetPath);

    final Map<String, dynamic> decoded;
    try {
      final value = jsonDecode(rawJson);
      if (value is! Map) {
        throw FormatException(
          'Expected a JSON object, got ${value.runtimeType}.',
        );
      }
      decoded = Map<String, dynamic>.from(value);
    } on FormatException catch (error) {
      throw FormatException(
        "Invalid Qur'an Surah $number ($assetPath): ${error.message}",
      );
    }

    try {
      final surah = QuranSurah.fromJson(decoded);
      if (surah.number != number) {
        throw FormatException(
          'Expected Surah number $number, got ${surah.number}.',
        );
      }
      return surah;
    } on FormatException catch (error) {
      throw FormatException(
        "Invalid Qur'an Surah $number ($assetPath): ${error.message}",
      );
    }
  }
}
