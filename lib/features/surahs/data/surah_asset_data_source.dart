import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/constants/asset_paths.dart';
import '../domain/surah.dart';
import 'surah_data_source.dart';

/// Loads the bundled, offline Surah catalogue from a JSON asset.
class SurahAssetDataSource implements SurahDataSource {
  const SurahAssetDataSource({
    this.assetPath = AssetPaths.surahsData,
    this.bundle,
  });

  final String assetPath;
  final AssetBundle? bundle;

  @override
  Future<List<Surah>> loadSurahs() async {
    final assetBundle = bundle ?? rootBundle;
    final rawJson = await assetBundle.loadString(assetPath);
    final decoded = jsonDecode(rawJson);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The Surah catalogue must be a JSON object.');
    }

    final rawSurahs = decoded['surahs'];
    if (rawSurahs is! List) {
      throw const FormatException(
        'The Surah catalogue must contain a "surahs" list.',
      );
    }

    final surahs = <Surah>[];
    for (var index = 0; index < rawSurahs.length; index++) {
      final entry = rawSurahs[index];
      if (entry is! Map) {
        throw FormatException('Surah entry $index is not a JSON object.');
      }

      try {
        surahs.add(Surah.fromJson(Map<String, dynamic>.from(entry)));
      } on FormatException catch (error) {
        throw FormatException('Invalid Surah entry $index: ${error.message}');
      }
    }

    return List<Surah>.unmodifiable(surahs);
  }
}
