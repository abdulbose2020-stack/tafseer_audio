import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/core/constants/asset_paths.dart';
import 'package:tafseer_audio/features/quran/data/asset_quran_repository.dart';
import 'package:tafseer_audio/features/quran/data/quran_surah_asset_data_source.dart';
import 'package:tafseer_audio/features/quran/presentation/providers/quran_surah_providers.dart';

/// Records every `loadString` call so tests can prove which assets are read.
class _RecordingAssetBundle extends CachingAssetBundle {
  _RecordingAssetBundle(this.assets);

  final Map<String, String> assets;
  final List<String> loadedKeys = [];

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loadedKeys.add(key);
    final value = assets[key];
    if (value == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return value;
  }

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}

const _basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';

String _surahJson({
  required int number,
  required String basmalaMode,
  String? basmalaText,
}) {
  return jsonEncode(<String, dynamic>{
    'surah_number': number,
    'basmala_mode': basmalaMode,
    'basmala_text': basmalaText,
    'ayahs': [
      {
        'number': 1,
        'arabic': 'سورة $number',
        'translation': 'Surah $number, Ayah 1',
        'footnotes': '',
        'sajdah': false,
      },
    ],
  });
}

String get _surah1Json {
  return _surahJson(number: 1, basmalaMode: 'ayah');
}

String get _surah2Json {
  return _surahJson(number: 2, basmalaMode: 'prefatory', basmalaText: _basmala);
}

ProviderContainer _createContainer(_RecordingAssetBundle bundle) {
  return ProviderContainer.test(
    overrides: [
      quranSurahDataSourceProvider.overrideWithValue(
        QuranSurahAssetDataSource(bundle: bundle),
      ),
    ],
  );
}

void main() {
  test('provides the asset data source and repository', () {
    final container = ProviderContainer.test();

    expect(
      container.read(quranSurahDataSourceProvider),
      isA<QuranSurahAssetDataSource>(),
    );
    expect(
      container.read(quranSurahRepositoryProvider),
      isA<AssetQuranRepository>(),
    );
  });

  test('loads only the requested Surah asset and caches it', () async {
    final surah1Path = AssetPaths.quranSurah(1);
    final surah2Path = AssetPaths.quranSurah(2);
    final bundle = _RecordingAssetBundle({
      surah1Path: _surah1Json,
      surah2Path: _surah2Json,
    });
    final container = _createContainer(bundle);

    // 1. Nothing is loaded before a Surah is requested.
    expect(bundle.loadedKeys, isEmpty);

    // 2. Requesting Surah 1 loads only its own asset.
    final surah1 = await container.read(quranSurahProvider(1).future);
    expect(surah1.number, 1);
    expect(bundle.loadedKeys, [surah1Path]);

    // 3. Requesting Surah 1 again reuses the cached provider value.
    final surah1Again = await container.read(quranSurahProvider(1).future);
    expect(surah1Again, same(surah1));
    expect(bundle.loadedKeys, [surah1Path]);

    // 4. Requesting Surah 2 adds only its own asset.
    final surah2 = await container.read(quranSurahProvider(2).future);
    expect(surah2.number, 2);
    expect(bundle.loadedKeys, [surah1Path, surah2Path]);

    // 5. No manifest or unrelated Surah asset was requested.
    expect(bundle.loadedKeys, isNot(contains(AssetPaths.quranManifest)));
    expect(bundle.loadedKeys.toSet(), {surah1Path, surah2Path});
    expect(
      bundle.loadedKeys.where(
        (key) => key.startsWith('${AssetPaths.quranSurahsDirectory}/'),
      ),
      hasLength(2),
    );
  });

  test('does not load content when only the repository is read', () {
    final bundle = _RecordingAssetBundle({
      AssetPaths.quranSurah(1): _surah1Json,
    });
    final container = _createContainer(bundle);

    container.read(quranSurahRepositoryProvider);

    expect(bundle.loadedKeys, isEmpty);
  });

  test('exposes a missing asset as a provider error', () async {
    final container = _createContainer(_RecordingAssetBundle(const {}));

    await expectLater(
      container.read(quranSurahProvider(1).future),
      throwsA(isA<FlutterError>()),
    );
  });
}
