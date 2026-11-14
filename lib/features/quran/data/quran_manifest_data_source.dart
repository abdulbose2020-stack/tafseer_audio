import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/constants/asset_paths.dart';
import '../domain/quran_source_manifest.dart';

/// Loads the bundled, offline source manifest for the Qur'an dataset.
///
/// Only the small manifest is read here. Surah text is intentionally not
/// loaded at startup; the reader will fetch individual Surah assets later.
class QuranManifestDataSource {
  const QuranManifestDataSource({
    this.assetPath = AssetPaths.quranManifest,
    this.bundle,
  });

  final String assetPath;
  final AssetBundle? bundle;

  Future<QuranSourceManifest> loadManifest() async {
    final assetBundle = bundle ?? rootBundle;
    final rawJson = await assetBundle.loadString(assetPath);
    final decoded = jsonDecode(rawJson);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The Qur’an manifest must be a JSON object.');
    }

    return QuranSourceManifest.fromJson(decoded);
  }
}
