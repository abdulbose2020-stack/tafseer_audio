import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/core/constants/asset_paths.dart';
import 'package:tafseer_audio/features/quran/data/quran_manifest_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundles the manifest and every one of the 114 Surah files', () async {
    final manifest = await const QuranManifestDataSource().loadManifest();

    expect(manifest.surahCount, 114);
    for (var number = 1; number <= 114; number++) {
      final assetPath = AssetPaths.quranSurah(number);
      final data = await rootBundle.load(assetPath);

      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: 'Bundled asset $assetPath must not be empty.',
      );
    }
  });

  test(
    'asset manifest lists each Qur’an file once and no raw sources',
    () async {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = assetManifest.listAssets();
      final quranAssets = assets
          .where((asset) => asset.startsWith('assets/data/quran/'))
          .toList();

      expect(assets.toSet(), hasLength(assets.length));
      expect(
        assets.where(
          (asset) => asset.endsWith('.xml') || asset.endsWith('.csv'),
        ),
        isEmpty,
      );
      expect(quranAssets, hasLength(115));
      expect(quranAssets.toSet(), hasLength(quranAssets.length));
      expect(
        quranAssets.where(
          (asset) =>
              asset != AssetPaths.quranManifest &&
              !asset.startsWith('${AssetPaths.quranSurahsDirectory}/'),
        ),
        isEmpty,
      );
      expect(
        assets.where(
          (asset) =>
              asset.contains('tool/quran_data') ||
              asset.contains('tanzil-uthmani') ||
              asset.contains('quranenc-english'),
        ),
        isEmpty,
      );

      for (var number = 1; number <= 114; number++) {
        expect(
          quranAssets,
          contains(AssetPaths.quranSurah(number)),
          reason: 'Surah $number must be declared as a Flutter asset.',
        );
      }
    },
  );
}
